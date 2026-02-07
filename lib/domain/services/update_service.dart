import 'dart:async';
import 'package:afterclose/core/constants/default_stocks.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/update/update.dart';

/// 每日市場資料更新協調服務
///
/// 協調各專責 updater 執行 10 步驟每日更新流程：
/// 1. 檢查交易日
/// 2. 更新股票清單
/// 3. 取得每日價格
/// 4. 取得法人資料（可選）
/// 5. 取得 RSS 新聞
/// 6. 篩選候選股票（候選優先策略）
/// 7. 執行分析
/// 8. 套用規則引擎
/// 9. 產生前 10 名
/// 10. 標記完成
class UpdateService {
  UpdateService({
    required AppDatabase database,
    required StockRepository stockRepository,
    required PriceRepository priceRepository,
    required NewsRepository newsRepository,
    required AnalysisRepository analysisRepository,
    InstitutionalRepository? institutionalRepository,
    MarketDataRepository? marketDataRepository,
    TradingRepository? tradingRepository,
    ShareholdingRepository? shareholdingRepository,
    FundamentalRepository? fundamentalRepository,
    InsiderRepository? insiderRepository,
    TwseClient? twseClient,
    TdccClient? tdccClient,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
    ScoringService? scoringService,
    List<String>? popularStocks,
  }) : _db = database,
       _priceRepo = priceRepository,
       _newsRepo = newsRepository,
       _analysisRepo = analysisRepository,
       _institutionalRepo = institutionalRepository,
       _shareholdingRepo = shareholdingRepository,
       _insiderRepo = insiderRepository,
       _analysisService = analysisService ?? AnalysisService(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _scoringService = scoringService,
       _popularStocks = popularStocks ?? DefaultStocks.popularStocks,
       // 初始化專責 updater
       _stockListSyncer = StockListSyncer(stockRepository: stockRepository),
       _newsSyncer = NewsSyncer(newsRepository: newsRepository),
       _institutionalSyncer = institutionalRepository != null
           ? InstitutionalSyncer(
               institutionalRepository: institutionalRepository,
             )
           : null,
       _historicalPriceSyncer = HistoricalPriceSyncer(
         database: database,
         priceRepository: priceRepository,
       ),
       _marketDataUpdater =
           (tradingRepository != null && shareholdingRepository != null)
           ? MarketDataUpdater(
               database: database,
               tradingRepository: tradingRepository,
               shareholdingRepository: shareholdingRepository,
             )
           : null,
       _fundamentalSyncer = fundamentalRepository != null
           ? FundamentalSyncer(
               database: database,
               fundamentalRepository: fundamentalRepository,
               marketDataRepository: marketDataRepository,
             )
           : null,
       _marketIndexSyncer = twseClient != null
           ? MarketIndexSyncer(database: database, twseClient: twseClient)
           : null,
       _tdccHoldingSyncer = tdccClient != null
           ? TdccHoldingSyncer(database: database, tdccClient: tdccClient)
           : null;

  final AppDatabase _db;
  final PriceRepository _priceRepo;
  final NewsRepository _newsRepo;
  final AnalysisRepository _analysisRepo;
  final InstitutionalRepository? _institutionalRepo;
  final ShareholdingRepository? _shareholdingRepo;
  final InsiderRepository? _insiderRepo;
  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;
  final ScoringService? _scoringService;
  final List<String> _popularStocks;

  // 專責 updater
  final StockListSyncer _stockListSyncer;
  final NewsSyncer _newsSyncer;
  final InstitutionalSyncer? _institutionalSyncer;
  final HistoricalPriceSyncer _historicalPriceSyncer;
  final MarketDataUpdater? _marketDataUpdater;
  final FundamentalSyncer? _fundamentalSyncer;
  final MarketIndexSyncer? _marketIndexSyncer;
  final TdccHoldingSyncer? _tdccHoldingSyncer;

  /// 取得或建立 ScoringService（延遲初始化）
  ScoringService get _scoring =>
      _scoringService ??
      ScoringService(
        analysisService: _analysisService,
        ruleEngine: _ruleEngine,
        analysisRepository: _analysisRepo,
      );

  /// 執行完整每日更新流程
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool forceFetch = false,
    UpdateProgressCallback? onProgress,
  }) async {
    var targetDate = forDate ?? DateTime.now();

    // 智慧回溯：若為預設「現在」但非交易日，自動回溯至最近交易日
    if (forDate == null && !TaiwanCalendar.isTradingDay(targetDate)) {
      final lastTradingDay = TaiwanCalendar.getPreviousTradingDay(targetDate);
      AppLogger.info(
        'UpdateSvc',
        '非交易日 ($targetDate)，自動調整至上個交易日: $lastTradingDay',
      );
      targetDate = lastTradingDay;
    }

    var normalizedDate = _normalizeDate(targetDate);
    final runId = await _db.createUpdateRun(
      normalizedDate,
      UpdateStatus.partial.code,
    );

    final result = UpdateResult(date: normalizedDate);
    final ctx = _UpdateContext(
      targetDate: normalizedDate,
      runId: runId,
      result: result,
      forceFetch: forceFetch,
      onProgress: onProgress,
    );

    try {
      // 步驟 1：檢查是否為交易日
      onProgress?.call(1, 10, '檢查交易日');
      if (!forceFetch && !TaiwanCalendar.isTradingDay(targetDate)) {
        result.skipped = true;
        result.message = '非交易日，跳過更新';
        await _db.finishUpdateRun(
          runId,
          UpdateStatus.success.code,
          message: result.message,
        );
        return result;
      }

      // 步驟 1.5：強制更新時清理無效資料
      if (forceFetch) {
        await _cleanupInvalidData(onProgress);
      }

      // 步驟 2：更新股票清單
      onProgress?.call(2, 10, '更新股票清單');
      final stockResult = await _stockListSyncer.smartSync(
        date: targetDate,
        force: forceFetch,
      );
      result.stocksUpdated = stockResult.stockCount;
      if (!stockResult.success && stockResult.error != null) {
        result.errors.add('股票清單更新失敗: ${stockResult.error}');
      }

      // 步驟 3：取得每日價格
      onProgress?.call(3, 10, '取得今日價格');
      final originalDate = normalizedDate;
      normalizedDate = await _syncDailyPrices(ctx, normalizedDate);
      ctx.normalizedDate = normalizedDate;

      // 若日期被校正，更新 UpdateRun 的 runDate
      if (normalizedDate != originalDate) {
        await _db.updateRunDate(runId, normalizedDate);
        result.date = normalizedDate;
        AppLogger.info(
          'UpdateSvc',
          '日期校正: $originalDate -> $normalizedDate，已更新 UpdateRun',
        );
      }

      // 步驟 3.5：同步歷史價格
      ctx.reportProgress(4, 10, '取得歷史資料');
      await _syncHistoricalData(ctx);

      // 步驟 3.8：同步大盤指數歷史（sync() 內部已處理例外）
      if (_marketIndexSyncer != null) {
        await _marketIndexSyncer.sync();
      }

      // 步驟 3.9：同步 TDCC 股權分散表（每週，syncer 內部有新鮮度檢查）
      if (_tdccHoldingSyncer != null) {
        try {
          await _tdccHoldingSyncer.sync();
        } catch (e) {
          AppLogger.warning('UpdateSvc', 'TDCC 股權分散表同步失敗: $e');
        }
      }

      // 步驟 4：同步法人資料
      ctx.reportProgress(4, 10, '取得法人資料');
      await _syncInstitutionalData(ctx);

      // 步驟 4.5-4.7：同步籌碼和基本面資料
      await _syncMarketAndFundamentalData(ctx, normalizedDate);

      // 步驟 5：同步新聞
      onProgress?.call(5, 10, '取得新聞資料');
      final newsResult = await _newsSyncer.syncAndCleanup();
      result.newsUpdated = newsResult.itemsAdded;
      result.errors.addAll(newsResult.errors);

      // 步驟 6：篩選候選股票
      ctx.reportProgress(6, 10, '篩選候選股票');
      final candidates = await _filterCandidates(ctx: ctx);
      result.candidatesFound = candidates.length;

      // 步驟 6.5：補充上櫃候選股票資料
      await _syncOtcCandidatesData(ctx, candidates, normalizedDate);

      // 步驟 7-8：執行分析
      ctx.reportProgress(7, 10, '執行分析');
      final scoredStocks = await _analyzeStocks(
        ctx: ctx,
        candidates: candidates,
      );
      result.stocksAnalyzed = scoredStocks.length;

      // 步驟 9：產生推薦
      onProgress?.call(9, 10, '產生推薦');
      await _generateRecommendations(scoredStocks, normalizedDate);
      result.recommendationsGenerated = scoredStocks
          .take(RuleParams.dailyTopN)
          .length;

      // 步驟 10：完成
      onProgress?.call(10, 10, '完成');
      await _finishUpdate(ctx, result);

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

  // ============================================================
  // 私有輔助方法
  // ============================================================

  Future<void> _cleanupInvalidData(UpdateProgressCallback? onProgress) async {
    onProgress?.call(1, 10, '清理無效資料');
    try {
      final cleanupResult = await _db.cleanupInvalidStockCodes();
      final totalCleaned = cleanupResult.values.fold(0, (a, b) => a + b);
      if (totalCleaned > 0) {
        AppLogger.info('UpdateSvc', '已清理 $totalCleaned 筆無效資料: $cleanupResult');
      }
    } catch (e) {
      AppLogger.warning('UpdateSvc', '清理無效資料失敗', e);
    }
  }

  Future<DateTime> _syncDailyPrices(
    _UpdateContext ctx,
    DateTime normalizedDate,
  ) async {
    try {
      final syncResult = await _priceRepo.syncAllPricesForDate(
        normalizedDate,
        force: ctx.forceFetch,
      );

      // 日期校正
      if (syncResult.dataDate != null) {
        final dataDate = _normalizeDate(syncResult.dataDate!);
        if (dataDate.year != normalizedDate.year ||
            dataDate.month != normalizedDate.month ||
            dataDate.day != normalizedDate.day) {
          normalizedDate = dataDate;
        }
      }

      ctx.result.pricesUpdated = syncResult.count;
      ctx.marketCandidates = syncResult.candidates;
    } catch (e) {
      AppLogger.warning('UpdateSvc', '價格同步失敗');
      ctx.result.errors.add('價格資料更新失敗: $e');
    }
    return normalizedDate;
  }

  Future<void> _syncHistoricalData(_UpdateContext ctx) async {
    try {
      final watchlist = await _db.getWatchlist();
      final historyResult = await _historicalPriceSyncer.syncHistoricalPrices(
        date: ctx.normalizedDate,
        watchlistSymbols: watchlist.map((w) => w.symbol).toList(),
        popularStocks: _popularStocks,
        marketCandidates: ctx.marketCandidates,
        onProgress: (msg) => ctx.reportProgress(4, 10, msg),
      );
      if (historyResult.syncedCount > 0) {
        ctx.result.pricesUpdated += historyResult.syncedCount;
      }
      if (historyResult.hasFailures) {
        ctx.result.errors.add(
          '歷史資料同步失敗 (${historyResult.failedSymbols.length} 檔)',
        );
      }
    } catch (e) {
      ctx.result.errors.add('歷史資料更新失敗: $e');
    }
  }

  Future<void> _syncInstitutionalData(_UpdateContext ctx) async {
    final syncer = _institutionalSyncer;
    if (syncer == null) return;

    try {
      final instResult = await syncer.syncInstitutionalData(
        date: ctx.normalizedDate,
        force: ctx.forceFetch,
      );
      ctx.result.institutionalUpdated = instResult.estimatedCount;
    } catch (e) {
      ctx.result.errors.add('法人資料更新失敗: $e');
    }
  }

  Future<void> _syncMarketAndFundamentalData(
    _UpdateContext ctx,
    DateTime normalizedDate,
  ) async {
    // 步驟 4.5：籌碼資料
    final marketUpdater = _marketDataUpdater;
    if (marketUpdater != null) {
      ctx.onProgress?.call(4, 10, '取得籌碼資料');
      try {
        final marketResult = await marketUpdater.syncMarketWideData(
          date: normalizedDate,
          forceRefresh: true,
        );

        // 同步自選清單和熱門股的詳細籌碼
        final watchlist = await _db.getWatchlist();
        final symbolsForMarketData = <String>{
          ...watchlist.map((w) => w.symbol),
          ..._popularStocks,
        }.toList();

        final syncedCount = await marketUpdater.syncSymbolsMarketData(
          symbols: symbolsForMarketData,
          date: normalizedDate,
        );

        final marginLabel = marketResult.marginCount < 0
            ? '已快取'
            : '${marketResult.marginCount}';
        AppLogger.info(
          'UpdateSvc',
          '步驟 4.5: 當沖=${marketResult.dayTradingCount}, '
              '融資=$marginLabel, 持股=$syncedCount',
        );
      } catch (e) {
        ctx.result.errors.add('籌碼資料更新失敗: $e');
      }
    }

    // 步驟 4.6-4.7：基本面資料
    final fundamentalSyncer = _fundamentalSyncer;
    if (fundamentalSyncer != null) {
      ctx.onProgress?.call(4, 10, '取得基本面資料');
      try {
        final fundResult = await fundamentalSyncer.syncMarketWideFundamentals(
          date: normalizedDate,
          force: ctx.forceFetch,
        );

        // 補充上櫃自選股
        try {
          await fundamentalSyncer.syncOtcWatchlistFundamentals(
            date: normalizedDate,
          );
        } catch (e) {
          AppLogger.warning('UpdateSvc', '上櫃自選基本面補充失敗: $e');
        }

        final revenueLabel = fundResult.revenueCount < 0
            ? '已快取'
            : '${fundResult.revenueCount}';
        AppLogger.info(
          'UpdateSvc',
          '步驟 4.6: 估值=${fundResult.valuationCount}, 營收=$revenueLabel',
        );

        // 步驟 4.7：同步候選+自選股的財報資料（EPS + 資產負債表）
        try {
          final watchlist = await _db.getWatchlist();
          final targetSymbols = {
            ...watchlist.map((w) => w.symbol),
            ..._popularStocks,
          }.toList();
          if (targetSymbols.isNotEmpty) {
            final epsCount = await fundamentalSyncer.syncFinancialStatements(
              symbols: targetSymbols,
            );
            final bsCount = await fundamentalSyncer.syncBalanceSheets(
              symbols: targetSymbols,
            );
            final bsLabel = bsCount < 0 ? '已快取' : '$bsCount';
            AppLogger.info(
              'UpdateSvc',
              '步驟 4.7: 損益=$epsCount, 資負=$bsLabel (${targetSymbols.length} 檔)',
            );
          }
        } catch (e) {
          AppLogger.warning('UpdateSvc', '財報資料同步失敗: $e');
        }
      } catch (e) {
        ctx.result.errors.add('基本面資料更新失敗: $e');
      }
    }

    // 步驟 4.8：Killer Features 資料（警示、董監持股）
    if (marketUpdater != null) {
      ctx.onProgress?.call(4, 10, '取得警示資料');
      try {
        final killerResult = await marketUpdater.syncKillerFeaturesData(
          force: ctx.forceFetch,
        );

        AppLogger.info(
          'UpdateSvc',
          '步驟 4.8: 警示=${killerResult.warningCount}, 董監=${killerResult.insiderCount}',
        );
      } catch (e) {
        // 不加入 errors，因為這是額外功能，不影響主流程
        AppLogger.warning('UpdateSvc', 'Killer Features 資料更新失敗: $e');
      }
    }
  }

  Future<void> _syncOtcCandidatesData(
    _UpdateContext ctx,
    List<String> candidates,
    DateTime normalizedDate,
  ) async {
    if (candidates.isEmpty) return;

    try {
      ctx.reportProgress(6, 10, '補充上櫃資料');

      var fundResult = const FundamentalSyncResult(
        valuationCount: 0,
        revenueCount: 0,
      );
      var marketResult = const OtcMarketDataResult(
        dayTradingCount: 0,
        shareholdingCount: 0,
      );

      final fundamentalSyncer = _fundamentalSyncer;
      if (fundamentalSyncer != null) {
        fundResult = await fundamentalSyncer.syncOtcCandidatesFundamentals(
          candidates: candidates,
          date: normalizedDate,
        );
      }

      final marketUpdater = _marketDataUpdater;
      if (marketUpdater != null) {
        marketResult = await marketUpdater.syncOtcCandidatesMarketData(
          candidates: candidates,
          date: normalizedDate,
        );
      }

      final estimatedApiCalls = fundResult.total + marketResult.total;
      if (estimatedApiCalls > 0) {
        AppLogger.info(
          'UpdateSvc',
          '步驟 6.5: 上櫃 (${marketResult.syncedCandidates}/${marketResult.totalCandidates} 檔): '
              '估值=${fundResult.valuationCount}, 營收=${fundResult.revenueCount}, '
              '當沖=${marketResult.dayTradingCount}, 持股=${marketResult.shareholdingCount} '
              '(API ~$estimatedApiCalls calls)',
        );
      }
    } catch (e) {
      AppLogger.warning('UpdateSvc', '上櫃資料補充失敗: $e');
    }
  }

  Future<List<String>> _filterCandidates({required _UpdateContext ctx}) async {
    final historyStartDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.historyRequiredDays - 20),
    );
    final allAnalyzable = await _db.getSymbolsWithSufficientData(
      minDays: RuleParams.swingWindow,
      startDate: historyStartDate,
      endDate: ctx.normalizedDate,
    );

    final watchlist = await _db.getWatchlist();
    final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

    final orderedCandidates = <String>[];

    // 1. 自選清單優先
    for (final symbol in watchlistSymbols) {
      if (allAnalyzable.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 2. 熱門股第二
    for (final symbol in _popularStocks) {
      if (allAnalyzable.contains(symbol) &&
          !orderedCandidates.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 3. 市場候選股第三
    for (final symbol in ctx.marketCandidates) {
      if (allAnalyzable.contains(symbol) &&
          !orderedCandidates.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 4. 其餘可分析股票
    for (final symbol in allAnalyzable) {
      if (!orderedCandidates.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    AppLogger.info('UpdateSvc', '步驟 6: 篩選 ${orderedCandidates.length} 檔');
    return orderedCandidates;
  }

  Future<List<ScoredStock>> _analyzeStocks({
    required _UpdateContext ctx,
    required List<String> candidates,
  }) async {
    final startDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );
    final instStartDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.institutionalLookbackDays),
    );

    final instRepo = _institutionalRepo;
    final futures = <Future>[
      _db.getPriceHistoryBatch(
        candidates,
        startDate: startDate,
        endDate: ctx.normalizedDate,
      ),
      _newsRepo.getNewsForStocksBatch(candidates, days: 2),
      if (instRepo != null)
        _db.getInstitutionalHistoryBatch(
          candidates,
          startDate: instStartDate,
          endDate: ctx.normalizedDate,
        ),
      _db.getLatestMonthlyRevenuesBatch(candidates),
      _db.getLatestValuationsBatch(candidates),
      _db.getRecentMonthlyRevenueBatch(candidates, months: 6),
      _db.getDayTradingMapForDate(ctx.normalizedDate),
      _db.getLatestShareholdingsBatch(candidates),
      _db.getShareholdingsBeforeDateBatch(
        candidates,
        beforeDate: ctx.normalizedDate.subtract(
          const Duration(days: RuleParams.foreignShareholdingLookbackDays),
        ),
      ),
      _db.getActiveWarningsMapBatch(candidates),
      _db.getLatestInsiderHoldingsBatch(candidates),
      _db.getEPSHistoryBatch(candidates), // baseIndex + 8
      _db.getROEHistoryBatch(candidates), // baseIndex + 9
      _db.getDividendHistoryBatch(candidates), // baseIndex + 10
    ];

    final batchResults = await Future.wait(futures);
    final pricesMap = batchResults[0] as Map<String, List<DailyPriceEntry>>;
    final newsMap = batchResults[1] as Map<String, List<NewsItemEntry>>;
    final institutionalMap = instRepo != null
        ? batchResults[2] as Map<String, List<DailyInstitutionalEntry>>
        : <String, List<DailyInstitutionalEntry>>{};
    // 根據 instRepo 調整 index
    final baseIndex = instRepo != null ? 3 : 2;
    final revenueMap =
        batchResults[baseIndex] as Map<String, MonthlyRevenueEntry>;
    final valuationMap =
        batchResults[baseIndex + 1] as Map<String, StockValuationEntry>;
    final revenueHistoryMap =
        batchResults[baseIndex + 2] as Map<String, List<MonthlyRevenueEntry>>;
    final dayTradingMap = batchResults[baseIndex + 3] as Map<String, double>;
    final shareholdingEntries =
        batchResults[baseIndex + 4] as Map<String, ShareholdingEntry>;
    final prevShareholdingEntries =
        batchResults[baseIndex + 5] as Map<String, ShareholdingEntry>;
    final warningEntries =
        batchResults[baseIndex + 6] as Map<String, TradingWarningEntry>;
    final insiderEntries =
        batchResults[baseIndex + 7] as Map<String, InsiderHoldingEntry>;
    final epsHistoryMap =
        batchResults[baseIndex + 8] as Map<String, List<FinancialDataEntry>>;
    final roeHistoryMap =
        batchResults[baseIndex + 9] as Map<String, List<FinancialDataEntry>>;
    final dividendHistoryMap =
        batchResults[baseIndex + 10] as Map<String, List<DividendHistoryEntry>>;

    // 批次載入籌碼集中度（TDCC 股權分散表）
    final concentrationMap = _shareholdingRepo != null
        ? await _shareholdingRepo.getConcentrationRatioBatch(candidates)
        : <String, double>{};

    // 轉換為 Isolate 可用的 Map 格式（含外資持股變化量計算 + 籌碼集中度）
    final shareholdingMap = <String, Map<String, double?>>{};
    final allSymbols = {...shareholdingEntries.keys, ...concentrationMap.keys};
    for (final k in allSymbols) {
      final entry = shareholdingEntries[k];
      final currentRatio = entry?.foreignSharesRatio;
      final prevEntry = prevShareholdingEntries[k];
      final prevRatio = prevEntry?.foreignSharesRatio;

      double? ratioChange;
      if (currentRatio != null && prevRatio != null) {
        ratioChange = currentRatio - prevRatio;
      }

      shareholdingMap[k] = {
        'foreignSharesRatio': currentRatio,
        'foreignSharesRatioChange': ratioChange,
        'concentrationRatio': concentrationMap[k],
      };
    }

    final warningMap = warningEntries.map(
      (k, v) => MapEntry(k, {
        'warningType': v.warningType,
        'reasonDescription': v.reasonDescription,
        'disposalMeasures': v.disposalMeasures,
        'disposalEndDate': v.disposalEndDate?.toIso8601String(),
      }),
    );

    // 批次計算董監連續減持/增持狀態
    final insiderRepo = _insiderRepo;
    final insiderStatusMap = insiderRepo != null
        ? await insiderRepo.calculateInsiderStatusBatch(candidates)
        : <String, InsiderStatus>{};

    final insiderMap = insiderEntries.map((k, v) {
      final status = insiderStatusMap[k];
      return MapEntry(k, {
        'insiderRatio': v.insiderRatio,
        'pledgeRatio': v.pledgeRatio,
        'hasSellingStreak': status?.hasSellingStreak ?? false,
        'sellingStreakMonths': status?.sellingStreakMonths ?? 0,
        'hasSignificantBuying': status?.hasSignificantBuying ?? false,
        'buyingChange': status?.buyingChange ?? v.sharesChange,
      });
    });

    final recentlyRecommended = await _analysisRepo
        .getRecentlyRecommendedSymbols();

    await _analysisRepo.clearReasonsForDate(ctx.normalizedDate);
    await _analysisRepo.clearAnalysisForDate(ctx.normalizedDate);

    ctx.reportProgress(7, 10, '分析中 (${candidates.length} 檔)');
    final scoredStocks = await _scoring.scoreStocksInIsolate(
      candidates: candidates,
      date: ctx.normalizedDate,
      pricesMap: pricesMap,
      newsMap: newsMap,
      institutionalMap: institutionalMap,
      revenueMap: revenueMap,
      valuationMap: valuationMap,
      revenueHistoryMap: revenueHistoryMap,
      recentlyRecommended: recentlyRecommended,
      dayTradingMap: dayTradingMap,
      shareholdingMap: shareholdingMap,
      warningMap: warningMap,
      insiderMap: insiderMap,
      epsHistoryMap: epsHistoryMap,
      roeHistoryMap: roeHistoryMap,
      dividendHistoryMap: dividendHistoryMap,
    );

    AppLogger.info('UpdateSvc', '步驟 7-8: 評分 ${scoredStocks.length} 檔');
    return scoredStocks;
  }

  Future<void> _generateRecommendations(
    List<ScoredStock> scoredStocks,
    DateTime date,
  ) async {
    final liquidStocks = scoredStocks
        .where((s) => s.turnover >= RuleParams.topNMinTurnover)
        .toList();

    final topN = liquidStocks.take(RuleParams.dailyTopN).toList();

    await _analysisRepo.saveRecommendations(
      date,
      topN
          .map(
            (s) =>
                RecommendationData(symbol: s.symbol, score: s.score.toDouble()),
          )
          .toList(),
    );

    AppLogger.info('UpdateSvc', '步驟 9: 推薦 ${topN.length} 檔');
  }

  Future<void> _finishUpdate(_UpdateContext ctx, UpdateResult result) async {
    final dateStr = '${ctx.normalizedDate.month}/${ctx.normalizedDate.day}';
    AppLogger.info(
      'UpdateSvc',
      '完成 ($dateStr): 價格=${result.pricesUpdated}, 分析=${result.stocksAnalyzed}, '
          '推薦=${result.recommendationsGenerated}',
    );

    final status = result.errors.isEmpty
        ? UpdateStatus.success.code
        : UpdateStatus.partial.code;
    await _db.finishUpdateRun(
      ctx.runId,
      status,
      message: result.errors.isEmpty ? '更新完成' : '部分更新成功',
    );

    result.success = true;
    result.message = '更新完成';

    // 擷取警示價格資料
    await _fetchAlertPrices(ctx, result);
  }

  Future<void> _fetchAlertPrices(
    _UpdateContext ctx,
    UpdateResult result,
  ) async {
    try {
      final alertSymbols = (await _db.getActiveAlerts())
          .map((a) => a.symbol)
          .toSet()
          .toList();

      if (alertSymbols.isNotEmpty) {
        final latestPrices = await _db.getLatestPricesBatch(alertSymbols);
        final priceHistories = await _db.getPriceHistoryBatch(
          alertSymbols,
          startDate: ctx.normalizedDate.subtract(const Duration(days: 2)),
          endDate: ctx.normalizedDate,
        );

        for (final symbol in alertSymbols) {
          final price = latestPrices[symbol]?.close;
          if (price != null) {
            result.currentPrices[symbol] = price;

            final history = priceHistories[symbol];
            if (history != null && history.length >= 2) {
              final previousClose = history[history.length - 2].close;
              if (previousClose != null && previousClose > 0) {
                result.priceChanges[symbol] =
                    ((price - previousClose) / previousClose) * 100;
              }
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('UpdateSvc', '警示價格擷取失敗', e);
    }
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

/// 更新進度回呼
typedef UpdateProgressCallback =
    void Function(int currentStep, int totalSteps, String message);

/// 更新流程內部上下文
class _UpdateContext {
  _UpdateContext({
    required this.targetDate,
    required this.runId,
    required this.result,
    this.forceFetch = false,
    this.onProgress,
  }) : normalizedDate = targetDate;

  final DateTime targetDate;
  DateTime normalizedDate;
  final int runId;
  final UpdateResult result;
  final bool forceFetch;
  final UpdateProgressCallback? onProgress;
  List<String> marketCandidates = [];

  void reportProgress(int step, int total, String message) {
    onProgress?.call(step, total, message);
  }
}

/// 每日更新結果
class UpdateResult {
  UpdateResult({required this.date});

  /// 資料實際日期（可能在同步過程中被校正）
  DateTime date;
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
  Map<String, double> currentPrices = {};
  Map<String, double> priceChanges = {};

  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';
    return '分析 $stocksAnalyzed 檔，產生 $recommendationsGenerated 個推薦';
  }
}
