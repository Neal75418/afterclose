import 'dart:convert';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/liquidity_checker.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/scoring_isolate.dart';

/// 股票候選評分服務
///
/// 從 UpdateService 抽離以改善關注點分離
/// 處理：
/// - 對候選股票執行分析
/// - 套用規則引擎
/// - 計算分數
/// - 儲存分析結果
class ScoringService {
  const ScoringService({
    required AnalysisService analysisService,
    required RuleEngine ruleEngine,
    required AnalysisRepository analysisRepository,
  }) : _analysisService = analysisService,
       _ruleEngine = ruleEngine,
       _analysisRepo = analysisRepository;

  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;
  final AnalysisRepository _analysisRepo;

  /// 對股票候選清單評分
  ///
  /// 使用預先載入的批次資料以避免 N+1 查詢問題
  /// 回傳依分數由高至低排序的 [ScoredStock] 清單
  Future<List<ScoredStock>> scoreStocks({
    required List<String> candidates,
    required DateTime date,
    required Map<String, List<DailyPriceEntry>> pricesMap,
    required Map<String, List<NewsItemEntry>> newsMap,
    Map<String, List<DailyInstitutionalEntry>>? institutionalMap,
    Map<String, MonthlyRevenueEntry>? revenueMap,
    Map<String, StockValuationEntry>? valuationMap,
    Map<String, List<MonthlyRevenueEntry>>? revenueHistoryMap,
    Map<String, List<FinancialDataEntry>>? epsHistoryMap,
    Map<String, List<FinancialDataEntry>>? roeHistoryMap,
    Map<String, List<DividendHistoryEntry>>? dividendHistoryMap,
    Set<String>? recentlyRecommended,
    Future<MarketDataContext?> Function(String)? marketDataBuilder,
    void Function(int current, int total)? onProgress,
  }) async {
    if (candidates.isEmpty) return [];

    final scoredStocks = <ScoredStock>[];
    final recentSet = recentlyRecommended ?? <String>{};
    final instMap =
        institutionalMap ?? <String, List<DailyInstitutionalEntry>>{};

    // 記錄價格資料統計
    _logCandidateStats(candidates, pricesMap);

    // 使用預載資料處理每個候選
    var skippedNoData = 0;
    var skippedInsufficientData = 0;
    var skippedLowLiquidity = 0;
    var skippedLowScore = 0;

    for (var i = 0; i < candidates.length; i++) {
      final symbol = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      // 從批次載入資料取得價格歷史
      final prices = pricesMap[symbol];
      if (prices == null || prices.isEmpty) {
        skippedNoData++;
        continue;
      }
      if (prices.length < RuleParams.swingWindow) {
        skippedInsufficientData++;
        continue;
      }

      // 流動性過濾（使用共用工具）
      final latest = prices.last;
      final liquidityResult = LiquidityChecker.checkCandidateLiquidity(latest);
      if (liquidityResult != null) {
        if (liquidityResult == 'MISSING_DATA') {
          skippedNoData++;
        } else {
          skippedLowLiquidity++;
        }
        continue;
      }
      final turnover = latest.close! * latest.volume!;

      // 執行分析
      final analysisResult = _analysisService.analyzeStock(prices);
      if (analysisResult == null) continue;

      // 為第 4 階段訊號建立市場資料上下文（可選）
      MarketDataContext? marketData;
      if (marketDataBuilder != null) {
        marketData = await marketDataBuilder(symbol);
      }

      // 為規則引擎建立上下文
      final context = _analysisService.buildContext(
        analysisResult,
        priceHistory: prices,
        marketData: marketData,
      );

      // 從批次載入的 map 取得可選資料
      final institutionalHistory = instMap[symbol];
      final recentNews = newsMap[symbol];

      // 執行規則引擎
      final reasons = _ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        institutionalHistory: institutionalHistory,
        recentNews: recentNews,
        symbol: symbol,
        latestRevenue: revenueMap?[symbol],
        latestValuation: valuationMap?[symbol],
        revenueHistory: revenueHistoryMap?[symbol],
        epsHistory: epsHistoryMap?[symbol],
        roeHistory: roeHistoryMap?[symbol],
        dividendHistory: dividendHistoryMap?[symbol],
      );

      if (reasons.isEmpty) continue;

      // 計算分數
      final wasRecent = recentSet.contains(symbol);
      final score = _ruleEngine.calculateScore(
        reasons,
        wasRecentlyRecommended: wasRecent,
      );

      // 跳過低分股票（僅有弱訊號）
      if (score < RuleParams.minScoreThreshold) {
        skippedLowScore++;
        continue;
      }

      // 取得前幾個原因
      final topReasons = _ruleEngine.getTopReasons(reasons);

      // 轉換為 ReasonData 並儲存
      final reasonDataList = topReasons
          .map(
            (r) => ReasonData(
              type: r.type.code,
              evidenceJson: r.evidenceJson != null
                  ? jsonEncode(r.evidenceJson)
                  : '{}',
              score: r.score,
            ),
          )
          .toList();

      await _persistAnalysisResult(
        symbol: symbol,
        date: date,
        trendState: analysisResult.trendState.code,
        reversalState: analysisResult.reversalState.code,
        supportLevel: analysisResult.supportLevel,
        resistanceLevel: analysisResult.resistanceLevel,
        score: score.toDouble(),
        reasons: reasonDataList,
      );

      scoredStocks.add(
        ScoredStock(
          symbol: symbol,
          score: score,
          turnover: turnover,
          reasons: topReasons,
        ),
      );
    }

    // 記錄分析統計
    _logScoringResults(
      scoredStocks,
      skippedNoData,
      skippedInsufficientData,
      skippedLowLiquidity,
      skippedLowScore,
    );

    // 依流動性加權分數排序
    scoredStocks.sort(ScoredStock.compareByWeightedScore);

    return scoredStocks;
  }

  /// 在背景 Isolate 中對股票候選清單評分
  ///
  /// 此方法將運算移至背景執行緒，避免阻塞 UI。
  /// 使用預先載入的 dayTradingMap 支援當沖相關規則。
  ///
  /// 適用於：批量掃描、每日更新等場景
  Future<List<ScoredStock>> scoreStocksInIsolate({
    required List<String> candidates,
    required DateTime date,
    required Map<String, List<DailyPriceEntry>> pricesMap,
    required Map<String, List<NewsItemEntry>> newsMap,
    Map<String, List<DailyInstitutionalEntry>>? institutionalMap,
    Map<String, MonthlyRevenueEntry>? revenueMap,
    Map<String, StockValuationEntry>? valuationMap,
    Map<String, List<MonthlyRevenueEntry>>? revenueHistoryMap,
    Set<String>? recentlyRecommended,
    Map<String, double>? dayTradingMap,
    Map<String, Map<String, double?>>? shareholdingMap,
    Map<String, Map<String, dynamic>>? warningMap,
    Map<String, Map<String, dynamic>>? insiderMap,
    Map<String, List<FinancialDataEntry>>? epsHistoryMap,
    Map<String, List<FinancialDataEntry>>? roeHistoryMap,
    Map<String, List<DividendHistoryEntry>>? dividendHistoryMap,
  }) async {
    if (candidates.isEmpty) return [];

    // 記錄價格資料統計
    _logCandidateStats(candidates, pricesMap, suffix: ' (Isolate)');

    // 將資料轉換為可跨 Isolate 傳遞的格式
    final input = ScoringIsolateInput(
      candidates: candidates,
      pricesMap: _convertPricesMap(pricesMap),
      newsMap: _convertNewsMap(newsMap),
      institutionalMap: _convertInstitutionalMap(institutionalMap ?? {}),
      revenueMap: revenueMap != null ? _convertRevenueMap(revenueMap) : null,
      valuationMap: valuationMap != null
          ? _convertValuationMap(valuationMap)
          : null,
      revenueHistoryMap: revenueHistoryMap != null
          ? _convertRevenueHistoryMap(revenueHistoryMap)
          : null,
      recentlyRecommended: recentlyRecommended,
      dayTradingMap: dayTradingMap,
      shareholdingMap: shareholdingMap,
      warningMap: warningMap,
      insiderMap: insiderMap,
      epsHistoryMap: epsHistoryMap != null
          ? _convertEpsHistoryMap(epsHistoryMap)
          : null,
      roeHistoryMap: roeHistoryMap != null
          ? _convertEpsHistoryMap(roeHistoryMap)
          : null,
      dividendHistoryMap: dividendHistoryMap != null
          ? _convertDividendHistoryMap(dividendHistoryMap)
          : null,
    );

    // 在背景 Isolate 執行運算（含回退機制）
    ScoringBatchResult result;
    try {
      result = await evaluateStocksInIsolate(input);
    } catch (e, stackTrace) {
      AppLogger.warning('ScoringSvc', 'Isolate 執行失敗，回退至主執行緒', e, stackTrace);

      // 回退：在主執行緒執行評分，並傳入 marketDataBuilder 以確保市場資料一致性
      return await scoreStocks(
        candidates: candidates,
        date: date,
        pricesMap: pricesMap,
        newsMap: newsMap,
        institutionalMap: institutionalMap,
        revenueMap: revenueMap,
        valuationMap: valuationMap,
        revenueHistoryMap: revenueHistoryMap,
        epsHistoryMap: epsHistoryMap,
        roeHistoryMap: roeHistoryMap,
        dividendHistoryMap: dividendHistoryMap,
        recentlyRecommended: recentlyRecommended,
        marketDataBuilder: (symbol) async {
          return _buildMarketDataFromMaps(
            symbol: symbol,
            dayTradingMap: dayTradingMap,
            shareholdingMap: shareholdingMap,
            warningMap: warningMap,
            insiderMap: insiderMap,
          );
        },
      );
    }

    // 記錄分析統計
    _logScoringResultsFromIsolate(result);

    // 批次儲存分析結果
    for (final output in result.outputs) {
      final reasonDataList = output.reasons
          .map(
            (r) => ReasonData(
              type: r.type,
              evidenceJson: r.evidenceJson,
              score: r.score,
            ),
          )
          .toList();

      await _persistAnalysisResult(
        symbol: output.symbol,
        date: date,
        trendState: output.trendState,
        reversalState: output.reversalState,
        supportLevel: output.supportLevel,
        resistanceLevel: output.resistanceLevel,
        score: output.score.toDouble(),
        reasons: reasonDataList,
      );
    }

    // 轉換為 ScoredStock 並排序
    final scoredStocks = result.outputs
        .map(
          (o) => ScoredStock(
            symbol: o.symbol,
            score: o.score,
            turnover: o.turnover,
            reasons: [], // Isolate 無法返回完整 TriggeredReason，僅用於排序
          ),
        )
        .toList();

    // 依流動性加權分數排序
    scoredStocks.sort(ScoredStock.compareByWeightedScore);

    return scoredStocks;
  }

  // =============================================
  // 日誌輔助方法
  // =============================================

  /// 記錄候選股票的價格資料統計
  void _logCandidateStats(
    List<String> candidates,
    Map<String, List<DailyPriceEntry>> pricesMap, {
    String suffix = '',
  }) {
    var stocksWithSufficientData = 0;
    for (final symbol in candidates) {
      final prices = pricesMap[symbol];
      if (prices != null && prices.length >= RuleParams.swingWindow) {
        stocksWithSufficientData++;
      }
    }
    AppLogger.debug(
      'ScoringSvc',
      '候選 ${candidates.length} 檔，資料充足 $stocksWithSufficientData 檔$suffix',
    );
  }

  /// 記錄主執行緒評分結果統計
  void _logScoringResults(
    List<ScoredStock> scored,
    int skippedNoData,
    int skippedInsufficient,
    int skippedLiquidity,
    int skippedLowScore, {
    String suffix = '',
  }) {
    final maxScore = scored.isEmpty
        ? 0
        : scored.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final skippedTotal =
        skippedNoData +
        skippedInsufficient +
        skippedLiquidity +
        skippedLowScore;
    AppLogger.info(
      'ScoringSvc',
      '評分完成: ${scored.length} 檔 (最高 $maxScore 分), '
          '跳過 $skippedTotal 檔$suffix',
    );
  }

  /// 記錄 Isolate 評分結果統計
  void _logScoringResultsFromIsolate(ScoringBatchResult result) {
    final skippedTotal =
        result.skippedNoData +
        result.skippedInsufficientData +
        result.skippedLowLiquidity +
        result.skippedLowScore;
    final maxScore = result.outputs.isEmpty
        ? 0
        : result.outputs.map((o) => o.score).reduce((a, b) => a > b ? a : b);
    AppLogger.info(
      'ScoringSvc',
      '評分完成: ${result.outputs.length} 檔 (最高 $maxScore 分), '
          '跳過 $skippedTotal 檔 (Isolate)',
    );
  }

  // =============================================
  // 資料儲存輔助方法
  // =============================================

  /// 儲存股票分析結果與觸發原因
  ///
  /// 統一 [scoreStocks] 和 [scoreStocksInIsolate] 的儲存邏輯
  Future<void> _persistAnalysisResult({
    required String symbol,
    required DateTime date,
    required String trendState,
    required String reversalState,
    required double? supportLevel,
    required double? resistanceLevel,
    required double score,
    required List<ReasonData> reasons,
  }) async {
    await _analysisRepo.saveAnalysis(
      symbol: symbol,
      date: date,
      trendState: trendState,
      reversalState: reversalState,
      supportLevel: supportLevel,
      resistanceLevel: resistanceLevel,
      score: score,
    );
    await _analysisRepo.saveReasons(symbol, date, reasons);
  }

  // =============================================
  // 市場資料建構輔助方法（Isolate 回退時使用）
  // =============================================

  /// 從 Map 建構 MarketDataContext
  ///
  /// 用於 Isolate 回退時，確保市場資料一致性
  MarketDataContext? _buildMarketDataFromMaps({
    required String symbol,
    Map<String, double>? dayTradingMap,
    Map<String, Map<String, double?>>? shareholdingMap,
    Map<String, Map<String, dynamic>>? warningMap,
    Map<String, Map<String, dynamic>>? insiderMap,
  }) {
    final dayTradingRatio = dayTradingMap?[symbol];
    final shareholding = shareholdingMap?[symbol];
    final warning = warningMap?[symbol];
    final insider = insiderMap?[symbol];

    // 若全部都沒有資料，回傳 null
    if (dayTradingRatio == null &&
        shareholding == null &&
        warning == null &&
        insider == null) {
      return null;
    }

    // 建構警示資料
    WarningDataContext? warningData;
    if (warning != null) {
      final warningType = warning['warningType'] as String?;
      warningData = WarningDataContext(
        isAttention: warningType == 'ATTENTION',
        isDisposal: warningType == 'DISPOSAL',
        warningType: warningType,
        reasonDescription: warning['reasonDescription'] as String?,
        disposalMeasures: warning['disposalMeasures'] as String?,
        disposalEndDate: warning['disposalEndDate'] != null
            ? DateTime.tryParse(warning['disposalEndDate'] as String)
            : null,
      );
    }

    // 建構董監持股資料
    InsiderDataContext? insiderData;
    if (insider != null) {
      insiderData = InsiderDataContext(
        insiderRatio: insider['insiderRatio'] as double?,
        pledgeRatio: insider['pledgeRatio'] as double?,
        hasSellingStreak: insider['hasSellingStreak'] as bool? ?? false,
        sellingStreakMonths: insider['sellingStreakMonths'] as int? ?? 0,
        hasSignificantBuying: insider['hasSignificantBuying'] as bool? ?? false,
        buyingChange: insider['buyingChange'] as double?,
      );
    }

    return MarketDataContext(
      dayTradingRatio: dayTradingRatio,
      foreignSharesRatio: shareholding?['foreignSharesRatio'],
      foreignSharesRatioChange: shareholding?['foreignSharesRatioChange'],
      concentrationRatio: shareholding?['concentrationRatio'],
      warningData: warningData,
      insiderData: insiderData,
    );
  }

  // =============================================
  // 資料轉換輔助方法
  // =============================================

  Map<String, List<Map<String, dynamic>>> _convertPricesMap(
    Map<String, List<DailyPriceEntry>> map,
  ) {
    return map.map(
      (key, value) => MapEntry(key, value.map(dailyPriceEntryToMap).toList()),
    );
  }

  Map<String, List<Map<String, dynamic>>> _convertNewsMap(
    Map<String, List<NewsItemEntry>> map,
  ) {
    return map.map(
      (key, value) => MapEntry(key, value.map(newsItemEntryToMap).toList()),
    );
  }

  Map<String, List<Map<String, dynamic>>> _convertInstitutionalMap(
    Map<String, List<DailyInstitutionalEntry>> map,
  ) {
    return map.map(
      (key, value) =>
          MapEntry(key, value.map(dailyInstitutionalEntryToMap).toList()),
    );
  }

  Map<String, Map<String, dynamic>> _convertRevenueMap(
    Map<String, MonthlyRevenueEntry> map,
  ) {
    return map.map(
      (key, value) => MapEntry(key, monthlyRevenueEntryToMap(value)),
    );
  }

  Map<String, Map<String, dynamic>> _convertValuationMap(
    Map<String, StockValuationEntry> map,
  ) {
    return map.map(
      (key, value) => MapEntry(key, stockValuationEntryToMap(value)),
    );
  }

  Map<String, List<Map<String, dynamic>>> _convertRevenueHistoryMap(
    Map<String, List<MonthlyRevenueEntry>> map,
  ) {
    return map.map(
      (key, value) =>
          MapEntry(key, value.map(monthlyRevenueEntryToMap).toList()),
    );
  }

  Map<String, List<Map<String, dynamic>>> _convertEpsHistoryMap(
    Map<String, List<FinancialDataEntry>> map,
  ) {
    return map.map(
      (key, value) =>
          MapEntry(key, value.map(financialDataEntryToMap).toList()),
    );
  }

  Map<String, List<Map<String, dynamic>>> _convertDividendHistoryMap(
    Map<String, List<DividendHistoryEntry>> map,
  ) {
    return map.map(
      (key, value) =>
          MapEntry(key, value.map(dividendHistoryEntryToMap).toList()),
    );
  }
}

/// 已計算分數的股票
class ScoredStock {
  const ScoredStock({
    required this.symbol,
    required this.score,
    required this.turnover,
    required this.reasons,
  });

  final String symbol;
  final int score;
  final double turnover;
  final List<TriggeredReason> reasons;

  /// 依流動性加權分數排序的比較函數
  ///
  /// 策略：基礎分數 + 流動性加成
  /// 流動性加成：每 1 億成交金額 +2 分（上限 20 分）
  /// 這使高成交量股票（10 億成交、60 分）能與低成交量股票（3000 萬成交、80 分）競爭
  ///
  /// 排序優先順序：
  /// 1. 主要：總分（由高至低）
  /// 2. 次要：成交金額（由高至低）- 優先選擇流動性較高的股票
  /// 3. 第三：股票代碼（由低至高）- 確保平分處理結果一致
  static int compareByWeightedScore(ScoredStock a, ScoredStock b) {
    final double scoreA = a.score.toDouble();
    final double scoreB = b.score.toDouble();

    // 計算加成（上限為 10 億 = 20 分）
    double bonusA =
        (a.turnover / RuleParams.liquidityTurnoverUnit) *
        RuleParams.liquidityBonusPerUnit;
    if (bonusA > RuleParams.liquidityBonusMax) {
      bonusA = RuleParams.liquidityBonusMax;
    }

    double bonusB =
        (b.turnover / RuleParams.liquidityTurnoverUnit) *
        RuleParams.liquidityBonusPerUnit;
    if (bonusB > RuleParams.liquidityBonusMax) {
      bonusB = RuleParams.liquidityBonusMax;
    }

    // 四捨五入至小數點後 2 位以避免浮點數精度問題
    final totalA = ((scoreA + bonusA) * 100).round() / 100;
    final totalB = ((scoreB + bonusB) * 100).round() / 100;

    // 主要：總分（由高至低）
    final scoreCmp = totalB.compareTo(totalA);
    if (scoreCmp != 0) return scoreCmp;

    // 次要：成交金額（由高至低）- 優先選擇流動性較高的股票
    final turnoverCmp = b.turnover.compareTo(a.turnover);
    if (turnoverCmp != 0) return turnoverCmp;

    // 第三：股票代碼（由低至高）- 確保平分處理結果一致
    return a.symbol.compareTo(b.symbol);
  }
}
