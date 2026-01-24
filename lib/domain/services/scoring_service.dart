import 'dart:convert';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

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
    var stocksWithData = 0;
    var stocksWithSufficientData = 0;
    for (final symbol in candidates) {
      final prices = pricesMap[symbol];
      if (prices != null && prices.isNotEmpty) {
        stocksWithData++;
        if (prices.length >= RuleParams.swingWindow) {
          stocksWithSufficientData++;
        }
      }
    }
    AppLogger.info(
      'ScoringService',
      'scoreStocks: ${candidates.length} candidates, '
          '$stocksWithData with data, $stocksWithSufficientData with sufficient data '
          '(need >= ${RuleParams.swingWindow} days)',
    );

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

      // 檢查最小成交金額與成交量（流動性過濾）
      final latest = prices.last;
      if (latest.close == null || latest.volume == null) {
        skippedNoData++;
        continue;
      }

      // 檢查成交量（股數）
      if (latest.volume! < RuleParams.minCandidateVolumeShares) {
        skippedLowLiquidity++;
        continue;
      }

      // 檢查成交金額（價格 * 股數）
      final turnover = latest.close! * latest.volume!;
      if (turnover < RuleParams.minCandidateTurnover) {
        skippedLowLiquidity++;
        continue;
      }

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

      // 儲存分析結果
      await _analysisRepo.saveAnalysis(
        symbol: symbol,
        date: date,
        trendState: analysisResult.trendState.code,
        reversalState: analysisResult.reversalState.code,
        supportLevel: analysisResult.supportLevel,
        resistanceLevel: analysisResult.resistanceLevel,
        score: score.toDouble(),
      );

      // 儲存原因
      await _analysisRepo.saveReasons(
        symbol,
        date,
        topReasons
            .map(
              (r) => ReasonData(
                type: r.type.code,
                evidenceJson: r.evidenceJson != null
                    ? jsonEncode(r.evidenceJson)
                    : '{}',
                score: r.score,
              ),
            )
            .toList(),
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
    AppLogger.info(
      'ScoringService',
      'scoreStocks complete: ${scoredStocks.length} scored, '
          'skipped $skippedNoData (no data) + $skippedInsufficientData (insufficient data) '
          '+ $skippedLowLiquidity (low liquidity) + $skippedLowScore (score < ${RuleParams.minScoreThreshold})',
    );

    // 依流動性加權分數排序，具有穩定的平分處理
    // 策略：基礎分數 + 流動性加成
    // 流動性加成：每 1 億成交金額 +2 分（上限 20 分）
    // 這使高成交量股票（10 億成交、60 分）能與低成交量股票（3000 萬成交、80 分）競爭
    // 10 億成交 -> +20 加成 -> 60+20=80
    // 3000 萬成交 -> +0.6 加成 -> 80+0.6=80.6
    //
    // 重要：分數相同時，以成交金額為次要排序（高者優先），
    // 再以股票代碼為第三排序以確保結果一致性
    scoredStocks.sort((a, b) {
      double scoreA = a.score.toDouble();
      double scoreB = b.score.toDouble();

      // 計算加成（上限為 10 億 = 20 分）
      double bonusA = (a.turnover / 100000000) * 2.0;
      if (bonusA > 20) bonusA = 20;

      double bonusB = (b.turnover / 100000000) * 2.0;
      if (bonusB > 20) bonusB = 20;

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
    });

    return scoredStocks;
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
}
