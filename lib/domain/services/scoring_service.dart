import 'dart:convert';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// Service for scoring stock candidates
///
/// Extracted from UpdateService to improve separation of concerns.
/// Handles:
/// - Running analysis on candidates
/// - Applying rule engine
/// - Calculating scores
/// - Saving analysis results
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

  /// Score a list of stock candidates
  ///
  /// Takes pre-loaded batch data to avoid N+1 queries.
  /// Returns list of [ScoredStock] sorted by score descending.
  Future<List<ScoredStock>> scoreStocks({
    required List<String> candidates,
    required DateTime date,
    required Map<String, List<DailyPriceEntry>> pricesMap,
    required Map<String, List<NewsItemEntry>> newsMap,
    Map<String, List<DailyInstitutionalEntry>>? institutionalMap,
    Map<String, MonthlyRevenueEntry>? revenueMap,
    Map<String, StockValuationEntry>? valuationMap,
    Set<String>? recentlyRecommended,
    Future<MarketDataContext?> Function(String)? marketDataBuilder,
    void Function(int current, int total)? onProgress,
  }) async {
    if (candidates.isEmpty) return [];

    final scoredStocks = <ScoredStock>[];
    final recentSet = recentlyRecommended ?? <String>{};
    final instMap =
        institutionalMap ?? <String, List<DailyInstitutionalEntry>>{};

    // Log price data statistics
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

    // Process each candidate with pre-loaded data
    var skippedNoData = 0;
    var skippedInsufficientData = 0;

    for (var i = 0; i < candidates.length; i++) {
      final symbol = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      // Get price history from batch-loaded data
      final prices = pricesMap[symbol];
      if (prices == null || prices.isEmpty) {
        skippedNoData++;
        continue;
      }
      if (prices.length < RuleParams.swingWindow) {
        skippedInsufficientData++;
        continue;
      }

      // Run analysis
      final analysisResult = _analysisService.analyzeStock(prices);
      if (analysisResult == null) continue;

      // Build market data context for Phase 4 signals (optional)
      MarketDataContext? marketData;
      if (marketDataBuilder != null) {
        marketData = await marketDataBuilder(symbol);
      }

      // Build context for rule engine
      final context = _analysisService.buildContext(
        analysisResult,
        priceHistory: prices,
        marketData: marketData,
      );

      // Get optional data from batch-loaded maps
      final institutionalHistory = instMap[symbol];
      final recentNews = newsMap[symbol];

      // Run rule engine
      final reasons = _ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        institutionalHistory: institutionalHistory,
        recentNews: recentNews,
        symbol: symbol,
        latestRevenue: revenueMap?[symbol],
        latestValuation: valuationMap?[symbol],
      );

      if (reasons.isEmpty) continue;

      // Calculate score
      final wasRecent = recentSet.contains(symbol);
      final score = _ruleEngine.calculateScore(
        reasons,
        wasRecentlyRecommended: wasRecent,
      );

      // Get top reasons
      final topReasons = _ruleEngine.getTopReasons(reasons);

      // Save analysis result
      await _analysisRepo.saveAnalysis(
        symbol: symbol,
        date: date,
        trendState: analysisResult.trendState.code,
        reversalState: analysisResult.reversalState.code,
        supportLevel: analysisResult.supportLevel,
        resistanceLevel: analysisResult.resistanceLevel,
        score: score.toDouble(),
      );

      // Save reasons
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
        ScoredStock(symbol: symbol, score: score, reasons: topReasons),
      );
    }

    // Log analysis statistics
    AppLogger.info(
      'ScoringService',
      'scoreStocks complete: ${scoredStocks.length} scored, '
          'skipped $skippedNoData (no data) + $skippedInsufficientData (insufficient data)',
    );

    // Sort by score descending
    scoredStocks.sort((a, b) => b.score.compareTo(a.score));

    return scoredStocks;
  }
}

/// Stock with calculated score
class ScoredStock {
  const ScoredStock({
    required this.symbol,
    required this.score,
    required this.reasons,
  });

  final String symbol;
  final int score;
  final List<TriggeredReason> reasons;
}
