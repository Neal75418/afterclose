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
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;

import 'package:afterclose/core/constants/calibration_thresholds.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
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
    this.excessReturn = true,
    this.minUniverseSymbols = 100,
    this.excessSuccessThreshold = 0.0,
    this.dateFilter,
    this.excludeFilter,
  });

  final String dbPath;

  /// 股票必須至少有這麼多天歷史才開始評估
  final int minHistoryDays;

  final bool dryRun;

  /// 可選 whitelist（測試用，限定 symbol 範圍）
  final List<String>? symbolsWhitelist;

  /// 橫斷面超額報酬模式：forward return 減去「當日全市場平均 forward
  /// return」，去除多空 beta，量測訊號的相對 alpha。false = 舊的絕對報酬
  /// （供 walk-forward 新舊對比）。
  final bool excessReturn;

  /// 計算當日 universe 均值所需的最小 symbol 數。某交易日有效樣本不足
  /// （半套日 / 稀疏歷史）時，該日的均值不可靠 → 跳過該日所有 firing。
  final int minUniverseSymbols;

  /// 超額報酬模式下的命中門檻（百分點）。預設 0 = 「贏過當日大盤平均」。
  /// 刻意不沿用 [CalibrationThresholds]（那是絕對報酬語意、且與 runtime
  /// rule_accuracy 共用，改它會動到 app 顯示）。
  final double excessSuccessThreshold;

  /// 可選日期過濾（含頭含尾）。供 walk-forward 限定校準窗使用。
  /// null = 不過濾（用全部 backfill 資料）。
  final ({DateTime? start, DateTime? end})? dateFilter;

  /// 可選日期排除（含頭含尾）。entry 落在此區間的 firing 被跳過。
  /// 供 walk-forward leave-one-year-out 的「train = 除測試年外全部」使用。
  /// 與 [dateFilter] 互斥語意：dateFilter 限「窗內」、excludeFilter 排「窗內」。
  final ({DateTime start, DateTime end})? excludeFilter;
}

/// 分數層驗證 sink：對「有訊號」的股票日，回報加總後的手調分及其 5D / 60D
/// forward return。供 tool/score_validate.dart 量測「composite 分數 → 未來
/// 報酬」的單調性（高分股是否真的更會漲）。
/// [score] 是已 clamp [0, maxScore] 的對外分；[rawScore] 是**未封頂**原始加總
/// （供「天花板內部用原始分還分不分得出報酬」的排序鍵驗證）。
/// [volatility] 是進場日「過去 20 日日報酬標準差(%)」（供 C 風險調整驗證：
/// 高分股裡偏好低波動者,勝率會不會升）。
/// [trendPct] 是進場日 close 相對 60 日均線的偏離(%)，>0 多頭、<0 空頭（供
/// B-個股趨勢 / 分模式驗證）。
/// [modeMomentum]/[modeStrength]/[modePullback] 是該股票日「起漲 / 強勢 / 回檔」
/// 三模式各自規則的分數加總（供「訊號 vs 同池基準」分模式驗證）。
/// [shortReturn]/[longReturn] 隨 replay 模式為絕對或超額報酬。
typedef ScoreSample = ({
  double score,
  double rawScore,
  double volatility,
  double trendPct,
  double modeMomentum,
  double modeStrength,
  double modePullback,
  double shortReturn,
  double longReturn,
  DateTime date,
});

typedef ScoreSampleSink = void Function(ScoreSample sample);

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
    ScoreSampleSink? scoreSink,
    void Function(String)? logger,
  }) : _analysis = analysisService ?? AnalysisService(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _scoreSink = scoreSink,
       _log = logger ?? print;

  final AppDatabase db;
  final ReplayConfig config;
  final AnalysisService _analysis;
  final RuleEngine _ruleEngine;
  final ScoreSampleSink? _scoreSink;
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

    // 2a. 橫斷面 universe 均值 forward return（每個交易日一個值）— 供超額
    // 報酬扣除多空 beta 用。只在 excessReturn 模式下計算。
    _UniverseMeans? universeMeans;
    if (config.excessReturn) {
      _log('');
      _log('▶️  Computing cross-sectional universe mean returns...');
      universeMeans = _computeUniverseMeanReturns(data);
      _log(
        '✅ Universe means: ${universeMeans.mean5.length} days (5D), '
        '${universeMeans.mean60.length} days (60D)',
      );
    }

    // 2b. Replay 所有 firings + 即時計算 (超額) forward return
    _log('');
    _log(
      '▶️  Replaying rule firings across ${data.pricesBySymbol.length} symbols'
      '${config.excessReturn ? " (excess-return mode)" : " (absolute-return mode)"}...',
    );
    final replayStart = DateTime.now();
    final ruleStats = <String, RuleStats>{};
    var symbolsProcessed = 0;
    var daysProcessed = 0;
    var totalFirings = 0;
    var lastLogAt = DateTime.now();

    for (final symbol in data.pricesBySymbol.keys) {
      symbolsProcessed++;
      final result = _replaySymbol(symbol, data, ruleStats, universeMeans);
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
    _UniverseMeans? universeMeans,
  ) {
    final prices = data.pricesBySymbol[symbol];
    if (prices == null || prices.length < config.minHistoryDays) {
      return const _PerSymbolResult(days: 0, firings: 0);
    }

    const shortDays = 5;
    const longDays = 60;
    // 門檻：超額模式用 excessSuccessThreshold（「贏過大盤即命中」）；
    // 絕對模式沿用 canonical CalibrationThresholds（不在此重寫死值，否則跟
    // RuleAccuracyService 與 recalibrate drift — 過去就是這樣壞掉的）。
    final shortThreshold = config.excessReturn
        ? config.excessSuccessThreshold
        : (CalibrationThresholds.successThresholds[shortDays] ??
              CalibrationThresholds.defaultSuccessThreshold);
    final longThreshold = config.excessReturn
        ? config.excessSuccessThreshold
        : (CalibrationThresholds.successThresholds[longDays] ??
              CalibrationThresholds.defaultSuccessThreshold);

    var daysEvaluated = 0;
    var firingsRecorded = 0;

    for (var i = config.minHistoryDays; i < prices.length; i++) {
      // 確保 forward window 完整（短跟長都要）
      if (i + longDays >= prices.length) break;

      final currentPrice = prices[i];
      final entryClose = currentPrice.close;
      if (entryClose == null || entryClose <= 0) continue;

      // dateFilter：walk-forward 校準窗 — 只把窗內 entry 當 firing（early
      // skip，省下昂貴的 evaluateStock）。universe 均值仍用全部資料計算。
      final df = config.dateFilter;
      if (df != null) {
        if (df.start != null && currentPrice.date.isBefore(df.start!)) continue;
        if (df.end != null && currentPrice.date.isAfter(df.end!)) continue;
      }

      // excludeFilter：leave-one-year-out 的 train = 排除測試年的 entry。
      final ex = config.excludeFilter;
      if (ex != null &&
          !currentPrice.date.isBefore(ex.start) &&
          !currentPrice.date.isAfter(ex.end)) {
        continue;
      }

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

      var shortReturn = (shortExit / entryClose - 1) * 100;
      var longReturn = (longExit / entryClose - 1) * 100;

      // 橫斷面超額：減去當日全市場平均 forward return（去 beta）。
      // 該日 universe 覆蓋不足（半套日 / 稀疏歷史）→ 均值不可靠，跳過。
      if (config.excessReturn) {
        final key = _dateKey(currentPrice.date);
        final m5 = universeMeans!.mean5[key];
        final m60 = universeMeans.mean60[key];
        if (m5 == null ||
            m60 == null ||
            (universeMeans.count5[key] ?? 0) < config.minUniverseSymbols ||
            (universeMeans.count60[key] ?? 0) < config.minUniverseSymbols) {
          continue;
        }
        shortReturn -= m5;
        longReturn -= m60;
      }

      // 分數層驗證 hook（additive；sink 為 null 時零影響）：對有訊號的股票日，
      // 加總手調基礎分並 clamp [0, maxScore]，連同 forward return 交給 sink。
      // 用 reason.score（基礎分）= app 當前實際評分行為（校準層目前全 fallback）。
      if (_scoreSink != null) {
        var raw = 0.0;
        var modeMom = 0.0;
        var modeStr = 0.0;
        var modePul = 0.0;
        for (final reason in reasons) {
          raw += reason.score;
          switch (reason.type.scoringMode) {
            case ScoringMode.momentumEntry:
              modeMom += reason.score;
            case ScoringMode.strengthObserve:
              modeStr += reason.score;
            case ScoringMode.weaknessObserve:
              modePul += reason.score;
            case ScoringMode.neutral:
              break;
          }
        }
        final clamped = raw.clamp(0.0, RuleScores.maxScore.toDouble());
        // 進場日波動度：過去 20 日日報酬標準差(%)。供 C 風險調整驗證。
        const volWindow = 20;
        var volatility = 0.0;
        if (i >= volWindow) {
          final rets = <double>[];
          for (var k = i - volWindow + 1; k <= i; k++) {
            final prev = prices[k - 1].close;
            final cur = prices[k].close;
            if (prev != null && cur != null && prev > 0) {
              rets.add(cur / prev - 1);
            }
          }
          if (rets.length >= 2) {
            final mean = rets.reduce((a, b) => a + b) / rets.length;
            var sq = 0.0;
            for (final r in rets) {
              sq += (r - mean) * (r - mean);
            }
            volatility = math.sqrt(sq / rets.length) * 100;
          }
        }
        // 趨勢 proxy：close 相對 60 日均線偏離(%)。>0 多頭、<0 空頭。
        const maWindow = 60;
        var trendPct = 0.0;
        if (i >= maWindow) {
          var sum = 0.0;
          var cnt = 0;
          for (var k = i - maWindow + 1; k <= i; k++) {
            final c = prices[k].close;
            if (c != null && c > 0) {
              sum += c;
              cnt++;
            }
          }
          if (cnt > 0 && entryClose > 0) {
            trendPct = (entryClose / (sum / cnt) - 1) * 100;
          }
        }
        _scoreSink((
          score: clamped,
          rawScore: raw,
          volatility: volatility,
          trendPct: trendPct,
          modeMomentum: modeMom,
          modeStrength: modeStr,
          modePullback: modePul,
          shortReturn: shortReturn,
          longReturn: longReturn,
          date: currentPrice.date,
        ));
      }

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

    // look-ahead 修正：月營收次月 10 號才公布，故以「公布日」而非「營收月」
    // 過濾，避免訊號偷看尚未公布的營收。
    final revenueHistory = data.revenueBySymbol[symbol]
        ?.where((e) => !revenueVisibleDate(e.date).isAfter(currentDate))
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

    // look-ahead 修正：季財報季末後才公布（Q1-Q3 +45 天、年報次年 3/31），
    // 故以「公布日」過濾。
    final epsHistory = data.epsBySymbol[symbol]
        ?.where((e) => !financialVisibleDate(e.date).isAfter(currentDate))
        .toList();
    epsHistory?.sort((a, b) => b.date.compareTo(a.date));

    final roeHistory = data.roeBySymbol[symbol]
        ?.where((e) => !financialVisibleDate(e.date).isAfter(currentDate))
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

  /// 計算每個交易日的「全市場平均 forward return」（5D / 60D）。
  ///
  /// 對所有 symbol × 所有交易日累加 (date → 報酬)，再除以該日有效樣本數。
  /// 用於橫斷面超額報酬：個股報酬 − 當日均值 = 相對 alpha（去多空 beta）。
  _UniverseMeans _computeUniverseMeanReturns(_BackfilledData data) {
    const shortDays = 5;
    const longDays = 60;
    final sum5 = <DateTime, double>{};
    final cnt5 = <DateTime, int>{};
    final sum60 = <DateTime, double>{};
    final cnt60 = <DateTime, int>{};

    for (final prices in data.pricesBySymbol.values) {
      for (var i = 0; i < prices.length; i++) {
        final entry = prices[i].close;
        if (entry == null || entry <= 0) continue;
        final key = _dateKey(prices[i].date);

        if (i + shortDays < prices.length) {
          final exit = prices[i + shortDays].close;
          if (exit != null && exit > 0) {
            sum5[key] = (sum5[key] ?? 0) + (exit / entry - 1) * 100;
            cnt5[key] = (cnt5[key] ?? 0) + 1;
          }
        }
        if (i + longDays < prices.length) {
          final exit = prices[i + longDays].close;
          if (exit != null && exit > 0) {
            sum60[key] = (sum60[key] ?? 0) + (exit / entry - 1) * 100;
            cnt60[key] = (cnt60[key] ?? 0) + 1;
          }
        }
      }
    }

    final mean5 = <DateTime, double>{};
    final mean60 = <DateTime, double>{};
    sum5.forEach((d, s) => mean5[d] = s / cnt5[d]!);
    sum60.forEach((d, s) => mean60[d] = s / cnt60[d]!);

    return _UniverseMeans(
      mean5: mean5,
      mean60: mean60,
      count5: cnt5,
      count60: cnt60,
    );
  }

  /// 把 DateTime 正規化成 (年,月,日) 當 map key，避免時間分量造成同日不同 key。
  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 月營收的「實際公布日」≈ 次月 10 號（台股月營收揭露慣例）。
  /// [revenueMonthDate] 是營收所屬月份（DB 存該月 1 號）。public 供測試。
  static DateTime revenueVisibleDate(DateTime revenueMonthDate) {
    final isDec = revenueMonthDate.month == 12;
    final year = isDec ? revenueMonthDate.year + 1 : revenueMonthDate.year;
    final month = isDec ? 1 : revenueMonthDate.month + 1;
    return DateTime(year, month, 10);
  }

  /// 季財報的「實際公布日」（台股揭露期限）：Q1≈5/15、Q2≈8/14、Q3≈11/14、
  /// 年報(Q4)次年 3/31。
  ///
  /// ⚠️ 刻意「季正規化」而非對輸入日 +45 天 —— 因 codebase 內財報 date 語意不
  /// 一致（backfill/calibration.db 存季底 3/31…；app 另一路徑 parseQuarterDate
  /// 存季初 1/1…）。本函式從 month 推季號，對「季初或季底」輸入皆給同一公布日，
  /// 消除該歧義。[anyDateInQuarter] 是季內任一日。public 供測試。
  static DateTime financialVisibleDate(DateTime anyDateInQuarter) {
    final quarter = (anyDateInQuarter.month - 1) ~/ 3; // 0=Q1 .. 3=Q4
    final year = anyDateInQuarter.year;
    return switch (quarter) {
      0 => DateTime(year, 5, 15), // Q1 季末後 ~45 天
      1 => DateTime(year, 8, 14), // Q2
      2 => DateTime(year, 11, 14), // Q3
      _ => DateTime(year + 1, 3, 31), // Q4 / 年報
    };
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

/// 每個交易日的全市場平均 forward return（橫斷面均值）+ 有效樣本數。
/// 供超額報酬扣除多空 beta；count 用於半套日 / 稀疏歷史的可靠度 guard。
class _UniverseMeans {
  const _UniverseMeans({
    required this.mean5,
    required this.mean60,
    required this.count5,
    required this.count60,
  });

  final Map<DateTime, double> mean5;
  final Map<DateTime, double> mean60;
  final Map<DateTime, int> count5;
  final Map<DateTime, int> count60;
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
  var excessReturn = true;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--db':
        if (i + 1 >= args.length) return null;
        dbPath = args[++i];
      case '--no-excess':
        // 舊的絕對報酬模式（供新舊對比）。預設走橫斷面超額。
        excessReturn = false;
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
    excessReturn: excessReturn,
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
