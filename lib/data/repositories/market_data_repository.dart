import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 擴充市場資料 Repository（Phase 1）
///
/// 處理：外資持股、當沖、財報、還原股價、週K線、股權分散表
class MarketDataRepository {
  MarketDataRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final FinMindClient _client;
  final TwseClient _twseClient;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 判定批次資料為「最新」的最低筆數門檻
  /// 若該日期已有超過此數量的資料，則跳過 API 呼叫
  static const _batchFreshnessThreshold = 100;

  // ============================================
  // 外資持股
  // ============================================

  /// 取得外資持股歷史資料
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    int days = 60,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getShareholdingHistory(symbol, startDate: startDate);
  }

  /// 取得股票最新外資持股資料
  Future<ShareholdingEntry?> getLatestShareholding(String symbol) {
    return _db.getLatestShareholding(symbol);
  }

  /// 從 FinMind 同步外資持股資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若 [endDate]（或今日）的資料已存在則跳過。
  Future<int> syncShareholding(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有目標日期資料則跳過
      final targetDate = endDate ?? DateTime.now();
      final latest = await getLatestShareholding(symbol);
      if (latest != null && _isSameDay(latest.date, targetDate)) {
        return 0;
      }

      final data = await _client.getShareholding(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return ShareholdingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignRemainingShares: Value(item.foreignInvestmentRemainingShares),
          foreignSharesRatio: Value(item.foreignInvestmentSharesRatio),
          foreignUpperLimitRatio: Value(item.foreignInvestmentUpperLimitRatio),
          sharesIssued: Value(item.numberOfSharesIssued),
        );
      }).toList();

      await _db.insertShareholdingData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync shareholding for $symbol', e);
    }
  }

  /// 檢查兩個日期是否為同一天（忽略時間）
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 檢查兩個日期是否在同一週（週一至週日）
  bool _isSameWeek(DateTime a, DateTime b) {
    // 正規化至該週開始（週一）
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aWeekStart, bWeekStart);
  }

  /// 根據當前日期取得預期最新季度日期
  ///
  /// 財報通常在季度結束後約 45 天公布：
  /// - Q1（1-3月）→ 約 5 月中公布
  /// - Q2（4-6月）→ 約 8 月中公布
  /// - Q3（7-9月）→ 約 11 月中公布
  /// - Q4（10-12月）→ 約隔年 3 月中公布
  DateTime _getExpectedLatestQuarter() {
    final now = DateTime.now();
    final month = now.month;

    // 判斷哪一季的財報應該已公布
    if (month >= 3 && month < 5) {
      // 3-4月：去年 Q4 應已公布
      return DateTime(now.year - 1, 10, 1);
    } else if (month >= 5 && month < 8) {
      // 5-7月：Q1 應已公布
      return DateTime(now.year, 1, 1);
    } else if (month >= 8 && month < 11) {
      // 8-10月：Q2 應已公布
      return DateTime(now.year, 4, 1);
    } else if (month >= 11) {
      // 11-12月：Q3 應已公布
      return DateTime(now.year, 7, 1);
    } else {
      // 1-2月：去年 Q3 應已公布
      return DateTime(now.year - 1, 7, 1);
    }
  }

  /// 檢查外資持股比例是否增加中
  Future<bool> isForeignShareholdingIncreasing(
    String symbol, {
    int days = 5,
  }) async {
    final history = await getShareholdingHistory(symbol, days: days + 10);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.foreignSharesRatio ?? 0;
    final last = recent.first.foreignSharesRatio ?? 0;

    return last > first;
  }

  // ============================================
  // 當沖
  // ============================================

  /// 取得當沖歷史資料
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 10));
    return _db.getDayTradingHistory(symbol, startDate: startDate);
  }

  /// 取得最新當沖資料
  Future<DayTradingEntry?> getLatestDayTrading(String symbol) {
    return _db.getLatestDayTrading(symbol);
  }

  /// 從 FinMind 同步當沖資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若 [endDate]（或今日）的資料已存在則跳過。
  ///
  /// 註：建議使用 [syncAllDayTradingFromTwse] 進行批次同步（免費、無配額限制）。
  Future<int> syncDayTrading(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有目標日期資料則跳過
      final targetDate = endDate ?? DateTime.now();
      final latest = await getLatestDayTrading(symbol);
      if (latest != null && _isSameDay(latest.date, targetDate)) {
        return 0;
      }

      final data = await _client.getDayTrading(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return DayTradingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          buyVolume: Value(item.buyDayTradingVolume),
          sellVolume: Value(item.sellDayTradingVolume),
          dayTradingRatio: Value(item.dayTradingRatio),
          tradeVolume: Value(item.tradeVolume),
        );
      }).toList();

      await _db.insertDayTradingData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading for $symbol', e);
    }
  }

  /// 檢查是否為高當沖股（當沖比 > 30%）
  Future<bool> isHighDayTradingStock(String symbol) async {
    final latest = await getLatestDayTrading(symbol);
    if (latest == null) return false;
    return (latest.dayTradingRatio ?? 0) > 30;
  }

  /// 取得平均當沖比例
  Future<double?> getAverageDayTradingRatio(
    String symbol, {
    int days = 5,
  }) async {
    final history = await getDayTradingHistory(symbol, days: days + 5);
    if (history.isEmpty) return null;

    final recent = history.reversed.take(days).toList();
    if (recent.isEmpty) return null;

    double sum = 0;
    int count = 0;
    for (final entry in recent) {
      if (entry.dayTradingRatio != null) {
        sum += entry.dayTradingRatio!;
        count++;
      }
    }

    return count > 0 ? sum / count : null;
  }

  /// 從 TWSE 同步全市場當沖資料（免費 API）
  ///
  /// 使用 TWSE 官方 API，無需 Token。
  /// 比透過 FinMind 逐檔同步快很多。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [forceRefresh] 為 true 可略過新鮮度檢查。
  Future<int> syncAllDayTradingFromTwse({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    try {
      // 統一使用本地時間午夜，確保與 DateContext.normalize 一致
      final rawDate = date ?? DateTime.now();
      final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

      // 新鮮度檢查：若已有目標日期資料則跳過
      if (!forceRefresh) {
        final existingCount = await _db.getDayTradingCountForDate(targetDate);
        if (existingCount > _batchFreshnessThreshold) {
          return 0;
        }
      }

      // 1. 取得當沖資料（比例為 0，因為 API 不提供）
      final data = await _twseClient.getAllDayTradingData(date: targetDate);

      AppLogger.info(
        'MarketData',
        'TWSE 當沖原始筆數: ${data.length}，日期: $targetDate',
      );

      if (data.isEmpty) return 0;

      // 2. 取得同日期的價格資料以計算比例
      // 註：呼叫此方法前必須先同步價格資料
      var prices = await _db.getPricesForDate(targetDate);

      // 備援 1：若 UTC 日期無結果，嘗試本地日期
      // Database 可能以本地時間或正規化 UTC 儲存日期
      if (prices.isEmpty) {
        prices = await _db.getPricesForDate(targetDate.toLocal());
      }

      // 備援 2：嘗試範圍查詢（涵蓋 UTC 和本地時間）
      if (prices.isEmpty) {
        final year = targetDate.year;
        final month = targetDate.month;
        final day = targetDate.day;

        final start = DateTime(year, month, day); // 本地午夜
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));

        final result = await _db.getAllPricesInRange(
          startDate: start,
          endDate: end,
        );
        prices = result.values.expand((list) => list).toList();
      }

      AppLogger.info('MarketData', '用於計算的價格資料: ${prices.length} 筆');
      final volumeMap = <String, double>{};
      for (final p in prices) {
        if (p.volume != null) {
          volumeMap[p.symbol] = p.volume!.toDouble();
        }
      }

      final entries = <DayTradingCompanion>[];

      for (final item in data) {
        double ratio = 0;
        final totalVolumeFromPrice = volumeMap[item.code] ?? 0;

        // 優先使用價格表的總成交量，否則使用當沖成交量
        // 但計算比例需要總市場成交量
        if (totalVolumeFromPrice > 0) {
          ratio = (item.totalVolume / totalVolumeFromPrice) * 100;
        } else {
          // 若無價格資料則備援（需確認同步順序）
          ratio = 0;
        }

        // 驗證比例
        if (ratio > 100) ratio = 100;
        if (ratio < 0) ratio = 0;

        entries.add(
          DayTradingCompanion.insert(
            symbol: item.code,
            date: targetDate, // 使用標準化日期，確保與查詢一致
            buyVolume: Value(item.buyVolume),
            sellVolume: Value(item.sellVolume),
            dayTradingRatio: Value(ratio),
            tradeVolume: Value(item.totalVolume),
          ),
        );
      }

      // 刪除舊記錄（可能存在因 UTC/本地時間不一致導致的重複）
      // 刪除範圍：目標日期的前後各 12 小時（涵蓋 UTC 偏移）
      final deleteStart = targetDate.subtract(const Duration(hours: 12));
      final deleteEnd = targetDate.add(const Duration(hours: 36));
      await _db.deleteDayTradingForDateRange(deleteStart, deleteEnd);

      await _db.insertDayTradingData(entries);

      // 統計當沖比例分佈
      final highRatioEntries = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null && ratio >= 60;
      }).toList();
      final extremeRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null && ratio >= 70;
      }).length;
      final zeroRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio == null || ratio == 0;
      }).length;

      AppLogger.info(
        'MarketData',
        '當沖資料寫入 ${entries.length} 筆: '
            '高比例(>=60%)=${highRatioEntries.length}，極高(>=70%)=$extremeRatioCount，零比例=$zeroRatioCount',
      );

      if (highRatioEntries.isNotEmpty) {
        final highSymbols = highRatioEntries
            .map(
              (e) =>
                  '${e.symbol.value}(${e.dayTradingRatio.value?.toStringAsFixed(1)}%)',
            )
            .join(', ');
        AppLogger.info('MarketData', '高當沖股票: $highSymbols');
      }
      return entries.length;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading from TWSE', e);
    }
  }

  // ============================================
  // 財報資料
  // ============================================

  /// 同步損益表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncIncomeStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有最新季度則跳過
      final latestDate = await _db.getLatestFinancialDataDate(symbol, 'INCOME');
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getFinancialStatements(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'INCOME',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync income statement for $symbol', e);
    }
  }

  /// 同步資產負債表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有最新季度則跳過
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        'BALANCE',
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getBalanceSheet(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'BALANCE',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync balance sheet for $symbol', e);
    }
  }

  /// 同步現金流量表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncCashFlowStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有最新季度則跳過
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        'CASHFLOW',
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getCashFlowsStatement(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'CASHFLOW',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync cash flow for $symbol', e);
    }
  }

  /// 取得特定財務指標
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    int quarters = 8,
  }) async {
    final startDate = DateTime.now().subtract(
      Duration(days: quarters * 90 + 30),
    );
    return _db.getFinancialMetrics(
      symbol,
      dataTypes: dataTypes,
      startDate: startDate,
    );
  }

  /// 解析季度日期字串（如 "2024-Q1" 或 "2024-01-01"）
  DateTime _parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      // 格式：2024-Q1
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
  }

  // ============================================
  // 還原股價
  // ============================================

  /// 取得還原股價歷史資料
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    int days = 120,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getAdjustedPriceHistory(symbol, startDate: startDate);
  }

  /// 同步還原股價資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有目標日期資料則跳過。
  Future<int> syncAdjustedPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有今日資料則跳過
      final targetDate = endDate ?? DateTime.now();
      final latestDate = await _db.getLatestAdjustedPriceDate(symbol);
      if (latestDate != null && _isSameDay(latestDate, targetDate)) {
        return 0;
      }

      final data = await _client.getAdjustedPrices(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return AdjustedPriceCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          open: Value(item.open),
          high: Value(item.high),
          low: Value(item.low),
          close: Value(item.close),
          volume: Value(item.volume),
        );
      }).toList();

      await _db.insertAdjustedPrices(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync adjusted prices for $symbol', e);
    }
  }

  // ============================================
  // 週K線
  // ============================================

  /// 取得週K線歷史資料
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    int weeks = 52,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: weeks * 7 + 30));
    return _db.getWeeklyPriceHistory(symbol, startDate: startDate);
  }

  /// 同步週K線資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有本週資料則跳過。
  Future<int> syncWeeklyPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有本週資料則跳過
      final latestDate = await _db.getLatestWeeklyPriceDate(symbol);
      if (latestDate != null && _isSameWeek(latestDate, DateTime.now())) {
        return 0;
      }

      final data = await _client.getWeeklyPrices(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return WeeklyPriceCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          open: Value(item.open),
          high: Value(item.high),
          low: Value(item.low),
          close: Value(item.close),
          volume: Value(item.volume),
        );
      }).toList();

      await _db.insertWeeklyPrices(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync weekly prices for $symbol', e);
    }
  }

  /// 取得 52 週最高/最低價
  Future<({double? high, double? low})> get52WeekHighLow(String symbol) async {
    final history = await getWeeklyPriceHistory(symbol, weeks: 52);
    if (history.isEmpty) return (high: null, low: null);

    double? maxHigh;
    double? minLow;

    for (final entry in history) {
      if (entry.high != null) {
        maxHigh = maxHigh == null
            ? entry.high
            : (entry.high! > maxHigh ? entry.high : maxHigh);
      }
      if (entry.low != null) {
        minLow = minLow == null
            ? entry.low
            : (entry.low! < minLow ? entry.low : minLow);
      }
    }

    return (high: maxHigh, low: minLow);
  }

  // ============================================
  // 股權分散表
  // ============================================

  /// 取得最新股權分散表
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) {
    return _db.getLatestHoldingDistribution(symbol);
  }

  /// 同步股權分散表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 股權分散表每週公布，若已有本週資料則跳過。
  ///
  /// 註：此 API 需要 FinMind 付費訂閱。
  Future<int> syncHoldingDistribution(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有本週資料則跳過
      final latestDate = await _db.getLatestHoldingDistributionDate(symbol);
      if (latestDate != null && _isSameWeek(latestDate, DateTime.now())) {
        return 0;
      }

      final data = await _client.getHoldingSharesPer(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return HoldingDistributionCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          level: item.holdingSharesLevel,
          shareholders: Value(item.people),
          percent: Value(item.percent),
          shares: Value(item.unit),
        );
      }).toList();

      await _db.insertHoldingDistribution(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync holding distribution for $symbol',
        e,
      );
    }
  }

  /// 計算籌碼集中度（大戶持股比例）
  ///
  /// 回傳持股超過 [threshold] 張的股東持股百分比
  Future<double?> getConcentrationRatio(
    String symbol, {
    int thresholdLevel = 400, // 400張 = 40萬股
  }) async {
    final distribution = await getLatestHoldingDistribution(symbol);
    if (distribution.isEmpty) return null;

    double largeHolderPercent = 0;

    for (final entry in distribution) {
      // 解析級距以取得最小持股數
      // 級距如 "400-600"、"600-800"、"800-1000"、"1000以上"
      final level = entry.level;
      final minShares = _parseMinSharesFromLevel(level);

      if (minShares >= thresholdLevel) {
        largeHolderPercent += entry.percent ?? 0;
      }
    }

    return largeHolderPercent;
  }

  /// 從級距字串解析最小持股數
  int _parseMinSharesFromLevel(String level) {
    // 處理 "1000以上" 或 "over 1000"
    if (level.contains('以上') || level.toLowerCase().contains('over')) {
      final numStr = level.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    // 處理 "400-600" 格式
    final parts = level.split('-');
    if (parts.isNotEmpty) {
      final numStr = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    return 0;
  }

  // ============================================
  // 融資融券 - TWSE API
  // ============================================

  /// 取得融資融券歷史資料
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 10));
    return _db.getMarginTradingHistory(symbol, startDate: startDate);
  }

  /// 取得最新融資融券資料
  Future<MarginTradingEntry?> getLatestMarginTrading(String symbol) {
    return _db.getLatestMarginTrading(symbol);
  }

  /// 從 TWSE 同步全市場融資融券資料（免費 API）
  ///
  /// 使用 TWSE 官方 API，無需 Token。
  /// API 端點：/rwd/zh/marginTrading/MI_MARGN
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [forceRefresh] 為 true 可略過新鮮度檢查。
  Future<int> syncAllMarginTradingFromTwse({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();

      // 新鮮度檢查：若已有目標日期資料則跳過
      if (!forceRefresh) {
        final existingCount = await _db.getMarginTradingCountForDate(
          targetDate,
        );
        if (existingCount > _batchFreshnessThreshold) {
          return 0;
        }
      }

      final data = await _twseClient.getAllMarginTradingData();

      AppLogger.info('MarketData', 'TWSE 融資融券原始筆數: ${data.length}');

      if (data.isEmpty) return 0;

      final entries = data.map((item) {
        return MarginTradingCompanion.insert(
          symbol: item.code,
          date: item.date,
          marginBuy: Value(item.marginBuy),
          marginSell: Value(item.marginSell),
          marginBalance: Value(item.marginBalance),
          shortBuy: Value(item.shortBuy),
          shortSell: Value(item.shortSell),
          shortBalance: Value(item.shortBalance),
        );
      }).toList();

      await _db.insertMarginTradingData(entries);
      AppLogger.info('MarketData', 'TWSE 融資融券寫入 ${entries.length} 筆');
      return entries.length;
    } catch (e) {
      throw DatabaseException('Failed to sync margin trading from TWSE', e);
    }
  }

  /// 計算券資比
  ///
  /// 較高的券資比（> 30%）表示潛在軋空機會
  Future<double?> getShortMarginRatio(String symbol) async {
    final latest = await getLatestMarginTrading(symbol);
    if (latest == null) return null;

    final marginBalance = latest.marginBalance ?? 0;
    final shortBalance = latest.shortBalance ?? 0;

    if (marginBalance <= 0) return null;
    return (shortBalance / marginBalance) * 100;
  }

  /// 檢查融資餘額是否增加中（散戶追多）
  Future<bool> isMarginIncreasing(String symbol, {int days = 5}) async {
    final history = await getMarginTradingHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.marginBalance ?? 0;
    final last = recent.first.marginBalance ?? 0;

    return last > first;
  }

  /// 檢查融券餘額是否增加中（空單增加）
  Future<bool> isShortIncreasing(String symbol, {int days = 5}) async {
    final history = await getMarginTradingHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.shortBalance ?? 0;
    final last = recent.first.shortBalance ?? 0;

    return last > first;
  }
}
