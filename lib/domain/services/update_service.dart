import 'package:flutter/foundation.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// Service for orchestrating daily market data updates
///
/// Implements the 10-step daily update pipeline:
/// 1. Check trading day
/// 2. Update stock master
/// 3. Fetch daily prices
/// 4. Fetch institutional data (optional)
/// 5. Fetch RSS news
/// 6. Filter candidates (candidate-first)
/// 7. Run analysis
/// 8. Apply rule engine
/// 9. Generate top 10
/// 10. Mark completion
class UpdateService {
  UpdateService({
    required AppDatabase database,
    required StockRepository stockRepository,
    required PriceRepository priceRepository,
    required NewsRepository newsRepository,
    required AnalysisRepository analysisRepository,
    InstitutionalRepository? institutionalRepository,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
  }) : _db = database,
       _stockRepo = stockRepository,
       _priceRepo = priceRepository,
       _newsRepo = newsRepository,
       _analysisRepo = analysisRepository,
       _institutionalRepo = institutionalRepository,
       _analysisService = analysisService ?? const AnalysisService(),
       _ruleEngine = ruleEngine ?? const RuleEngine();

  /// Default popular Taiwan stocks for free account fallback
  /// These are high-volume stocks that are commonly tracked
  static const _defaultPopularStocks = [
    '2330', // 台積電
    '2317', // 鴻海
    '2454', // 聯發科
    '2308', // 台達電
    '2881', // 富邦金
    '2882', // 國泰金
    '2303', // 聯電
    '3711', // 日月光投控
    '2891', // 中信金
    '2412', // 中華電
    '2886', // 兆豐金
    '1301', // 台塑
    '2884', // 玉山金
    '3037', // 欣興
    '2357', // 華碩
  ];

  final AppDatabase _db;
  final StockRepository _stockRepo;
  final PriceRepository _priceRepo;
  final NewsRepository _newsRepo;
  final AnalysisRepository _analysisRepo;
  final InstitutionalRepository? _institutionalRepo;
  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;

  /// Run the complete daily update pipeline
  ///
  /// Returns [UpdateResult] with details of what was updated
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool forceFetch = false,
    UpdateProgressCallback? onProgress,
  }) async {
    final targetDate = forDate ?? DateTime.now();
    final normalizedDate = _normalizeDate(targetDate);

    // Create update run record
    final runId = await _db.createUpdateRun(
      normalizedDate,
      UpdateStatus.partial.code,
    );

    final result = UpdateResult(date: normalizedDate);

    try {
      // Step 1: Check if trading day
      onProgress?.call(1, 10, '檢查交易日');
      if (!forceFetch && !_isTradingDay(targetDate)) {
        result.skipped = true;
        result.message = '非交易日，跳過更新';
        await _db.finishUpdateRun(
          runId,
          UpdateStatus.success.code,
          message: result.message,
        );
        return result;
      }

      // Step 2: Update stock master (weekly is enough)
      onProgress?.call(2, 10, '更新股票清單');
      if (forceFetch || _shouldUpdateStockList(targetDate)) {
        try {
          final stockCount = await _stockRepo.syncStockList();
          result.stocksUpdated = stockCount;
        } catch (e) {
          result.errors.add('股票清單更新失敗: $e');
        }
      }

      // Step 3: Fetch daily prices (TWSE - all market) and quick-filter candidates
      onProgress?.call(3, 10, '取得今日價格');
      var marketCandidates = <String>[];
      try {
        final syncResult = await _priceRepo.syncAllPricesForDate(
          normalizedDate,
        );
        result.pricesUpdated = syncResult.count;
        marketCandidates = syncResult.candidates;
      } catch (e) {
        result.errors.add('價格資料更新失敗: $e');
      }

      // Step 3.5: Ensure historical data exists for analysis
      // Now includes: watchlist + popular stocks + market candidates (from quick filter)
      // OPTIMIZED: Parallel fetching + smart skipping
      onProgress?.call(4, 10, '取得歷史資料');
      try {
        // Combine all sources for historical data
        final watchlist = await _db.getWatchlist();
        final symbolsForHistory = <String>{
          ...watchlist.map((w) => w.symbol),
          ..._defaultPopularStocks,
          ...marketCandidates, // Quick-filtered candidates from all market!
        }.toList();

        // Check which stocks need historical data
        final historyStartDate = normalizedDate.subtract(
          const Duration(days: RuleParams.lookbackPrice + 30),
        );

        // Smart skip: Only check stocks that might need data
        // Use batch query to check latest price dates
        final latestPrices = await _db.getLatestPricesBatch(symbolsForHistory);

        final symbolsNeedingData = <String>[];
        for (final symbol in symbolsForHistory) {
          final latestPrice = latestPrices[symbol];
          if (latestPrice == null) {
            // No data at all - need to fetch
            symbolsNeedingData.add(symbol);
            continue;
          }

          // Smart skip: If data is less than 7 days old, skip
          // (it's likely complete enough for analysis)
          final daysSinceLastUpdate = normalizedDate
              .difference(latestPrice.date)
              .inDays;
          if (daysSinceLastUpdate > 7) {
            symbolsNeedingData.add(symbol);
          }
        }

        // Only fetch for stocks that actually need it
        if (symbolsNeedingData.isEmpty) {
          onProgress?.call(4, 10, '歷史資料已完整');
        } else {
          // OPTIMIZATION: Parallel fetch with controlled concurrency
          final total = symbolsNeedingData.length;
          var completed = 0;
          var historySynced = 0;

          // Process in batches of 5 for parallel execution
          const batchSize = 5;
          final failedSymbols = <String>[];

          for (var i = 0; i < total; i += batchSize) {
            final batchEnd = (i + batchSize).clamp(0, total);
            final batch = symbolsNeedingData.sublist(i, batchEnd);

            onProgress?.call(
              4,
              10,
              '歷史資料 (${completed + 1}~$batchEnd / $total)',
            );

            // Fetch batch in parallel, tracking failures
            final futures = batch.map((symbol) async {
              try {
                final count = await _priceRepo.syncStockPrices(
                  symbol,
                  startDate: historyStartDate,
                  endDate: normalizedDate,
                );
                return (symbol, count, null as Object?);
              } catch (e) {
                return (symbol, 0, e);
              }
            });

            final results = await Future.wait(futures);

            for (final (symbol, count, error) in results) {
              if (error != null) {
                failedSymbols.add(symbol);
                // Log error for debugging (first 3 failures only to avoid log spam)
                if (failedSymbols.length <= 3) {
                  debugPrint('[UpdateService] Failed to sync $symbol: $error');
                }
              } else {
                historySynced += count;
              }
            }
            completed += batch.length;
          }

          // Report failed symbols if any
          if (failedSymbols.isNotEmpty) {
            result.errors.add(
              '歷史資料同步失敗 (${failedSymbols.length} 檔): ${failedSymbols.take(5).join(", ")}${failedSymbols.length > 5 ? "..." : ""}',
            );
          }

          if (historySynced > 0) {
            result.pricesUpdated += historySynced;
          }
        }
      } catch (e) {
        result.errors.add('歷史資料更新失敗: $e');
      }

      // Step 4: Fetch institutional data (optional)
      onProgress?.call(4, 10, '取得法人資料');
      final institutionalRepo = _institutionalRepo;
      if (institutionalRepo != null) {
        try {
          // Sync for watchlist stocks only to save API calls
          final watchlist = await _db.getWatchlist();
          for (final item in watchlist) {
            await institutionalRepo.syncInstitutionalData(
              item.symbol,
              startDate: normalizedDate.subtract(const Duration(days: 5)),
              endDate: normalizedDate,
            );
          }
          result.institutionalUpdated = watchlist.length;
        } catch (e) {
          result.errors.add('法人資料更新失敗: $e');
        }
      }

      // Step 5: Fetch RSS news
      onProgress?.call(5, 10, '取得新聞資料');
      try {
        final newsResult = await _newsRepo.syncNews();
        result.newsUpdated = newsResult.itemsAdded;
        if (newsResult.hasErrors) {
          for (final error in newsResult.errors) {
            result.errors.add('RSS 錯誤: $error');
          }
        }
      } catch (e) {
        result.errors.add('新聞更新失敗: $e');
      }

      // Step 6: Filter candidates (now includes market-wide candidates!)
      onProgress?.call(6, 10, '篩選候選股票');
      var candidates = <String>[];
      try {
        // Include market candidates from quick filter
        candidates = await _filterCandidates(
          normalizedDate,
          additionalSymbols: marketCandidates,
        );
        result.candidatesFound = candidates.length;

        // Fallback: if no candidates meet strict criteria,
        // use all stocks with sufficient historical data
        if (candidates.isEmpty) {
          final watchlist = await _db.getWatchlist();
          candidates = <String>{
            ...watchlist.map((w) => w.symbol),
            ..._defaultPopularStocks,
            ...marketCandidates,
          }.toList();
          result.candidatesFound = candidates.length;
        }
      } catch (e) {
        result.errors.add('候選股票篩選失敗: $e');
        // Continue with empty candidates - will result in no recommendations
      }

      // Step 7-8: Run analysis and apply rule engine
      onProgress?.call(7, 10, '執行分析');
      var scoredStocks = <ScoredStock>[];
      try {
        scoredStocks = await _analyzeAndScore(
          candidates,
          normalizedDate,
          onProgress: (current, total) {
            onProgress?.call(7, 10, '分析中 ($current/$total)');
          },
        );
        result.stocksAnalyzed = scoredStocks.length;
      } catch (e) {
        result.errors.add('股票分析失敗: $e');
        // Continue with empty scored stocks - will result in no recommendations
      }

      // Step 9: Generate top 10 recommendations
      onProgress?.call(9, 10, '產生推薦');
      try {
        await _generateRecommendations(scoredStocks, normalizedDate);
        result.recommendationsGenerated = scoredStocks
            .take(RuleParams.dailyTopN)
            .length;
      } catch (e) {
        result.errors.add('推薦產生失敗: $e');
      }

      // Step 10: Mark completion
      onProgress?.call(10, 10, '完成');
      final status = result.errors.isEmpty
          ? UpdateStatus.success.code
          : UpdateStatus.partial.code;

      await _db.finishUpdateRun(
        runId,
        status,
        message: result.errors.isEmpty ? '更新完成' : '部分更新成功',
      );

      result.success = true;
      result.message = '更新完成';

      // Capture price data for alert checking
      try {
        final alertSymbols = (await _db.getActiveAlerts())
            .map((a) => a.symbol)
            .toSet()
            .toList();

        if (alertSymbols.isNotEmpty) {
          final latestPrices = await _db.getLatestPricesBatch(alertSymbols);
          final priceHistories = await _db.getPriceHistoryBatch(
            alertSymbols,
            startDate: normalizedDate.subtract(const Duration(days: 2)),
            endDate: normalizedDate,
          );

          for (final symbol in alertSymbols) {
            final price = latestPrices[symbol]?.close;
            if (price != null) {
              result.currentPrices[symbol] = price;

              // Calculate price change percentage
              final history = priceHistories[symbol];
              if (history != null && history.length >= 2) {
                final previousClose = history[history.length - 2].close;
                if (previousClose != null && previousClose > 0) {
                  final change =
                      ((price - previousClose) / previousClose) * 100;
                  result.priceChanges[symbol] = change;
                }
              }
            }
          }
        }
      } catch (e) {
        // Non-critical: alert data capture failure shouldn't fail the update
        debugPrint('[UpdateService] Alert price capture failed: $e');
      }

      return result;
    } catch (e) {
      result.success = false;
      result.message = '更新失敗: $e';
      result.errors.add(e.toString());

      await _db.finishUpdateRun(
        runId,
        UpdateStatus.failed.code,
        message: result.message,
      );

      return result;
    }
  }

  /// Filter stocks that meet candidate criteria
  ///
  /// Checks: watchlist + popular stocks + additional symbols (from market-wide filter)
  ///
  /// [additionalSymbols] - Extra symbols from quick market filter to include
  Future<List<String>> _filterCandidates(
    DateTime date, {
    List<String> additionalSymbols = const [],
  }) async {
    final candidates = <String>[];

    // Combine all sources: watchlist + popular + market candidates
    final watchlist = await _db.getWatchlist();
    final symbolsToCheck = <String>{
      ...watchlist.map((w) => w.symbol),
      ..._defaultPopularStocks,
      ...additionalSymbols, // NEW: Include market-wide quick-filtered candidates
    }.toList();

    if (symbolsToCheck.isEmpty) return candidates;

    // Calculate date range for price history
    final startDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );

    // Batch load prices for stocks we're checking
    final pricesMap = await _db.getPriceHistoryBatch(
      symbolsToCheck,
      startDate: startDate,
      endDate: date,
    );

    for (final symbol in symbolsToCheck) {
      final prices = pricesMap[symbol];
      if (prices == null || prices.isEmpty) continue;

      // Check if meets candidate criteria
      if (_analysisService.isCandidate(prices)) {
        candidates.add(symbol);
      }
    }

    return candidates;
  }

  /// Analyze candidates and calculate scores
  ///
  /// Uses batch queries to avoid N+1 problem
  Future<List<ScoredStock>> _analyzeAndScore(
    List<String> candidates,
    DateTime date, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (candidates.isEmpty) return [];

    final scoredStocks = <ScoredStock>[];

    // Get recently recommended symbols for cooldown check (single query)
    final recentlyRecommended = await _analysisRepo
        .getRecentlyRecommendedSymbols();

    final startDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );
    final instStartDate = date.subtract(const Duration(days: 10));

    // Batch load all required data in parallel for better performance
    final instRepo = _institutionalRepo;
    final futures = <Future>[
      _db.getPriceHistoryBatch(candidates, startDate: startDate, endDate: date),
      _newsRepo.getNewsForStocksBatch(candidates, days: 2),
      if (instRepo != null)
        _db.getInstitutionalHistoryBatch(
          candidates,
          startDate: instStartDate,
          endDate: date,
        ),
    ];

    final results = await Future.wait(futures);

    final pricesMap = results[0] as Map<String, List<DailyPriceEntry>>;
    final newsMap = results[1] as Map<String, List<NewsItemEntry>>;
    final institutionalMap = instRepo != null
        ? results[2] as Map<String, List<DailyInstitutionalEntry>>
        : <String, List<DailyInstitutionalEntry>>{};

    // Process each candidate with pre-loaded data
    for (var i = 0; i < candidates.length; i++) {
      final symbol = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      // Get price history from batch-loaded data
      final prices = pricesMap[symbol];
      if (prices == null || prices.length < RuleParams.swingWindow) continue;

      // Run analysis
      final analysisResult = _analysisService.analyzeStock(prices);
      if (analysisResult == null) continue;

      // Build context for rule engine
      final context = _analysisService.buildContext(analysisResult);

      // Get optional data from batch-loaded maps
      final institutionalHistory = institutionalMap[symbol];
      final recentNews = newsMap[symbol];

      // Run rule engine
      final reasons = _ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        institutionalHistory: institutionalHistory,
        recentNews: recentNews,
      );

      if (reasons.isEmpty) continue;

      // Calculate score
      final wasRecent = recentlyRecommended.contains(symbol);
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
                evidenceJson: r.evidenceJson,
                score: r.score,
              ),
            )
            .toList(),
      );

      scoredStocks.add(
        ScoredStock(symbol: symbol, score: score, reasons: topReasons),
      );
    }

    // Sort by score descending
    scoredStocks.sort((a, b) => b.score.compareTo(a.score));

    return scoredStocks;
  }

  /// Generate and save daily recommendations
  Future<void> _generateRecommendations(
    List<ScoredStock> scoredStocks,
    DateTime date,
  ) async {
    // Take top N
    final topN = scoredStocks.take(RuleParams.dailyTopN).toList();

    // Save recommendations
    await _analysisRepo.saveRecommendations(
      date,
      topN
          .map(
            (s) =>
                RecommendationData(symbol: s.symbol, score: s.score.toDouble()),
          )
          .toList(),
    );
  }

  /// Check if date is a trading day (Taiwan market)
  ///
  /// Uses [TaiwanCalendar] to check for weekends and national holidays.
  bool _isTradingDay(DateTime date) {
    return TaiwanCalendar.isTradingDay(date);
  }

  /// Check if stock list should be updated (weekly)
  bool _shouldUpdateStockList(DateTime date) {
    // Update on Mondays or if never updated
    return date.weekday == DateTime.monday;
  }

  /// Normalize date to start of day in UTC
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}

/// Callback for update progress
typedef UpdateProgressCallback =
    void Function(int currentStep, int totalSteps, String message);

/// Result of daily update
class UpdateResult {
  UpdateResult({required this.date});

  final DateTime date;
  bool success = false;
  bool skipped = false;
  String? message;
  int stocksUpdated = 0;
  int pricesUpdated = 0;
  int institutionalUpdated = 0;
  int newsUpdated = 0;
  int candidatesFound = 0;
  int stocksAnalyzed = 0;
  int recommendationsGenerated = 0;
  List<String> errors = [];

  /// Price data for alert checking (populated after price sync)
  Map<String, double> currentPrices = {};
  Map<String, double> priceChanges = {};

  /// Summary message
  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';

    return '分析 $stocksAnalyzed 檔，產生 $recommendationsGenerated 個推薦';
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
