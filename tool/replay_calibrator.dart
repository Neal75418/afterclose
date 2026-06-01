// tool/replay_calibrator.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// Stage 4: Replay rule firings across historical backfilled data and
// populate the `rule_accuracy` table for `tool/recalibrate.dart` to
// consume.
//
// ## 為什麼需要這支工具
//
// 生產環境的 `rule_accuracy_service.validatePastRecommendationsMultiPeriod`
// 只看 Top 20 推薦股的 rule firings — 這造成 calibration 的嚴重 selection
// bias：負訊號 rule 會拖低總分，相關股票根本不會進 Top 20，於是 calibration
// 看不到足夠的負訊號 rule 樣本，全部被 `sample_size < 30` 砍掉。
//
// 這支工具**直接迭代所有股票的所有交易日**，呼叫 `RuleEngine.evaluateStock`
// 收集每條 rule 的所有觸發，計算 forward return，寫入 `rule_accuracy`
// 表。沒有任何 Top-20 過濾 → unbiased sample。
//
// ## 使用方式
//
//   dart run tool/replay_calibrator.dart \
//     --db tool/calibration.db \    # default
//     --min-history 20              # default: RuleParams.swingWindow
//
//   # Dry run（只 print 預計工作量）
//   dart run tool/replay_calibrator.dart --db tool/calibration.db --dry-run
//
// ## Pipeline
//
//   1. Load all backfilled data from DB into memory maps per symbol
//   2. For each symbol × each trading day with enough history + forward data:
//        reasons = RuleEngine.evaluateStock(context, stockData)
//        for each reason:
//          compute 5d + 60d forward return from prices[i+5] and prices[i+60]
//          accumulate into per-rule stats
//   3. Upsert rule_accuracy rows: '5D' / '60D' for each rule
//
// ## Output
//
// Writes to `rule_accuracy` table in the same calibration DB. The existing
// `tool/recalibrate.dart` reads from this table as its input.

import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:afterclose/core/constants/calibration_thresholds.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ============================================================================
// Public data models (importable by tests)
// ============================================================================

/// Replay 執行配置
class ReplayConfig {
  const ReplayConfig({
    required this.dbPath,
    this.minHistoryDays = RuleParams.swingWindow,
    this.dryRun = false,
    this.symbolsWhitelist,
  });

  final String dbPath;

  /// 股票必須至少有這麼多天歷史才開始評估
  final int minHistoryDays;

  final bool dryRun;

  /// 可選 whitelist（測試用，限定 symbol 範圍）
  final List<String>? symbolsWhitelist;
}

/// 單一 rule × horizon 的統計累加器
class RuleHorizonStats {
  RuleHorizonStats();

  int triggerCount = 0;
  int successCount = 0;
  double sumReturn = 0;
  final List<double> returns = [];

  void addSample(double returnPct, double threshold) {
    triggerCount++;
    sumReturn += returnPct;
    returns.add(returnPct);
    if (returnPct >= threshold) successCount++;
  }

  double get avgReturn => triggerCount == 0 ? 0.0 : sumReturn / triggerCount;

  double get hitRate => triggerCount == 0 ? 0.0 : successCount / triggerCount;
}

/// 單一 rule 的所有 horizon 統計
class RuleStats {
  RuleStats();

  final RuleHorizonStats short = RuleHorizonStats();
  final RuleHorizonStats long = RuleHorizonStats();
}

/// Replay 執行結果（summary 用）
class ReplayResult {
  const ReplayResult({
    required this.rulesObserved,
    required this.totalFirings,
    required this.symbolsProcessed,
    required this.daysProcessed,
    required this.ruleStats,
    required this.duration,
  });

  final int rulesObserved;
  final int totalFirings;
  final int symbolsProcessed;
  final int daysProcessed;
  final Map<String, RuleStats> ruleStats;
  final Duration duration;
}

// ============================================================================
// Core replay logic (testable)
// ============================================================================

/// 依靠已 backfill 的 calibration DB，replay 所有 rule firings 並產出
/// `rule_accuracy` 統計。
class ReplayCalibrator {
  ReplayCalibrator({
    required this.db,
    required this.config,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
    void Function(String)? logger,
  }) : _analysis = analysisService ?? AnalysisService(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _log = logger ?? print;

  final AppDatabase db;
  final ReplayConfig config;
  final AnalysisService _analysis;
  final RuleEngine _ruleEngine;
  final void Function(String) _log;

  Future<ReplayResult> run() async {
    final overallStart = DateTime.now();

    // 1. Load 所有資料
    _log('▶️  Loading backfilled data from DB...');
    final loadStart = DateTime.now();
    final data = await _loadData();
    _log(
      '✅ Loaded: ${data.pricesBySymbol.length} symbols with prices '
      '(${_formatDuration(DateTime.now().difference(loadStart))})',
    );

    if (data.pricesBySymbol.isEmpty) {
      _log('⚠️  No price data found — did backfill run first?');
      return ReplayResult(
        rulesObserved: 0,
        totalFirings: 0,
        symbolsProcessed: 0,
        daysProcessed: 0,
        ruleStats: const {},
        duration: DateTime.now().difference(overallStart),
      );
    }

    if (config.dryRun) {
      _logDryRunPlan(data);
      return ReplayResult(
        rulesObserved: 0,
        totalFirings: 0,
        symbolsProcessed: data.pricesBySymbol.length,
        daysProcessed: 0,
        ruleStats: const {},
        duration: DateTime.now().difference(overallStart),
      );
    }

    // 2. Replay 所有 firings + 即時計算 forward return
    _log('');
    _log(
      '▶️  Replaying rule firings across ${data.pricesBySymbol.length} symbols...',
    );
    final replayStart = DateTime.now();
    final ruleStats = <String, RuleStats>{};
    var symbolsProcessed = 0;
    var daysProcessed = 0;
    var totalFirings = 0;
    var lastLogAt = DateTime.now();

    for (final symbol in data.pricesBySymbol.keys) {
      symbolsProcessed++;
      final result = _replaySymbol(symbol, data, ruleStats);
      daysProcessed += result.days;
      totalFirings += result.firings;

      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          symbolsProcessed == data.pricesBySymbol.length) {
        final pct = (symbolsProcessed / data.pricesBySymbol.length * 100)
            .toStringAsFixed(1);
        final elapsed = now.difference(replayStart);
        _log(
          '  📊 $symbolsProcessed/${data.pricesBySymbol.length} ($pct%), '
          'firings=$totalFirings, rules=${ruleStats.length}, '
          'elapsed=${_formatDuration(elapsed)}',
        );
        lastLogAt = now;
      }
    }

    _log('');
    _log(
      '✅ Replay complete: $totalFirings firings across ${ruleStats.length} rules',
    );

    // 3. Write aggregated stats to rule_accuracy
    _log('');
    _log('▶️  Writing rule_accuracy table...');
    await _writeRuleAccuracy(ruleStats);
    _log('✅ rule_accuracy 寫入完成');

    final duration = DateTime.now().difference(overallStart);
    final result = ReplayResult(
      rulesObserved: ruleStats.length,
      totalFirings: totalFirings,
      symbolsProcessed: symbolsProcessed,
      daysProcessed: daysProcessed,
      ruleStats: ruleStats,
      duration: duration,
    );
    _logSummary(result);
    return result;
  }

  /// Replay 單一 symbol 的所有歷史交易日
  ///
  /// 對每一天：
  /// 1. 取 prices[0..=i] 作為分析輸入
  /// 2. 確保 forward window 夠（i + 60 < length）
  /// 3. 呼叫 analysisService + ruleEngine
  /// 4. 對每個 firing 計算 5d + 60d forward return 並累加進 ruleStats
  _PerSymbolResult _replaySymbol(
    String symbol,
    _BackfilledData data,
    Map<String, RuleStats> ruleStats,
  ) {
    final prices = data.pricesBySymbol[symbol];
    if (prices == null || prices.length < config.minHistoryDays) {
      return const _PerSymbolResult(days: 0, firings: 0);
    }

    const shortDays = 5;
    const longDays = 60;
    // 從 canonical 常數讀出 — 不要在這邊重新寫死值，否則跟
    // RuleAccuracyService 與 recalibrate 會 drift（過去就是這樣壞掉的）
    final shortThreshold =
        CalibrationThresholds.successThresholds[shortDays] ??
        CalibrationThresholds.defaultSuccessThreshold;
    final longThreshold =
        CalibrationThresholds.successThresholds[longDays] ??
        CalibrationThresholds.defaultSuccessThreshold;

    var daysEvaluated = 0;
    var firingsRecorded = 0;

    for (var i = config.minHistoryDays; i < prices.length; i++) {
      // 確保 forward window 完整（短跟長都要）
      if (i + longDays >= prices.length) break;

      final currentPrice = prices[i];
      final entryClose = currentPrice.close;
      if (entryClose == null || entryClose <= 0) continue;

      // 建立分析視窗
      final pricesUpToDay = prices.sublist(0, i + 1);
      final analysisResult = _analysis.analyzeStock(pricesUpToDay);
      if (analysisResult == null) continue;

      final context = _analysis.buildContext(
        analysisResult,
        priceHistory: pricesUpToDay,
        evaluationTime: currentPrice.date,
        // marketData: null — 4 current-day-only rules 不會 fire，自然被 cut
      );

      final stockData = _buildStockData(
        symbol: symbol,
        data: data,
        pricesUpToDay: pricesUpToDay,
        currentDate: currentPrice.date,
      );

      final reasons = _ruleEngine.evaluateStock(context, stockData);
      daysEvaluated++;

      if (reasons.isEmpty) continue;

      // Forward return: i + shortDays, i + longDays
      final shortExit = prices[i + shortDays].close;
      final longExit = prices[i + longDays].close;
      if (shortExit == null || longExit == null) continue;

      final shortReturn = (shortExit / entryClose - 1) * 100;
      final longReturn = (longExit / entryClose - 1) * 100;

      for (final reason in reasons) {
        final ruleId = reason.type.code;
        final stats = ruleStats.putIfAbsent(ruleId, RuleStats.new);
        stats.short.addSample(shortReturn, shortThreshold);
        stats.long.addSample(longReturn, longThreshold);
        firingsRecorded++;
      }
    }

    return _PerSymbolResult(days: daysEvaluated, firings: firingsRecorded);
  }

  /// 組裝特定日期 cut-off 的 [StockData]
  ///
  /// 所有 history list 都會被過濾成 `date <= currentDate`。非 backfillable
  /// 的欄位（dividendHistory / news / marketData）傳 null，讓對應 rules
  /// 自然 no-fire。
  StockData _buildStockData({
    required String symbol,
    required _BackfilledData data,
    required List<DailyPriceEntry> pricesUpToDay,
    required DateTime currentDate,
  }) {
    final institutional = data.institutionalBySymbol[symbol]
        ?.where((e) => !e.date.isAfter(currentDate))
        .toList();

    final revenueHistory = data.revenueBySymbol[symbol]
        ?.where((e) => !e.date.isAfter(currentDate))
        .toList();
    // Revenue history 需要依時間降序（最新在前）
    revenueHistory?.sort((a, b) => b.date.compareTo(a.date));
    final latestRevenue = revenueHistory == null || revenueHistory.isEmpty
        ? null
        : revenueHistory.first;

    final valuationHistory = data.valuationBySymbol[symbol]
        ?.where((e) => !e.date.isAfter(currentDate))
        .toList();
    valuationHistory?.sort((a, b) => b.date.compareTo(a.date));
    final latestValuation = valuationHistory == null || valuationHistory.isEmpty
        ? null
        : valuationHistory.first;

    final epsHistory = data.epsBySymbol[symbol]
        ?.where((e) => !e.date.isAfter(currentDate))
        .toList();
    epsHistory?.sort((a, b) => b.date.compareTo(a.date));

    final roeHistory = data.roeBySymbol[symbol]
        ?.where((e) => !e.date.isAfter(currentDate))
        .toList();
    roeHistory?.sort((a, b) => b.date.compareTo(a.date));

    double? maxRevenue;
    if (revenueHistory != null && revenueHistory.isNotEmpty) {
      maxRevenue = revenueHistory
          .map((r) => r.revenue)
          .reduce((a, b) => a > b ? a : b);
    }

    return StockData(
      symbol: symbol,
      prices: pricesUpToDay,
      institutional: institutional,
      latestRevenue: latestRevenue,
      latestValuation: latestValuation,
      revenueHistory: revenueHistory,
      epsHistory: epsHistory,
      roeHistory: roeHistory,
      maxHistoricalRevenue: maxRevenue,
      // news / dividendHistory — not backfilled, leave null
    );
  }

  /// 從 DB 載入所有 backfilled 資料到 in-memory maps
  Future<_BackfilledData> _loadData() async {
    // Stock master — 取得有效 symbol 清單
    final stocks = await db.getAllActiveStocks();
    var symbols = stocks.map((s) => s.symbol).toList();
    if (config.symbolsWhitelist != null &&
        config.symbolsWhitelist!.isNotEmpty) {
      final whitelist = config.symbolsWhitelist!.toSet();
      symbols = symbols.where(whitelist.contains).toList();
    }

    final pricesBySymbol = <String, List<DailyPriceEntry>>{};
    final institutionalBySymbol = <String, List<DailyInstitutionalEntry>>{};
    final revenueBySymbol = <String, List<MonthlyRevenueEntry>>{};
    final epsBySymbol = <String, List<FinancialDataEntry>>{};
    final roeBySymbol = <String, List<FinancialDataEntry>>{};
    final valuationBySymbol = <String, List<StockValuationEntry>>{};

    // Drift batch queries — 每個 symbol 一次
    for (final symbol in symbols) {
      final allPrices = await db.getPriceHistory(
        symbol,
        startDate: DateTime(2000),
        endDate: DateTime.now(),
      );
      if (allPrices.isEmpty) continue;
      // 確保升序
      allPrices.sort((a, b) => a.date.compareTo(b.date));
      pricesBySymbol[symbol] = allPrices;

      final inst = await db.getInstitutionalHistory(
        symbol,
        startDate: DateTime(2000),
      );
      if (inst.isNotEmpty) institutionalBySymbol[symbol] = inst;
    }

    // Monthly revenue / EPS / valuation — per symbol 查詢
    final bigBang = DateTime(2000);
    for (final symbol in pricesBySymbol.keys) {
      final rev = await db.getMonthlyRevenueHistory(symbol, startDate: bigBang);
      if (rev.isNotEmpty) revenueBySymbol[symbol] = rev;

      final eps = await db.getEPSHistory(symbol);
      if (eps.isNotEmpty) epsBySymbol[symbol] = eps;

      final roeMap = await db.getROEHistoryBatch([symbol]);
      if (roeMap[symbol] != null && roeMap[symbol]!.isNotEmpty) {
        roeBySymbol[symbol] = roeMap[symbol]!;
      }

      final val = await db.getValuationHistory(symbol, startDate: bigBang);
      if (val.isNotEmpty) valuationBySymbol[symbol] = val;
    }

    return _BackfilledData(
      pricesBySymbol: pricesBySymbol,
      institutionalBySymbol: institutionalBySymbol,
      revenueBySymbol: revenueBySymbol,
      epsBySymbol: epsBySymbol,
      roeBySymbol: roeBySymbol,
      valuationBySymbol: valuationBySymbol,
    );
  }

  /// Upsert rule_accuracy rows
  ///
  /// 每條 rule 寫入兩行：period = '5D' / '60D'，對齊 rule_accuracy_service
  /// 的 dual-horizon 行為。`tool/recalibrate.dart` 也只讀這兩個 period。
  /// 'ALL' period 已於 2026-04 移除（混 threshold 算 hit_rate 數學上沒意義）。
  Future<void> _writeRuleAccuracy(Map<String, RuleStats> ruleStats) async {
    await db.transaction(() async {
      // 先清空既有的 rule_accuracy（replay 每次跑完全覆寫，不增量）
      await db.delete(db.ruleAccuracy).go();

      for (final entry in ruleStats.entries) {
        final ruleId = entry.key;
        final stats = entry.value;

        // 5D
        await db
            .into(db.ruleAccuracy)
            .insertOnConflictUpdate(
              RuleAccuracyCompanion.insert(
                ruleId: ruleId,
                period: '5D',
                triggerCount: Value(stats.short.triggerCount),
                successCount: Value(stats.short.successCount),
                avgReturn: Value(stats.short.avgReturn),
              ),
            );

        // 60D
        await db
            .into(db.ruleAccuracy)
            .insertOnConflictUpdate(
              RuleAccuracyCompanion.insert(
                ruleId: ruleId,
                period: '60D',
                triggerCount: Value(stats.long.triggerCount),
                successCount: Value(stats.long.successCount),
                avgReturn: Value(stats.long.avgReturn),
              ),
            );
      }
    });
  }

  void _logDryRunPlan(_BackfilledData data) {
    _log('');
    _log('DRY RUN PLAN:');
    _log('  Symbols with prices: ${data.pricesBySymbol.length}');
    final totalDays = data.pricesBySymbol.values
        .map((prices) => prices.length)
        .fold<int>(0, (sum, n) => sum + n);
    _log('  Total price rows: $totalDays');
    _log('  Min history days: ${config.minHistoryDays}');
    _log('  Forward window: 60 trading days (60D horizon)');
    final eligibleDays = data.pricesBySymbol.values
        .map((prices) {
          final available = prices.length - config.minHistoryDays - 60;
          return available < 0 ? 0 : available;
        })
        .fold<int>(0, (sum, n) => sum + n);
    _log('  Eligible (day, symbol) pairs: $eligibleDays');
    _log(
      '  Est. runtime: ~${_formatDuration(Duration(seconds: eligibleDays ~/ 200))} '
      '(estimated at 200 eval/sec)',
    );
  }

  void _logSummary(ReplayResult result) {
    _log('');
    _log('=' * 60);
    _log('✅ REPLAY CALIBRATION COMPLETE');
    _log('=' * 60);
    _log('Symbols processed: ${result.symbolsProcessed}');
    _log('Days evaluated:    ${result.daysProcessed}');
    _log('Total firings:     ${result.totalFirings}');
    _log('Rules observed:    ${result.rulesObserved}');
    _log('Duration:          ${_formatDuration(result.duration)}');
    _log('');
    _log('Top 10 rules by trigger count (short + long):');
    final sorted = result.ruleStats.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.short.triggerCount + a.value.long.triggerCount;
        final bTotal = b.value.short.triggerCount + b.value.long.triggerCount;
        return bTotal.compareTo(aTotal);
      });
    for (final e in sorted.take(10)) {
      final s = e.value.short;
      final l = e.value.long;
      _log(
        '  ${e.key.padRight(32)} '
        'short: n=${s.triggerCount.toString().padLeft(5)} '
        'hit=${(s.hitRate * 100).toStringAsFixed(1)}% '
        'avg=${s.avgReturn.toStringAsFixed(2)}%  |  '
        'long: n=${l.triggerCount.toString().padLeft(5)} '
        'hit=${(l.hitRate * 100).toStringAsFixed(1)}% '
        'avg=${l.avgReturn.toStringAsFixed(2)}%',
      );
    }
  }
}

// ============================================================================
// Internal data structures
// ============================================================================

class _BackfilledData {
  const _BackfilledData({
    required this.pricesBySymbol,
    required this.institutionalBySymbol,
    required this.revenueBySymbol,
    required this.epsBySymbol,
    required this.roeBySymbol,
    required this.valuationBySymbol,
  });

  final Map<String, List<DailyPriceEntry>> pricesBySymbol;
  final Map<String, List<DailyInstitutionalEntry>> institutionalBySymbol;
  final Map<String, List<MonthlyRevenueEntry>> revenueBySymbol;
  final Map<String, List<FinancialDataEntry>> epsBySymbol;
  final Map<String, List<FinancialDataEntry>> roeBySymbol;
  final Map<String, List<StockValuationEntry>> valuationBySymbol;
}

class _PerSymbolResult {
  const _PerSymbolResult({required this.days, required this.firings});
  final int days;
  final int firings;
}

// ============================================================================
// CLI entry
// ============================================================================

/// Dart CLI main — [runReplayCalibratorCli] 的 thin wrapper。見
/// [runBackfillCli] 同樣的設計動機。
Future<void> main(List<String> args) async {
  final code = await runReplayCalibratorCli(args);
  exit(code);
}

/// 不呼叫 [exit] 的 replay calibrator 入口函式。供 test wrapper 使用。
///
/// 返回 exit code：
///   0 — 成功
///   1 — 無效 CLI 參數
///   2 — DB 檔案不存在（未 backfill）
///   3 — 沒有任何 rule firing（資料太少）
Future<int> runReplayCalibratorCli(List<String> args) async {
  final config = _parseArgs(args);
  if (config == null) {
    _printUsage(stderr);
    return 1;
  }

  if (!File(config.dbPath).existsSync()) {
    stderr.writeln('❌ DB 檔案不存在: ${config.dbPath}');
    stderr.writeln('💡 先跑 backfill（見 scripts/calibrate.sh）');
    return 2;
  }

  print('📦 開啟 calibration DB: ${config.dbPath}');
  final db = AppDatabase.forToolFile(config.dbPath);

  try {
    final calibrator = ReplayCalibrator(db: db, config: config);
    final result = await calibrator.run();
    if (result.rulesObserved == 0 && !config.dryRun) {
      stderr.writeln('⚠️  沒有 rule firing — 檢查 backfill 資料是否完整');
      return 3;
    }
    return 0;
  } finally {
    await db.close();
  }
}

ReplayConfig? _parseArgs(List<String> args) {
  var dbPath = 'tool/calibration.db';
  var minHistoryDays = RuleParams.swingWindow;
  var dryRun = false;
  List<String>? symbolsWhitelist;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--db':
        if (i + 1 >= args.length) return null;
        dbPath = args[++i];
      case '--min-history':
        if (i + 1 >= args.length) return null;
        final parsed = int.tryParse(args[++i]);
        if (parsed == null || parsed < 1) {
          stderr.writeln('❌ Invalid --min-history: must be positive integer');
          return null;
        }
        minHistoryDays = parsed;
      case '--symbols':
        if (i + 1 >= args.length) return null;
        symbolsWhitelist = args[++i]
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      case '--dry-run':
        dryRun = true;
      case '--help' || '-h':
        return null;
      default:
        stderr.writeln('❌ Unknown arg: $arg');
        return null;
    }
  }

  return ReplayConfig(
    dbPath: dbPath,
    minHistoryDays: minHistoryDays,
    dryRun: dryRun,
    symbolsWhitelist: symbolsWhitelist,
  );
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/replay_calibrator.dart '
    '[--db <path>] [--min-history <N>] [--symbols <csv>] [--dry-run]',
  );
  sink.writeln('');
  sink.writeln('Replay historical rule firings and populate rule_accuracy');
  sink.writeln('table for Stage 4 calibration consumption.');
  sink.writeln('');
  sink.writeln('Options:');
  sink.writeln(
    '  --db <path>         SQLite from tool/backfill.dart (default: tool/calibration.db)',
  );
  sink.writeln(
    '  --min-history <N>   Min price history days per eval (default: ${RuleParams.swingWindow})',
  );
  sink.writeln('  --symbols <csv>     Whitelist for quick test runs');
  sink.writeln('  --dry-run           Print plan without replaying');
  sink.writeln('  --help, -h          Show this help');
}

// ============================================================================
// Formatting helpers
// ============================================================================

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h${d.inMinutes.remainder(60)}m';
  } else if (d.inMinutes > 0) {
    return '${d.inMinutes}m${d.inSeconds.remainder(60)}s';
  } else {
    return '${d.inSeconds}s';
  }
}
