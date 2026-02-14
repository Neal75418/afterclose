import 'dart:async';
import 'package:afterclose/core/constants/default_stocks.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/clock.dart';
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
import 'package:afterclose/domain/models/scoring_batch_data.dart';
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
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
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock,
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
  final AppClock _clock;
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

  /// 提前載入的緩衝天數（確保有足夠歷史資料用於技術指標計算）
  static const int _historyLoadBuffer = 20;

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
    var targetDate = forDate ?? _clock.now();

    // 智慧回溯：若為預設「現在」但非交易日，自動回溯至最近交易日
    if (forDate == null && !TaiwanCalendar.isTradingDay(targetDate)) {
      final lastTradingDay = TaiwanCalendar.getPreviousTradingDay(targetDate);
      AppLogger.info(
        'UpdateSvc',
        '非交易日 ($targetDate)，自動調整至上個交易日: $lastTradingDay',
      );
      targetDate = lastTradingDay;
    }

    final normalizedDate = _normalizeDate(targetDate);
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
      await _syncStockList(ctx, targetDate);

      // 步驟 3-3.5：同步價格（含日期校正）+ 歷史資料
      await _syncPricesAndHistory(ctx);

      // 步驟 3.8-3.9：大盤指數 + TDCC 股權分散表
      await _syncAuxiliaryData(ctx);

      // 步驟 4-4.7：法人 + 籌碼 + 基本面
      ctx.reportProgress(4, 10, '取得法人資料');
      await _syncInstitutionalData(ctx);
      await _syncMarketAndFundamentalData(ctx, ctx.normalizedDate);

      // 步驟 5：新聞
      await _syncNews(ctx);

      // 步驟 6：篩選候選股票 + 補充上櫃資料
      ctx.reportProgress(6, 10, '篩選候選股票');
      final candidates = await _filterCandidates(ctx: ctx);
      result.candidatesFound = candidates.length;
      await _syncOtcCandidatesData(ctx, candidates, ctx.normalizedDate);

      // 步驟 7-8：執行分析
      ctx.reportProgress(7, 10, '執行分析');
      final scoredStocks = await _analyzeStocks(
        ctx: ctx,
        candidates: candidates,
      );
      result.stocksAnalyzed = scoredStocks.length;

      // 步驟 9-10：推薦 + 完成
      ctx.onProgress?.call(9, 10, '產生推薦');
      await _generateRecommendations(scoredStocks, ctx.normalizedDate);
      result.recommendationsGenerated = scoredStocks
          .take(RuleParams.dailyTopN)
          .length;
      ctx.onProgress?.call(10, 10, '完成');
      await _finishUpdate(ctx, result);

      return result;
    } catch (e) {
      result.success = false;
      result.message = '更新失敗: $e';
      result.recordError(e.toString(), e);
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

  Future<void> _syncStockList(_UpdateContext ctx, DateTime targetDate) async {
    ctx.onProgress?.call(2, 10, '更新股票清單');
    final stockResult = await _stockListSyncer.smartSync(
      date: targetDate,
      force: ctx.forceFetch,
    );
    ctx.result.stocksUpdated = stockResult.stockCount;
    if (!stockResult.success && stockResult.error != null) {
      ctx.result.errors.add('股票清單更新失敗: ${stockResult.error}');
    }
  }

  Future<void> _syncPricesAndHistory(_UpdateContext ctx) async {
    ctx.onProgress?.call(3, 10, '取得今日價格');
    final originalDate = ctx.normalizedDate;
    final correctedDate = await _syncDailyPrices(ctx, ctx.normalizedDate);
    ctx.normalizedDate = correctedDate;

    // 若日期被校正，更新 UpdateRun 的 runDate
    if (correctedDate != originalDate) {
      await _db.updateRunDate(ctx.runId, correctedDate);
      ctx.result.date = correctedDate;
      AppLogger.info(
        'UpdateSvc',
        '日期校正: $originalDate -> $correctedDate，已更新 UpdateRun',
      );
    }

    ctx.reportProgress(4, 10, '取得歷史資料');
    await _syncHistoricalData(ctx);
  }

  Future<void> _syncAuxiliaryData(_UpdateContext ctx) async {
    if (_marketIndexSyncer != null) {
      await _marketIndexSyncer.sync();
    }

    if (_tdccHoldingSyncer != null) {
      try {
        await _tdccHoldingSyncer.sync();
      } catch (e) {
        AppLogger.warning('UpdateSvc', 'TDCC 股權分散表同步失敗: $e');
      }
    }
  }

  Future<void> _syncNews(_UpdateContext ctx) async {
    ctx.onProgress?.call(5, 10, '取得新聞資料');
    final newsResult = await _newsSyncer.syncAndCleanup();
    ctx.result.newsUpdated = newsResult.itemsAdded;
    ctx.result.errors.addAll(newsResult.errors);
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
      AppLogger.warning('UpdateSvc', '價格同步失敗: $e', e);
      ctx.result.recordError('價格資料更新失敗: $e', e);
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
      ctx.result.recordError('歷史資料更新失敗: $e', e);
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
      ctx.result.recordError('法人資料更新失敗: $e', e);
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
        ctx.result.recordError('籌碼資料更新失敗: $e', e);
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
        ctx.result.recordError('基本面資料更新失敗: $e', e);
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
      const Duration(days: RuleParams.historyRequiredDays - _historyLoadBuffer),
    );
    final allAnalyzable = await _db.getSymbolsWithSufficientData(
      minDays: RuleParams.swingWindow,
      startDate: historyStartDate,
      endDate: ctx.normalizedDate,
    );

    final watchlist = await _db.getWatchlist();
    final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

    final allAnalyzableSet = allAnalyzable.toSet();
    final orderedCandidates = <String>{};

    // 1. 自選清單優先
    for (final symbol in watchlistSymbols) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 2. 熱門股第二
    for (final symbol in _popularStocks) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 3. 市場候選股第三
    for (final symbol in ctx.marketCandidates) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 4. 其餘可分析股票
    for (final symbol in allAnalyzableSet) {
      orderedCandidates.add(symbol);
    }

    AppLogger.info('UpdateSvc', '步驟 6: 篩選 ${orderedCandidates.length} 檔');
    return orderedCandidates.toList();
  }

  Future<List<ScoredStock>> _analyzeStocks({
    required _UpdateContext ctx,
    required List<String> candidates,
  }) async {
    final batchData = await _loadBatchData(ctx, candidates);

    final recentlyRecommended = await _analysisRepo
        .getRecentlyRecommendedSymbols();

    await _analysisRepo.clearReasonsForDate(ctx.normalizedDate);
    await _analysisRepo.clearAnalysisForDate(ctx.normalizedDate);

    ctx.reportProgress(7, 10, '分析中 (${candidates.length} 檔)');
    final scoredStocks = await _scoring.scoreStocksInIsolate(
      candidates: candidates,
      date: ctx.normalizedDate,
      batchData: batchData,
      recentlyRecommended: recentlyRecommended,
    );

    AppLogger.info('UpdateSvc', '步驟 7-8: 評分 ${scoredStocks.length} 檔');
    return scoredStocks;
  }

  /// 平行載入所有評分所需的批次資料
  ///
  /// 同時啟動 14+ 個 DB 查詢，使用 Dart 3 Record 解構等待，
  /// 再將原始資料轉換為 Isolate 可用的 Map 格式。
  Future<ScoringBatchData> _loadBatchData(
    _UpdateContext ctx,
    List<String> candidates,
  ) async {
    final startDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );
    final instStartDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.institutionalLookbackDays),
    );

    final instRepo = _institutionalRepo;

    // 同時啟動所有批次查詢（所有 Future 在建立時即開始並行執行）
    final pricesFuture = _db.getPriceHistoryBatch(
      candidates,
      startDate: startDate,
      endDate: ctx.normalizedDate,
    );
    final newsFuture = _newsRepo.getNewsForStocksBatch(candidates, days: 2);
    final instFuture = instRepo != null
        ? _db.getInstitutionalHistoryBatch(
            candidates,
            startDate: instStartDate,
            endDate: ctx.normalizedDate,
          )
        : Future.value(<String, List<DailyInstitutionalEntry>>{});
    final revenueFuture = _db.getLatestMonthlyRevenuesBatch(candidates);
    final valuationFuture = _db.getLatestValuationsBatch(candidates);
    final revenueHistoryFuture = _db.getRecentMonthlyRevenueBatch(
      candidates,
      months: 6,
    );
    final dayTradingFuture = _db.getDayTradingMapForDate(ctx.normalizedDate);
    final shareholdingFuture = _db.getLatestShareholdingsBatch(candidates);
    final prevShareholdingFuture = _db.getShareholdingsBeforeDateBatch(
      candidates,
      beforeDate: ctx.normalizedDate.subtract(
        const Duration(days: RuleParams.foreignShareholdingLookbackDays),
      ),
    );
    final warningFuture = _db.getActiveWarningsMapBatch(candidates);
    final insiderFuture = _db.getLatestInsiderHoldingsBatch(candidates);
    final epsFuture = _db.getEPSHistoryBatch(candidates);
    final roeFuture = _db.getROEHistoryBatch(candidates);
    final dividendFuture = _db.getDividendHistoryBatch(candidates);

    // 型別安全的並行等待（Dart 3 Record 解構）
    final (pricesMap, newsMap, institutionalMap) = await (
      pricesFuture,
      newsFuture,
      instFuture,
    ).wait;
    final (
      revenueMap,
      valuationMap,
      revenueHistoryMap,
      dayTradingMap,
      shareholdingEntries,
    ) = await (
      revenueFuture,
      valuationFuture,
      revenueHistoryFuture,
      dayTradingFuture,
      shareholdingFuture,
    ).wait;
    final (
      prevShareholdingEntries,
      warningEntries,
      insiderEntries,
      epsHistoryMap,
      roeHistoryMap,
      dividendHistoryMap,
    ) = await (
      prevShareholdingFuture,
      warningFuture,
      insiderFuture,
      epsFuture,
      roeFuture,
      dividendFuture,
    ).wait;

    // 批次載入籌碼集中度（TDCC 股權分散表）
    final concentrationMap = _shareholdingRepo != null
        ? await _shareholdingRepo.getConcentrationRatioBatch(candidates)
        : <String, double>{};

    // 轉換為 Isolate 可用的 Map 格式
    final shareholdingMap = _buildShareholdingMap(
      shareholdingEntries,
      prevShareholdingEntries,
      concentrationMap,
    );

    final warningMap = warningEntries.map(
      (k, v) => MapEntry(k, {
        'warningType': v.warningType,
        'reasonDescription': v.reasonDescription,
        'disposalMeasures': v.disposalMeasures,
        'disposalEndDate': v.disposalEndDate?.toIso8601String(),
      }),
    );

    final insiderMap = await _buildInsiderMap(insiderEntries, candidates);

    return ScoringBatchData(
      pricesMap: pricesMap,
      newsMap: newsMap,
      institutionalMap: institutionalMap,
      revenueMap: revenueMap,
      valuationMap: valuationMap,
      revenueHistoryMap: revenueHistoryMap,
      epsHistoryMap: epsHistoryMap,
      roeHistoryMap: roeHistoryMap,
      dividendHistoryMap: dividendHistoryMap,
      dayTradingMap: dayTradingMap,
      shareholdingMap: shareholdingMap,
      warningMap: warningMap,
      insiderMap: insiderMap,
    );
  }

  /// 建構外資持股 Map（含變化量計算 + 籌碼集中度）
  Map<String, Map<String, double?>> _buildShareholdingMap(
    Map<String, ShareholdingEntry> shareholdingEntries,
    Map<String, ShareholdingEntry> prevShareholdingEntries,
    Map<String, double> concentrationMap,
  ) {
    final result = <String, Map<String, double?>>{};
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

      result[k] = {
        'foreignSharesRatio': currentRatio,
        'foreignSharesRatioChange': ratioChange,
        'concentrationRatio': concentrationMap[k],
      };
    }
    return result;
  }

  /// 建構董監持股狀態 Map（含連續減持/增持判斷）
  Future<Map<String, Map<String, dynamic>>> _buildInsiderMap(
    Map<String, InsiderHoldingEntry> insiderEntries,
    List<String> candidates,
  ) async {
    final insiderRepo = _insiderRepo;
    final insiderStatusMap = insiderRepo != null
        ? await insiderRepo.calculateInsiderStatusBatch(candidates)
        : <String, InsiderStatus>{};

    return insiderEntries.map((k, v) {
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
  bool hasRateLimitError = false;
  Map<String, double> currentPrices = {};
  Map<String, double> priceChanges = {};

  /// 記錄錯誤，同時自動偵測 RateLimitException
  void recordError(String message, Object exception) {
    errors.add(message);
    if (exception is RateLimitException) hasRateLimitError = true;
  }

  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';
    return '分析 $stocksAnalyzed 檔，產生 $recommendationsGenerated 個推薦';
  }
}
