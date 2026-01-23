import 'dart:async';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/scoring_service.dart';

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
    MarketDataRepository? marketDataRepository,
    FundamentalRepository? fundamentalRepository,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
    ScoringService? scoringService,
    List<String>? popularStocks,
  }) : _db = database,
       _stockRepo = stockRepository,
       _priceRepo = priceRepository,
       _newsRepo = newsRepository,
       _analysisRepo = analysisRepository,
       _institutionalRepo = institutionalRepository,
       _marketDataRepo = marketDataRepository,
       _fundamentalRepo = fundamentalRepository,
       _analysisService = analysisService ?? const AnalysisService(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _scoringService = scoringService,
       _popularStocks = popularStocks ?? _defaultPopularStocks;

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
  final MarketDataRepository? _marketDataRepo;
  final FundamentalRepository? _fundamentalRepo;
  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;
  final ScoringService? _scoringService;
  final List<String> _popularStocks;

  /// Get or create ScoringService (lazy initialization)
  ScoringService get _scoring =>
      _scoringService ??
      ScoringService(
        analysisService: _analysisService,
        ruleEngine: _ruleEngine,
        analysisRepository: _analysisRepo,
      );

  /// Run the complete daily update pipeline
  ///
  /// Returns [UpdateResult] with details of what was updated
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool forceFetch = false,
    UpdateProgressCallback? onProgress,
  }) async {
    final targetDate = forDate ?? DateTime.now();
    var normalizedDate = _normalizeDate(targetDate);

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
        AppLogger.info('UpdateService', 'Step 3: Fetching daily prices...');
        final syncResult = await _priceRepo.syncAllPricesForDate(
          normalizedDate,
          force: forceFetch,
        );

        if (syncResult.skipped) {
          AppLogger.info(
            'UpdateService',
            'Price data already exists for ${syncResult.dataDate}. skipped DB write.',
          );
        }

        // Date Correction: If TWSE returned data for a different date (e.g. yesterday),
        // use that date for all subsequent data fetches (Institutional, Valuation, etc.)
        if (syncResult.dataDate != null) {
          final dataDate = _normalizeDate(syncResult.dataDate!);
          if (dataDate.year != normalizedDate.year ||
              dataDate.month != normalizedDate.month ||
              dataDate.day != normalizedDate.day) {
            AppLogger.info(
              'UpdateService',
              'Date Correction: Requested $normalizedDate, Got data for $dataDate. Adjusting effective date.',
            );
            normalizedDate = dataDate;
            // Note: We don't update the 'runId' record date, keeping it as the "Run Date".
          }
        }

        result.pricesUpdated = syncResult.count;
        marketCandidates = syncResult.candidates;
        AppLogger.info(
          'UpdateService',
          'Step 3 complete: ${syncResult.count} prices, '
              '${marketCandidates.length} candidates',
        );
      } catch (e) {
        AppLogger.error('UpdateService', 'Step 3 failed', e);
        result.errors.add('價格資料更新失敗: $e');
      }

      // Step 3.5: Ensure historical data exists for analysis
      // Now includes: watchlist + popular stocks + market candidates (from quick filter)
      // OPTIMIZED: Parallel fetching + smart skipping
      onProgress?.call(4, 10, '取得歷史資料');
      try {
        AppLogger.info(
          'UpdateService',
          'Step 3.5: Checking historical data...',
        );
        // Combine all sources for historical data
        final watchlist = await _db.getWatchlist();

        // Find stocks that already have sufficient data locally ("Existing Data Strategy")
        // This ensures stocks we've tracked before keep getting analyzed even if they are low volume today
        final historyLookbackStart = normalizedDate.subtract(
          const Duration(days: RuleParams.swingWindow + 20),
        );
        final existingDataSymbols = await _db.getSymbolsWithSufficientData(
          minDays: RuleParams.swingWindow,
          startDate: historyLookbackStart,
          endDate: normalizedDate,
        );
        AppLogger.info(
          'UpdateService',
          'Found ${existingDataSymbols.length} stocks with existing data',
        );

        final symbolsForHistory = <String>{
          ...watchlist.map((w) => w.symbol),
          ..._popularStocks,
          ...marketCandidates, // Quick-filtered candidates from all market!
          ...existingDataSymbols, // NEW: Include verified local stocks
        }.toList();

        AppLogger.info(
          'UpdateService',
          'symbolsForHistory: ${symbolsForHistory.length} '
              '(watchlist=${watchlist.length}, popular=${_popularStocks.length}, '
              'candidates=${marketCandidates.length}, existing=${existingDataSymbols.length})',
        );

        // Check which stocks need historical data
        final historyStartDate = normalizedDate.subtract(
          const Duration(days: RuleParams.historyRequiredDays),
        );

        // FIX: Check actual data counts, not just latest date
        // We need at least RuleParams.swingWindow days of data for analysis
        final priceHistoryBatch = await _db.getPriceHistoryBatch(
          symbolsForHistory,
          startDate: historyStartDate,
          endDate: normalizedDate,
        );

        final symbolsNeedingData = <String>[];
        for (final symbol in symbolsForHistory) {
          final prices = priceHistoryBatch[symbol];
          final priceCount = prices?.length ?? 0;

          // Need at least swingWindow days of data for analysis
          if (priceCount < RuleParams.swingWindow) {
            symbolsNeedingData.add(symbol);
          }
        }

        AppLogger.info(
          'UpdateService',
          'symbolsNeedingData: ${symbolsNeedingData.length} out of ${symbolsForHistory.length} '
              '(need >= ${RuleParams.swingWindow} days)',
        );

        // Only fetch for stocks that actually need it
        if (symbolsNeedingData.isEmpty) {
          AppLogger.info('UpdateService', 'Historical data already complete');
          onProgress?.call(4, 10, '歷史資料已完整');
        } else {
          // OPTIMIZATION: Parallel fetch with controlled concurrency
          final total = symbolsNeedingData.length;
          var completed = 0;
          var historySynced = 0;

          // Process in batches of 2 for improved throughput
          // BatchSize 2 = ~12 requests in parallel bursts.
          // Combined with 200ms inter-month delay, this aims for ~2s per batch.
          const batchSize = 2;
          final failedSymbols = <String>[];

          for (var i = 0; i < total; i += batchSize) {
            // Throttle: Short breath between batches
            // 200ms is minimal to reset connection states
            if (i > 0) await Future.delayed(const Duration(milliseconds: 200));

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
                  AppLogger.warning(
                    'UpdateService',
                    'Failed to sync $symbol',
                    error,
                  );
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

      // Step 4: Fetch institutional data (TWSE T86 - All Market)
      // Fetches current day + backfill recent days to ensure streak rules work
      onProgress?.call(4, 10, '取得法人資料');
      final institutionalRepo = _institutionalRepo;
      if (institutionalRepo != null) {
        try {
          AppLogger.info(
            'UpdateService',
            'Step 4: Syncing all market institutional data...',
          );

          // 1. Sync TODAY (Target Date)
          await institutionalRepo.syncAllMarketInstitutional(
            normalizedDate,
            force: forceFetch,
          );

          // 2. Backfill recent days (last 5 trading days)
          // This ensures "3-day Buy Streak" etc. work even for new users/stocks
          const backfillDays = 5;
          var syncedDays = 1;

          for (var i = 1; i < backfillDays; i++) {
            final backDate = normalizedDate.subtract(Duration(days: i));
            // Check trading day logic (simple check usually sufficient)
            if (_isTradingDay(backDate)) {
              // Throttle to respect server limits
              await Future.delayed(const Duration(milliseconds: 1000));

              onProgress?.call(
                4,
                10,
                '取得法人資料 (${backDate.month}/${backDate.day})',
              );
              try {
                await institutionalRepo.syncAllMarketInstitutional(backDate);
                syncedDays++;
              } catch (e) {
                // Log but continue (backfill is best-effort)
                AppLogger.warning(
                  'UpdateService',
                  'Backfill institutional failed for $backDate',
                  e,
                );
              }
            }
          }

          AppLogger.info(
            'UpdateService',
            'Step 4 complete: Synced $syncedDays days of T86 data',
          );
          // Using a high number to indicate success since we synced full market
          result.institutionalUpdated = syncedDays * 1000;
        } catch (e) {
          result.errors.add('法人資料更新失敗: $e');
        }
      }

      // Step 4.5: Fetch extended market data (Phase 4: shareholding, day trading, concentration)
      onProgress?.call(4, 10, '取得籌碼資料');
      final marketRepo = _marketDataRepo;
      if (marketRepo != null) {
        try {
          // Sync for watchlist + popular stocks to save API calls
          final watchlist = await _db.getWatchlist();
          final symbolsForMarketData = <String>{
            ...watchlist.map((w) => w.symbol),
            ..._popularStocks,
          }.toList();

          AppLogger.info(
            'UpdateService',
            'Step 4.5: Syncing market data for ${symbolsForMarketData.length} stocks...',
          );

          final marketDataStartDate = normalizedDate.subtract(
            const Duration(
              days: RuleParams.foreignShareholdingLookbackDays + 5,
            ),
          );

          // Parallel sync with concurrency limit to avoid overwhelming API
          const chunkSize = 5;
          var syncedCount = 0;
          var errorCount = 0;

          // Process in chunks for controlled parallelism
          for (var i = 0; i < symbolsForMarketData.length; i += chunkSize) {
            final chunk = symbolsForMarketData.skip(i).take(chunkSize).toList();

            // Sync each symbol's data in parallel within the chunk
            final futures = chunk.map((symbol) async {
              try {
                // Run both syncs in parallel for each symbol
                await Future.wait([
                  marketRepo.syncShareholding(
                    symbol,
                    startDate: marketDataStartDate,
                    endDate: normalizedDate,
                  ),
                  marketRepo.syncDayTrading(
                    symbol,
                    startDate: marketDataStartDate,
                    endDate: normalizedDate,
                  ),
                ]);
                return true;
              } catch (e) {
                if (errorCount < 3) {
                  AppLogger.warning(
                    'UpdateService',
                    'Market data sync failed for $symbol',
                    e,
                  );
                }
                errorCount++;
                return false;
              }
            });

            // Wait for all futures in this chunk
            final results = await Future.wait(futures);
            syncedCount += results.where((r) => r).length;
          }

          // NOTE: syncHoldingDistribution (股權分散表) requires paid membership
          // and is intentionally not called here

          AppLogger.info(
            'UpdateService',
            'Step 4.5 complete: synced $syncedCount/${symbolsForMarketData.length} stocks',
          );
        } catch (e) {
          result.errors.add('籌碼資料更新失敗: $e');
        }
      }

      // Step 4.6: Fetch fundamental data (revenue, PE, PBR, dividend yield)
      final fundamentalRepo = _fundamentalRepo;
      if (fundamentalRepo != null) {
        onProgress?.call(4, 10, '取得基本面資料 (PE/PBR)');
        try {
          // 1. Valuation: Full Market (TWSE Free - BWIBBU_d)
          AppLogger.info(
            'UpdateService',
            'Step 4.6: Syncing full market valuation (TWSE)...',
          );
          final valCount = await fundamentalRepo.syncAllMarketValuation(
            normalizedDate,
            force: forceFetch,
          );

          // 2. Revenue: Watchlist Only (FinMind)
          // Since revenue is monthly, checking for updates is less frequent,
          // but we sync watchlist to ensure fresh data.
          onProgress?.call(4, 10, '取得營收資料 (自選股)');
          final watchlist = await _db.getWatchlist();
          final symbolsForRevenue = watchlist.map((w) => w.symbol).toList();

          AppLogger.info(
            'UpdateService',
            'Step 4.6: Syncing revenue for ${symbolsForRevenue.length} stocks (FinMind)...',
          );

          // Sync last 13 months of revenue data (for YoY comparison)
          final revenueStartDate = DateTime(
            normalizedDate.year - 1,
            normalizedDate.month - 1,
            1, // First day of month
          );

          var syncedRevenueCount = 0;
          var errorCount = 0;

          // Process revenue in chunks (FinMind Rate Limits apply!)
          // 5 stocks per batch, throttle 1s between batches
          const chunkSize = 5;
          for (var i = 0; i < symbolsForRevenue.length; i += chunkSize) {
            final chunk = symbolsForRevenue.skip(i).take(chunkSize).toList();

            // Throttle to respect FinMind limits (600/hour ~ 10/min)
            // We should be careful. 5 calls then wait.
            if (i > 0) await Future.delayed(const Duration(milliseconds: 1000));

            final futures = chunk.map((symbol) async {
              try {
                final count = await fundamentalRepo.syncMonthlyRevenue(
                  symbol: symbol,
                  startDate: revenueStartDate,
                  endDate: normalizedDate,
                );
                return count > 0;
              } catch (e) {
                if (errorCount < 3) {
                  AppLogger.warning(
                    'UpdateService',
                    'Revenue sync failed for $symbol',
                    e,
                  );
                }
                errorCount++;
                return false;
              }
            });

            final results = await Future.wait(futures);
            syncedRevenueCount += results.where((r) => r).length;
          }

          AppLogger.info(
            'UpdateService',
            'Step 4.6 complete: Valuation=$valCount, Revenue=$syncedRevenueCount stocks',
          );
        } catch (e) {
          result.errors.add('基本面資料更新失敗: $e');
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

        // Cleanup old news (older than 30 days)
        final deletedNews = await _newsRepo.cleanupOldNews(olderThanDays: 30);
        if (deletedNews > 0) {
          AppLogger.info('UpdateService', '已清理 $deletedNews 則過期新聞');
        }
      } catch (e) {
        result.errors.add('新聞更新失敗: $e');
      }

      // Step 6: Get ALL stocks with sufficient historical data for analysis
      // This enables full-market analysis without extra API calls
      onProgress?.call(6, 10, '篩選候選股票');
      var candidates = <String>[];
      try {
        AppLogger.info('UpdateService', 'Step 6: Finding analyzable stocks...');

        // Query DB for all stocks with sufficient historical data
        final historyStartDate = normalizedDate.subtract(
          const Duration(days: RuleParams.historyRequiredDays - 20),
        );
        final allAnalyzable = await _db.getSymbolsWithSufficientData(
          minDays: RuleParams.swingWindow,
          startDate: historyStartDate,
          endDate: normalizedDate,
        );

        AppLogger.info(
          'UpdateService',
          'Step 6: Found ${allAnalyzable.length} stocks with sufficient data',
        );

        // Use all analyzable stocks as candidates
        // Priority: watchlist first, then popular stocks, then rest of market
        final watchlist = await _db.getWatchlist();
        final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();
        final popularSet = _popularStocks.toSet();

        // Build ordered candidate list
        final orderedCandidates = <String>[];

        // 1. Watchlist stocks first (if they have sufficient data)
        for (final symbol in watchlistSymbols) {
          if (allAnalyzable.contains(symbol)) {
            orderedCandidates.add(symbol);
          }
        }

        // 2. Popular stocks second
        for (final symbol in _popularStocks) {
          if (allAnalyzable.contains(symbol) &&
              !orderedCandidates.contains(symbol)) {
            orderedCandidates.add(symbol);
          }
        }

        // 3. Quick-filtered market candidates third
        for (final symbol in marketCandidates) {
          if (allAnalyzable.contains(symbol) &&
              !orderedCandidates.contains(symbol)) {
            orderedCandidates.add(symbol);
          }
        }

        // 4. Rest of analyzable stocks
        for (final symbol in allAnalyzable) {
          if (!orderedCandidates.contains(symbol)) {
            orderedCandidates.add(symbol);
          }
        }

        candidates = orderedCandidates;
        result.candidatesFound = candidates.length;
        AppLogger.info(
          'UpdateService',
          'Step 6: ${candidates.length} candidates '
              '(watchlist=${watchlistSymbols.length}, popular=${popularSet.length}, '
              'market=${marketCandidates.length}, total analyzable=${allAnalyzable.length})',
        );
      } catch (e) {
        AppLogger.error('UpdateService', 'Step 6 failed', e);
        result.errors.add('候選股票篩選失敗: $e');
        // Continue with empty candidates - will result in no recommendations
      }

      // Step 7-8: Run analysis and apply rule engine
      onProgress?.call(7, 10, '執行分析');
      var scoredStocks = <ScoredStock>[];
      try {
        AppLogger.info(
          'UpdateService',
          'Step 7-8: Analyzing ${candidates.length} candidates...',
        );

        // Batch load all required data upfront
        final startDate = normalizedDate.subtract(
          const Duration(days: RuleParams.lookbackPrice + 10),
        );
        final instStartDate = normalizedDate.subtract(
          const Duration(days: RuleParams.institutionalLookbackDays),
        );

        final instRepo = _institutionalRepo;
        final futures = <Future>[
          _db.getPriceHistoryBatch(
            candidates,
            startDate: startDate,
            endDate: normalizedDate,
          ),
          _newsRepo.getNewsForStocksBatch(candidates, days: 2),
          if (instRepo != null)
            _db.getInstitutionalHistoryBatch(
              candidates,
              startDate: instStartDate,
              endDate: normalizedDate,
            ),
          _db.getLatestMonthlyRevenuesBatch(candidates),
          _db.getLatestValuationsBatch(candidates),
        ];

        final batchResults = await Future.wait(futures);
        final pricesMap = batchResults[0] as Map<String, List<DailyPriceEntry>>;
        final newsMap = batchResults[1] as Map<String, List<NewsItemEntry>>;
        final institutionalMap = instRepo != null
            ? batchResults[2] as Map<String, List<DailyInstitutionalEntry>>
            : <String, List<DailyInstitutionalEntry>>{};
        final revenueMap = batchResults[3] as Map<String, MonthlyRevenueEntry>;
        final valuationMap =
            batchResults[4] as Map<String, StockValuationEntry>;

        // Get recently recommended symbols for cooldown
        final recentlyRecommended = await _analysisRepo
            .getRecentlyRecommendedSymbols();

        // Use ScoringService
        scoredStocks = await _scoring.scoreStocks(
          candidates: candidates,
          date: normalizedDate,
          pricesMap: pricesMap,
          newsMap: newsMap,
          institutionalMap: institutionalMap,
          revenueMap: revenueMap,
          valuationMap: valuationMap,
          recentlyRecommended: recentlyRecommended,
          marketDataBuilder: _marketDataRepo != null
              ? _buildMarketDataContext
              : null,
          onProgress: (current, total) {
            onProgress?.call(7, 10, '分析中 ($current/$total)');
          },
        );

        result.stocksAnalyzed = scoredStocks.length;
        AppLogger.info(
          'UpdateService',
          'Step 7-8 complete: ${scoredStocks.length} stocks scored',
        );
      } catch (e) {
        AppLogger.error('UpdateService', 'Step 7-8 failed', e);
        result.errors.add('股票分析失敗: $e');
        // Continue with empty scored stocks - will result in no recommendations
      }

      // Step 9: Generate top 10 recommendations
      onProgress?.call(9, 10, '產生推薦');
      try {
        AppLogger.info(
          'UpdateService',
          'Step 9: Generating recommendations...',
        );
        await _generateRecommendations(scoredStocks, normalizedDate);
        result.recommendationsGenerated = scoredStocks
            .take(RuleParams.dailyTopN)
            .length;
        AppLogger.info(
          'UpdateService',
          'Step 9 complete: ${result.recommendationsGenerated} recommendations',
        );
      } catch (e) {
        AppLogger.error('UpdateService', 'Step 9 failed', e);
        result.errors.add('推薦產生失敗: $e');
      }

      // Step 10: Mark completion
      onProgress?.call(10, 10, '完成');
      AppLogger.info(
        'UpdateService',
        'Update complete! prices=${result.pricesUpdated}, '
            'analyzed=${result.stocksAnalyzed}, '
            'recommendations=${result.recommendationsGenerated}, '
            'errors=${result.errors.length}',
      );
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
        AppLogger.warning('UpdateService', 'Alert price capture failed', e);
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

  /// Build MarketDataContext for Phase 4 signals
  ///
  /// Fetches foreign shareholding, day trading, and concentration data
  /// Returns null if no market data available
  Future<MarketDataContext?> _buildMarketDataContext(String symbol) async {
    final repo = _marketDataRepo;
    if (repo == null) return null;

    try {
      // Fetch shareholding data
      final shareholdingHistory = await repo.getShareholdingHistory(
        symbol,
        days: RuleParams.foreignShareholdingLookbackDays + 5,
      );

      double? foreignSharesRatio;
      double? foreignSharesRatioChange;

      if (shareholdingHistory.length >= 2) {
        final latest = shareholdingHistory.first;
        foreignSharesRatio = latest.foreignSharesRatio;

        // Calculate change over lookback period
        if (shareholdingHistory.length >=
            RuleParams.foreignShareholdingLookbackDays) {
          final older =
              shareholdingHistory[RuleParams.foreignShareholdingLookbackDays -
                  1];
          if (latest.foreignSharesRatio != null &&
              older.foreignSharesRatio != null) {
            foreignSharesRatioChange =
                latest.foreignSharesRatio! - older.foreignSharesRatio!;
          }
        }
      }

      // Fetch day trading data
      final dayTrading = await repo.getLatestDayTrading(symbol);
      final dayTradingRatio = dayTrading?.dayTradingRatio;

      // Fetch concentration ratio
      final concentrationRatio = await repo.getConcentrationRatio(symbol);

      // Return null if no meaningful data
      if (foreignSharesRatio == null &&
          dayTradingRatio == null &&
          concentrationRatio == null) {
        return null;
      }

      return MarketDataContext(
        foreignSharesRatio: foreignSharesRatio,
        foreignSharesRatioChange: foreignSharesRatioChange,
        dayTradingRatio: dayTradingRatio,
        concentrationRatio: concentrationRatio,
      );
    } catch (e) {
      // Log error but don't fail the analysis
      AppLogger.warning(
        'UpdateService',
        '_buildMarketDataContext failed for $symbol: $e',
      );
      return null;
    }
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
