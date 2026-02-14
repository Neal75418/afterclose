import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/services/screening_service.dart';

/// 策略回測引擎
///
/// 對每個歷史取樣日執行篩選，量化被選出股票在 N 天後的報酬率。
class BacktestService {
  const BacktestService({
    required AppDatabase database,
    required ScreeningService screeningService,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _screeningService = screeningService,
       _clock = clock;

  final AppDatabase _db;
  final ScreeningService _screeningService;
  final AppClock _clock;

  /// 執行回測
  ///
  /// [onProgress] 回報進度 (current, total)。
  /// 若 [isCancelled] 回傳 true 則提前中斷。
  Future<BacktestResult> execute({
    required List<ScreeningCondition> conditions,
    required BacktestConfig config,
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (conditions.isEmpty) {
      return BacktestResult(
        config: config,
        trades: const [],
        summary: BacktestSummary.fromTrades(const []),
        executionTime: Duration.zero,
        tradingDaysScanned: 0,
      );
    }

    // 1. 找到最新資料日期
    final latestDate = await _findLatestAnalysisDate();
    if (latestDate == null) {
      return BacktestResult(
        config: config,
        trades: const [],
        summary: BacktestSummary.fromTrades(const []),
        executionTime: Duration.zero,
        tradingDaysScanned: 0,
      );
    }

    // 2. 計算回測區間
    // 出場需要額外的 holdingDays，所以回測截止日要往前推
    final backtestEnd = _subtractTradingDays(latestDate, config.holdingDays);
    final backtestStart = DateContext.normalize(
      latestDate.subtract(Duration(days: config.totalDaysBack)),
    );

    // 3. 列舉取樣交易日
    final samplingDays = _getSamplingDays(
      backtestStart,
      backtestEnd,
      config.samplingInterval,
    );

    if (samplingDays.isEmpty) {
      return BacktestResult(
        config: config,
        trades: const [],
        summary: BacktestSummary.fromTrades(const []),
        executionTime: Duration.zero,
        tradingDaysScanned: 0,
      );
    }

    // 4. 逐日篩選 → 收集命中紀錄
    final pendingTrades = <_PendingTrade>[];

    for (var i = 0; i < samplingDays.length; i++) {
      if (isCancelled?.call() == true) break;

      final screeningDate = samplingDays[i];

      try {
        final result = await _screeningService.execute(
          conditions: conditions,
          targetDate: screeningDate,
        );

        for (final symbol in result.symbols) {
          final exitDate = _addTradingDays(screeningDate, config.holdingDays);
          pendingTrades.add(
            _PendingTrade(
              symbol: symbol,
              entryDate: screeningDate,
              exitDate: exitDate,
              holdingTradingDays: config.holdingDays,
            ),
          );
        }
      } catch (e) {
        AppLogger.error('BacktestService', '篩選日 $screeningDate 失敗', e);
      }

      onProgress?.call(i + 1, samplingDays.length);
    }

    // 5. 批次載入進出場價格 → 計算報酬率
    final resolved = await _resolveTradeReturns(pendingTrades);

    stopwatch.stop();

    final summary = BacktestSummary.fromTrades(resolved.trades);

    return BacktestResult(
      config: config,
      trades: resolved.trades,
      summary: summary,
      executionTime: stopwatch.elapsed,
      tradingDaysScanned: samplingDays.length,
      skippedTrades: resolved.skipped,
    );
  }

  // ==================================================
  // 私有輔助
  // ==================================================

  /// 找到最新有分析資料的日期
  Future<DateTime?> _findLatestAnalysisDate() async {
    final now = _clock.now();
    for (var daysAgo = 0; daysAgo <= 7; daysAgo++) {
      final date = DateContext.normalize(now.subtract(Duration(days: daysAgo)));
      final analyses = await _db.getAnalysisForDate(date);
      if (analyses.isNotEmpty) return date;
    }
    return null;
  }

  /// 列舉取樣日（每 samplingInterval 個交易日取一次）
  List<DateTime> _getSamplingDays(
    DateTime start,
    DateTime end,
    int samplingInterval,
  ) {
    final days = <DateTime>[];
    var current = start;
    var tradingDayCount = 0;

    while (!current.isAfter(end)) {
      if (TaiwanCalendar.isTradingDay(current)) {
        if (tradingDayCount % samplingInterval == 0) {
          days.add(current);
        }
        tradingDayCount++;
      }
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  /// 往後推 N 個交易日
  DateTime _addTradingDays(DateTime date, int tradingDays) {
    var current = date;
    var count = 0;
    while (count < tradingDays) {
      current = current.add(const Duration(days: 1));
      if (TaiwanCalendar.isTradingDay(current)) {
        count++;
      }
    }
    return current;
  }

  /// 往前推 N 個交易日
  DateTime _subtractTradingDays(DateTime date, int tradingDays) {
    var current = date;
    var count = 0;
    var iterations = 0;
    final maxIterations = tradingDays * 5; // 安全上限，防止無限迴圈
    while (count < tradingDays && iterations < maxIterations) {
      current = current.subtract(const Duration(days: 1));
      iterations++;
      if (TaiwanCalendar.isTradingDay(current)) {
        count++;
      }
    }
    return current;
  }

  /// 批次解析所有 pending trades 的進出場價格
  ///
  /// 回傳 (trades, skippedCount)。
  Future<({List<BacktestTrade> trades, int skipped})> _resolveTradeReturns(
    List<_PendingTrade> pendingTrades,
  ) async {
    if (pendingTrades.isEmpty) return (trades: <BacktestTrade>[], skipped: 0);

    // 收集所有需要查價的 symbols
    final allSymbols = pendingTrades.map((t) => t.symbol).toSet().toList();

    // 找到整體日期範圍
    final allDates = [
      ...pendingTrades.map((t) => t.entryDate),
      ...pendingTrades.map((t) => t.exitDate),
    ];
    allDates.sort();
    final startDate = allDates.first;
    final endDate = allDates.last.add(const Duration(days: 1));

    // 批次查詢所有價格
    final priceMap = await _db.getPriceHistoryBatch(
      allSymbols,
      startDate: startDate,
      endDate: endDate,
    );

    // 建構日期→價格的快速查詢 map
    final priceLookup = <String, Map<String, double>>{};
    for (final entry in priceMap.entries) {
      final symbol = entry.key;
      final dateMap = <String, double>{};
      for (final price in entry.value) {
        if (price.close != null) {
          final key = _dateKey(price.date);
          dateMap[key] = price.close!;
        }
      }
      priceLookup[symbol] = dateMap;
    }

    // 解析每筆交易
    final trades = <BacktestTrade>[];
    var skipped = 0;
    for (final pending in pendingTrades) {
      final symbolPrices = priceLookup[pending.symbol];
      if (symbolPrices == null) {
        skipped++;
        continue;
      }

      final entryPrice = symbolPrices[_dateKey(pending.entryDate)];
      final exitPrice = symbolPrices[_dateKey(pending.exitDate)];

      if (entryPrice == null || exitPrice == null || entryPrice == 0) {
        skipped++;
        continue;
      }

      // 扣除台股交易成本：買進手續費 0.1425% + 賣出手續費 0.1425% + 證交稅 0.3%
      final netEntry = entryPrice * (1 + 0.001425); // 買入含手續費
      final netExit = exitPrice * (1 - 0.001425 - 0.003); // 賣出扣手續費+稅
      final returnPercent = (netExit - netEntry) / netEntry * 100;

      trades.add(
        BacktestTrade(
          symbol: pending.symbol,
          entryDate: pending.entryDate,
          entryPrice: entryPrice,
          exitDate: pending.exitDate,
          exitPrice: exitPrice,
          holdingDays: pending.holdingTradingDays,
          returnPercent: returnPercent,
        ),
      );
    }

    return (trades: trades, skipped: skipped);
  }

  /// 日期 key（用於 map 查詢）
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 暫存的待解析交易（尚未查到價格）
class _PendingTrade {
  const _PendingTrade({
    required this.symbol,
    required this.entryDate,
    required this.exitDate,
    required this.holdingTradingDays,
  });

  final String symbol;
  final DateTime entryDate;
  final DateTime exitDate;
  final int holdingTradingDays;
}
