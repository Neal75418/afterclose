import 'dart:async';
import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/constants/default_stocks.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/domain/services/thesis/thesis_monitor_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:afterclose/domain/services/update/update.dart';
import 'package:afterclose/domain/services/update_service_deps.dart';

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
/// 8. 套用規則引擎（寫 daily_reason）
/// 9-10. 標記完成（daily_recommendation 已退役、3-mode 從 daily_reason 即時聚合）
class UpdateService {
  UpdateService({
    required AppDatabase database,
    required UpdateRepositories repositories,
    UpdateClients clients = const UpdateClients(),
    UpdateServices services = const UpdateServices(),
    List<String>? popularStocks,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock,
       _ruleAccuracyService = services.ruleAccuracy,
       _thesisMonitorService = services.thesisMonitor,
       _priceRepo = repositories.price,
       _analysisRepo = repositories.analysis,
       _analysisService = services.analysis ?? AnalysisService(),
       _ruleEngine = services.ruleEngine ?? RuleEngine(),
       _scoringService = services.scoring,
       _popularStocks = popularStocks ?? DefaultStocks.popularStocks,
       // 初始化專責 updater
       _stockListSyncer = StockListSyncer(stockRepository: repositories.stock),
       _newsSyncer = NewsSyncer(newsRepository: repositories.news),
       _institutionalSyncer = repositories.institutional != null
           ? InstitutionalSyncer(
               institutionalRepository: repositories.institutional!,
             )
           : null,
       _batchDataLoader = BatchDataLoader(
         database: database,
         newsRepository: repositories.news,
         institutionalRepository: repositories.institutional,
         shareholdingRepository: repositories.shareholding,
         insiderRepository: repositories.insider,
       ),
       _candidateSelector = CandidateSelector(
         database: database,
         popularStocks: popularStocks ?? DefaultStocks.popularStocks,
       ),
       _historicalPriceSyncer = HistoricalPriceSyncer(
         database: database,
         priceRepository: repositories.price,
       ),
       _marketDataUpdater =
           (repositories.trading != null &&
               repositories.shareholding != null &&
               repositories.warning != null &&
               repositories.insider != null)
           ? MarketDataUpdater(
               database: database,
               tradingRepository: repositories.trading!,
               shareholdingRepository: repositories.shareholding!,
               warningRepository: repositories.warning!,
               insiderRepository: repositories.insider!,
             )
           : null,
       _fundamentalSyncer = repositories.fundamental != null
           ? FundamentalSyncer(
               database: database,
               fundamentalRepository: repositories.fundamental!,
               marketDataRepository: repositories.marketData,
             )
           : null,
       _marketIndexSyncer = clients.twse != null
           ? MarketIndexSyncer(
               database: database,
               twseClient: clients.twse!,
               tpexClient: clients.tpex,
               finMindClient: clients.finMind,
             )
           : null,
       _tdccHoldingSyncer = clients.tdcc != null
           ? TdccHoldingSyncer(database: database, tdccClient: clients.tdcc!)
           : null,
       _dividendSyncer = (clients.twse != null || clients.tpex != null)
           ? DividendSyncer(
               database: database,
               twseClient: clients.twse,
               tpexClient: clients.tpex,
             )
           : null,
       _insiderTransferSyncer = clients.tpex != null
           ? InsiderTransferSyncer(
               database: database,
               tpexClient: clients.tpex!,
             )
           : null;

  final AppDatabase _db;
  final AppClock _clock;
  final IPriceRepository _priceRepo;
  final IAnalysisRepository _analysisRepo;
  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;
  final ScoringService? _scoringService;
  final RuleAccuracyService? _ruleAccuracyService;
  final ThesisMonitorService? _thesisMonitorService;
  final List<String> _popularStocks;

  // 專責 updater / loader
  final BatchDataLoader _batchDataLoader;
  final CandidateSelector _candidateSelector;
  final StockListSyncer _stockListSyncer;
  final NewsSyncer _newsSyncer;
  final InstitutionalSyncer? _institutionalSyncer;
  final HistoricalPriceSyncer _historicalPriceSyncer;
  final MarketDataUpdater? _marketDataUpdater;
  final FundamentalSyncer? _fundamentalSyncer;
  final MarketIndexSyncer? _marketIndexSyncer;
  final TdccHoldingSyncer? _tdccHoldingSyncer;
  final DividendSyncer? _dividendSyncer;
  final InsiderTransferSyncer? _insiderTransferSyncer;

  /// 取得或建立 ScoringService（延遲初始化）
  ScoringService get _scoring =>
      _scoringService ??
      ScoringService(
        analysisService: _analysisService,
        ruleEngine: _ruleEngine,
        analysisRepository: _analysisRepo,
      );

  /// 防止並發更新的 Completer 鎖
  ///
  /// 當更新正在執行時，後續呼叫會共享同一個 Future 結果，
  /// 避免重複 API 呼叫和 DB 寫入競爭。
  Completer<UpdateResult>? _activeUpdate;

  /// 執行完整每日更新流程
  ///
  /// 若已有更新正在執行，會等待並回傳該更新的結果，不重複執行。
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool force = false,
    UpdateProgressCallback? onProgress,
  }) async {
    // 已有更新在執行中 → 共享結果，避免重複 API 呼叫
    if (_activeUpdate != null) {
      AppLogger.info('UpdateService', '更新已在執行中，等待現有結果');
      return _activeUpdate!.future;
    }

    final completer = Completer<UpdateResult>();
    _activeUpdate = completer;

    try {
      final result = await _executeUpdate(
        forDate: forDate,
        force: force,
        onProgress: onProgress,
      );
      completer.complete(result);
      return result;
    } catch (e, s) {
      completer.completeError(e, s);
      rethrow;
    } finally {
      _activeUpdate = null;
    }
  }

  /// 實際執行更新邏輯（由 [runDailyUpdate] 的鎖保護）
  Future<UpdateResult> _executeUpdate({
    DateTime? forDate,
    bool force = false,
    UpdateProgressCallback? onProgress,
  }) async {
    var targetDate = forDate ?? _clock.now();

    // 智慧回溯：若為預設「現在」但非交易日，自動回溯至最近交易日
    if (forDate == null && !TaiwanCalendar.isTradingDay(targetDate)) {
      final lastTradingDay = TaiwanCalendar.getPreviousTradingDay(targetDate);
      AppLogger.info(
        'UpdateService',
        '非交易日 ($targetDate)，自動調整至上個交易日: $lastTradingDay',
      );
      targetDate = lastTradingDay;
    }

    final normalizedDate = DateContext.normalize(targetDate);
    final runId = await _db.createUpdateRun(
      normalizedDate,
      UpdateStatus.partial.code,
    );

    final result = UpdateResult(date: normalizedDate);
    final ctx = _UpdateContext(
      targetDate: normalizedDate,
      runId: runId,
      result: result,
      force: force,
      onProgress: onProgress,
    );

    try {
      // 步驟 1：檢查是否為交易日
      onProgress?.call(1, 10, '檢查交易日');
      if (!force && !TaiwanCalendar.isTradingDay(targetDate)) {
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
      if (force) {
        await _cleanupInvalidData(onProgress);
      }

      // 步驟 2：更新股票清單
      await _syncStockList(ctx, targetDate);

      // 步驟 3-3.5：同步價格（含日期校正）+ 歷史資料
      await _syncPricesAndHistory(ctx);

      // 步驟 3.8-5：大盤指數、TDCC、法人、籌碼、基本面、新聞（互相獨立，並行執行）
      ctx.reportProgress(4, 10, '取得法人與基本面資料');
      await (
        _syncAuxiliaryData(ctx),
        _syncInstitutionalData(ctx),
        _syncMarketAndFundamentalData(ctx, ctx.normalizedDate),
        _syncNews(ctx),
      ).wait;

      // 步驟 6：篩選候選股票 + 補充上櫃資料
      ctx.reportProgress(6, 10, '篩選候選股票');
      final candidates = await _candidateSelector.filterCandidates(
        date: ctx.normalizedDate,
        marketCandidates: ctx.marketCandidates,
      );
      result.candidatesFound = candidates.length;
      await _syncOtcCandidatesData(ctx, candidates, ctx.normalizedDate);

      // 步驟 7-8：執行分析
      ctx.reportProgress(7, 10, '執行分析');
      final scoredStocks = await _analyzeStocks(
        ctx: ctx,
        candidates: candidates,
      );
      result.stocksAnalyzed = scoredStocks.length;

      // 步驟 9-10：完成
      //
      // **2026-06-21 退役舊推薦系統 Step 4**：daily_recommendation 已停寫。
      // 3-mode tab（起漲/強勢/回檔）從 daily_reason 即時聚合（scoring 已寫入
      // daily_reason）、不再產生 / 儲存 Top-20 推薦清單。
      ctx.onProgress?.call(9, 10, '完成分析');
      ctx.onProgress?.call(10, 10, '完成');
      await _finishUpdate(ctx, result);

      // 步驟 10+: 重算規則準確度統計。docstring 自承「非阻塞」，但這裡 await =
      // foreground 仍會等到統計更新完成才 return。從 user 角度本來就是 run
      // 完整個 update 才看到結果，所以等統計更新跑完一起回也合理。
      // 真正「非阻塞」語意要 `unawaited(...)` —— 但 background WorkManager
      // 路徑若不 await，isolate 可能在統計更新跑完前被 OS 殺掉。所以維持 await
      // 是 by-design，docstring 同步澄清。
      await _updateRuleAccuracyStatsFailSafe();
      await _checkPinnedThesesFailSafe(ctx);

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

  // ==================================================
  // 私有輔助方法
  // ==================================================

  Future<void> _cleanupInvalidData(UpdateProgressCallback? onProgress) async {
    onProgress?.call(1, 10, '清理無效資料');
    try {
      final cleanupResult = await _db.cleanupInvalidStockCodes();
      final totalCleaned = cleanupResult.values.fold(0, (a, b) => a + b);
      if (totalCleaned > 0) {
        AppLogger.info(
          'UpdateService',
          '已清理 $totalCleaned 筆無效資料: $cleanupResult',
        );
      }
    } catch (e) {
      AppLogger.warning('UpdateService', '清理無效資料失敗', e);
    }
  }

  Future<void> _syncStockList(_UpdateContext ctx, DateTime targetDate) async {
    ctx.onProgress?.call(2, 10, '更新股票清單');
    final stockResult = await _stockListSyncer.smartSync(
      date: targetDate,
      force: ctx.force,
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
        'UpdateService',
        '日期校正: $originalDate -> $correctedDate，已更新 UpdateRun',
      );
    }

    ctx.reportProgress(4, 10, '取得歷史資料');
    await _syncHistoricalData(ctx);
  }

  Future<void> _syncAuxiliaryData(_UpdateContext ctx) async {
    if (ctx.rateLimitedAbort) return;
    if (_marketIndexSyncer != null) {
      try {
        await _marketIndexSyncer.sync();
      } on RateLimitException catch (e) {
        ctx.rateLimitedAbort = true;
        AppLogger.warning('UpdateService', '大盤指數同步失敗 (rate limit)', e);
        ctx.result.recordError('大盤指數同步失敗 (rate limit): $e', e);
      } catch (e) {
        AppLogger.warning('UpdateService', '大盤指數同步失敗', e);
        ctx.result.recordError('大盤指數同步失敗: $e', e);
      }
    }

    if (ctx.rateLimitedAbort) return;
    if (_tdccHoldingSyncer != null) {
      try {
        await _tdccHoldingSyncer.sync();
      } on RateLimitException catch (e) {
        ctx.rateLimitedAbort = true;
        AppLogger.warning('UpdateService', 'TDCC 股權分散表同步失敗 (rate limit)', e);
        ctx.result.recordError('TDCC 股權分散表同步失敗 (rate limit): $e', e);
      } catch (e) {
        AppLogger.warning('UpdateService', 'TDCC 股權分散表同步失敗', e);
        ctx.result.recordError('TDCC 股權分散表同步失敗: $e', e);
      }
    }

    if (ctx.rateLimitedAbort) return;
    if (_dividendSyncer != null) {
      try {
        final divResult = await _dividendSyncer.sync();
        if (divResult.dividendsUpserted > 0 ||
            divResult.meetingEventsCreated > 0) {
          AppLogger.info(
            'UpdateService',
            '股利同步: ${divResult.dividendsUpserted} 筆股利, '
                '${divResult.meetingEventsCreated} 筆股東會',
          );
        }
        // DividendSyncer 內部以 per-source catch 收集 generic 失敗，
        // 不 throw — 必須讀取 errors 轉發，否則對使用者靜默
        for (final err in divResult.errors) {
          ctx.result.errors.add('股利/股東會同步失敗: $err');
        }
      } on RateLimitException catch (e) {
        ctx.rateLimitedAbort = true;
        AppLogger.warning('UpdateService', '股利/股東會同步失敗 (rate limit)', e);
        ctx.result.recordError('股利/股東會同步失敗 (rate limit): $e', e);
      } catch (e) {
        AppLogger.warning('UpdateService', '股利/股東會同步失敗', e);
        ctx.result.recordError('股利/股東會同步失敗: $e', e);
      }
    }

    if (ctx.rateLimitedAbort) return;
    if (_insiderTransferSyncer != null) {
      try {
        final transferCount = await _insiderTransferSyncer.sync();
        if (transferCount > 0) {
          AppLogger.info('UpdateService', '內部人轉讓同步: $transferCount 筆');
        }
      } on RateLimitException catch (e) {
        ctx.rateLimitedAbort = true;
        AppLogger.warning('UpdateService', '內部人轉讓同步失敗 (rate limit)', e);
        ctx.result.recordError('內部人轉讓同步失敗 (rate limit): $e', e);
      } catch (e) {
        AppLogger.warning('UpdateService', '內部人轉讓同步失敗', e);
        ctx.result.recordError('內部人轉讓同步失敗: $e', e);
      }
    }
  }

  Future<void> _syncNews(_UpdateContext ctx) async {
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
        force: ctx.force,
      );

      // 日期校正
      if (syncResult.dataDate != null) {
        final dataDate = DateContext.normalize(syncResult.dataDate!);
        if (dataDate.year != normalizedDate.year ||
            dataDate.month != normalizedDate.month ||
            dataDate.day != normalizedDate.day) {
          normalizedDate = dataDate;
        }
      }

      ctx.result.pricesUpdated = syncResult.count;
      ctx.marketCandidates = syncResult.candidates;
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '價格同步失敗 (rate limit)', e);
      ctx.result.recordError('價格資料更新失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '價格同步失敗', e);
      ctx.result.recordError('價格資料更新失敗: $e', e);
    }
    return normalizedDate;
  }

  Future<void> _syncHistoricalData(_UpdateContext ctx) async {
    if (ctx.rateLimitedAbort) return;
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
      if (historyResult.marketDayRows > 0) {
        ctx.result.pricesUpdated += historyResult.marketDayRows;
      }
      if (historyResult.hasErrors) {
        ctx.result.errors.add(
          '歷史資料同步失敗 (${historyResult.failedSymbols.length} 檔)',
        );
      }
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '歷史資料更新失敗 (rate limit)', e);
      ctx.result.recordError('歷史資料更新失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '歷史資料更新失敗', e);
      ctx.result.recordError('歷史資料更新失敗: $e', e);
    }
  }

  Future<void> _syncInstitutionalData(_UpdateContext ctx) async {
    if (ctx.rateLimitedAbort) return;
    final syncer = _institutionalSyncer;
    if (syncer == null) return;

    try {
      final instResult = await syncer.syncInstitutionalData(
        date: ctx.normalizedDate,
        force: ctx.force,
        // 強制同步把回補窗拉深（~62 交易日）補足 surge/streak/Z-score 所需
        // 歷史深度；已完整的天會被 per-day 檢查跳過（非破壞式、可續傳）。
        // 日常更新維持淺回補保持快速。
        backfillDays: ctx.force
            ? ApiConfig.institutionalForceBackfillDays
            : ApiConfig.institutionalDailyBackfillDays,
      );
      ctx.result.institutionalUpdated = instResult.estimatedCount;
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '法人資料更新失敗 (rate limit)', e);
      ctx.result.recordError('法人資料更新失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '法人資料更新失敗', e);
      ctx.result.recordError('法人資料更新失敗: $e', e);
    }
  }

  Future<void> _syncMarketAndFundamentalData(
    _UpdateContext ctx,
    DateTime normalizedDate,
  ) async {
    if (ctx.rateLimitedAbort) return;
    // 方法內共享自選清單，避免重複查詢
    final watchlist = await _db.getWatchlist();
    final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

    await _syncDayTradingAndMarginData(ctx, normalizedDate, watchlistSymbols);
    if (ctx.rateLimitedAbort) return;
    await _syncFundamentalValuationAndRevenue(ctx, normalizedDate);
    if (ctx.rateLimitedAbort) return;
    await _syncBalanceSheetAndEps(ctx, normalizedDate, watchlistSymbols);
    if (ctx.rateLimitedAbort) return;
    await _syncKillerFeatures(ctx);
  }

  /// 步驟 4.5：籌碼資料（當沖、融資、持股）
  Future<void> _syncDayTradingAndMarginData(
    _UpdateContext ctx,
    DateTime normalizedDate,
    Set<String> watchlistSymbols,
  ) async {
    if (ctx.rateLimitedAbort) return;
    final marketUpdater = _marketDataUpdater;
    if (marketUpdater == null) return;

    try {
      // 硬寫 force: true 是刻意：當沖/融資/融券 batch API 每次都重抓全市場
      // (free TWSE/TPEx Open Data，配額不是 bottleneck)，新鮮度檢查反而
      // 浪費一次 DB count query。比 `ctx.force` 更積極、與本層 daily
      // pipeline 設計一致。若未來想跑 dry-run / replay 不刷新，應把這個
      // 決策移進 `MarketDataUpdater` 內部常數而非從 ctx 傳。
      final marketResult = await marketUpdater.syncMarketWideData(
        date: normalizedDate,
        force: true,
      );

      // 同步自選清單和熱門股的詳細籌碼
      final symbolsForMarketData = <String>{
        ...watchlistSymbols,
        ..._popularStocks,
      }.toList();

      final syncedCount = await marketUpdater.syncSymbolsMarketData(
        symbols: symbolsForMarketData,
        date: normalizedDate,
      );

      final marginLabel = marketResult.marginCount == null
          ? '已快取'
          : '${marketResult.marginCount}';
      final backfillLabel = marketResult.backfilledDays > 0
          ? ', 回補缺漏日=${marketResult.backfilledDays}'
          : '';
      AppLogger.info(
        'UpdateService',
        '步驟 4.5: 當沖=${marketResult.dayTradingCount}, '
            '融資=$marginLabel, 持股=$syncedCount$backfillLabel',
      );
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '籌碼資料更新失敗 (rate limit)', e);
      ctx.result.recordError('籌碼資料更新失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '籌碼資料更新失敗', e);
      ctx.result.recordError('籌碼資料更新失敗: $e', e);
    }
  }

  /// 步驟 4.6：基本面資料（估值 + 營收 + 上櫃自選補充）
  Future<void> _syncFundamentalValuationAndRevenue(
    _UpdateContext ctx,
    DateTime normalizedDate,
  ) async {
    if (ctx.rateLimitedAbort) return;
    final fundamentalSyncer = _fundamentalSyncer;
    if (fundamentalSyncer == null) return;

    try {
      final fundResult = await fundamentalSyncer.syncMarketWideFundamentals(
        date: normalizedDate,
        force: ctx.force,
      );
      // FundamentalSyncer 內部以 per-call catch 收集 generic 失敗（不
      // throw）— 必須讀取 errors 轉發，否則對使用者靜默
      for (final err in fundResult.errors) {
        ctx.result.errors.add('基本面同步失敗: $err');
      }

      // 補充上櫃自選股
      if (!ctx.rateLimitedAbort) {
        try {
          final otcResult = await fundamentalSyncer
              .syncOtcWatchlistFundamentals(
                date: normalizedDate,
                force: ctx.force,
              );
          for (final err in otcResult.errors) {
            ctx.result.errors.add('基本面同步失敗: $err');
          }
        } on RateLimitException catch (e) {
          ctx.rateLimitedAbort = true;
          AppLogger.warning('UpdateService', '上櫃自選基本面補充失敗 (rate limit)', e);
          ctx.result.recordError('上櫃自選基本面補充失敗 (rate limit): $e', e);
        } catch (e) {
          AppLogger.warning('UpdateService', '上櫃自選基本面補充失敗', e);
          ctx.result.recordError('上櫃自選基本面補充失敗: $e', e);
        }
      }

      final revenueLabel = fundResult.revenueCached
          ? '已快取'
          : '${fundResult.revenueCount}';
      AppLogger.info(
        'UpdateService',
        '步驟 4.6: 估值=${fundResult.valuationCount}, 營收=$revenueLabel',
      );
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '基本面資料更新失敗 (rate limit)', e);
      ctx.result.recordError('基本面資料更新失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '基本面資料更新失敗', e);
      ctx.result.recordError('基本面資料更新失敗: $e', e);
    }
  }

  /// 步驟 4.7：財報資料（EPS + 資產負債表）
  Future<void> _syncBalanceSheetAndEps(
    _UpdateContext ctx,
    DateTime normalizedDate,
    Set<String> watchlistSymbols,
  ) async {
    if (ctx.rateLimitedAbort) return;
    final fundamentalSyncer = _fundamentalSyncer;
    if (fundamentalSyncer == null) return;

    try {
      final prioritySymbols = {...watchlistSymbols, ..._popularStocks};
      final remainingSlots =
          ApiConfig.financialSyncMaxCandidates - prioritySymbols.length;
      final targetSymbols = {
        ...prioritySymbols,
        if (remainingSlots > 0)
          ...ctx.marketCandidates
              .where((s) => !prioritySymbols.contains(s))
              .take(remainingSlots),
      }.toList();
      if (targetSymbols.isNotEmpty) {
        // 損益表與資產負債表無相依性，平行執行以縮短等待時間
        final (epsCount, bsCount) = await (
          fundamentalSyncer.syncFinancialStatements(symbols: targetSymbols),
          fundamentalSyncer.syncBalanceSheets(symbols: targetSymbols),
        ).wait;
        final bsLabel = bsCount == null ? '已快取' : '$bsCount';
        AppLogger.info(
          'UpdateService',
          '步驟 4.7: 損益=$epsCount, 資負=$bsLabel (${targetSymbols.length} 檔)',
        );
      }
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '財報資料同步失敗 (rate limit)', e);
      ctx.result.recordError('財報資料同步失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '財報資料同步失敗', e);
      ctx.result.recordError('財報資料同步失敗: $e', e);
    }
  }

  /// 步驟 4.8：Killer Features 資料（警示、董監持股）
  Future<void> _syncKillerFeatures(_UpdateContext ctx) async {
    if (ctx.rateLimitedAbort) return;
    final marketUpdater = _marketDataUpdater;
    if (marketUpdater == null) return;

    try {
      final killerResult = await marketUpdater.syncKillerFeaturesData(
        force: ctx.force,
      );

      AppLogger.info(
        'UpdateService',
        '步驟 4.8: 警示=${killerResult.warningCount}, 董監=${killerResult.insiderCount}',
      );
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning(
        'UpdateService',
        'Killer Features 資料更新失敗 (rate limit)',
        e,
      );
      ctx.result.recordError('Killer Features (rate limit): $e', e);
    } catch (e) {
      // 不加入 errors，因為這是額外功能，不影響主流程
      AppLogger.warning('UpdateService', 'Killer Features 資料更新失敗', e);
    }
  }

  Future<void> _syncOtcCandidatesData(
    _UpdateContext ctx,
    List<String> candidates,
    DateTime normalizedDate,
  ) async {
    if (ctx.rateLimitedAbort) return;
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
        for (final err in fundResult.errors) {
          ctx.result.errors.add('上櫃候選基本面同步失敗: $err');
        }
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
          'UpdateService',
          '步驟 6.5: 上櫃 (${marketResult.syncedCandidates}/${marketResult.totalCandidates} 檔): '
              '估值=${fundResult.valuationCount}, 營收=${fundResult.revenueCount}, '
              '當沖=${marketResult.dayTradingCount}, 持股=${marketResult.shareholdingCount} '
              '(API ~$estimatedApiCalls calls)',
        );
      }
    } on RateLimitException catch (e) {
      ctx.rateLimitedAbort = true;
      AppLogger.warning('UpdateService', '上櫃資料補充失敗 (rate limit)', e);
      ctx.result.recordError('上櫃資料補充失敗 (rate limit): $e', e);
    } catch (e) {
      AppLogger.warning('UpdateService', '上櫃資料補充失敗', e);
      ctx.result.recordError('上櫃資料補充失敗: $e', e);
    }
  }

  Future<List<ScoredStock>> _analyzeStocks({
    required _UpdateContext ctx,
    required List<String> candidates,
  }) async {
    final batchData = await _batchDataLoader.loadBatchData(
      ctx.normalizedDate,
      candidates,
    );

    // 當日舊資料的清除已移入 ScoringService 的寫入 transaction
    // （clear-then-write 原子化，避免中斷留下當日分析真空）
    ctx.reportProgress(7, 10, '分析中 (${candidates.length} 檔)');
    final scoredStocks = await _scoring.scoreStocksInIsolate(
      candidates: candidates,
      date: ctx.normalizedDate,
      batchData: batchData,
    );

    AppLogger.info('UpdateService', '步驟 7-8: 評分 ${scoredStocks.length} 檔');
    return scoredStocks;
  }

  Future<void> _finishUpdate(_UpdateContext ctx, UpdateResult result) async {
    final dateStr = '${ctx.normalizedDate.month}/${ctx.normalizedDate.day}';
    AppLogger.info(
      'UpdateService',
      '完成 ($dateStr): 價格=${result.pricesUpdated}, 分析=${result.stocksAnalyzed}',
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

  /// 重算規則準確度統計（`rule_accuracy`）。**失敗不會拋例外**（fail-safe），
  /// 失敗只 log，不影響 update result.success。
  ///
  /// 命名重點：「fail-safe」≠「非阻塞」。caller 仍會 await 等統計更新跑完才
  /// return（避免 background isolate 被 WorkManager kill）。
  Future<void> _updateRuleAccuracyStatsFailSafe() async {
    final service = _ruleAccuracyService;
    if (service == null) return;

    try {
      await service.updateRuleAccuracyStats();
      AppLogger.info('UpdateService', '步驟 10+: 規則準確度統計更新完成');
    } catch (e, stack) {
      AppLogger.error('UpdateService', '規則準確度統計更新失敗（fail-safe）', e, stack);
    }
  }

  /// 釘選論點失效檢查（出場層 Phase 2）。**fail-safe**：失敗只 log、
  /// 不影響 update result（與 [_updateRuleAccuracyStatsFailSafe] 同模式）。
  Future<void> _checkPinnedThesesFailSafe(_UpdateContext ctx) async {
    final service = _thesisMonitorService;
    if (service == null) return;

    try {
      final n = await service.checkActiveTheses(asOf: ctx.normalizedDate);
      AppLogger.info('UpdateService', '步驟 10+: 釘選論點檢查完成（失效 $n 筆）');
    } catch (e, stack) {
      AppLogger.error('UpdateService', '釘選論點檢查失敗（fail-safe）', e, stack);
    }
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
          startDate: ctx.normalizedDate.subtract(
            const Duration(days: DataFreshness.alertPriceHistoryDays),
          ),
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
      AppLogger.warning('UpdateService', '警示價格擷取失敗', e);
    }
  }
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
    this.force = false,
    this.onProgress,
  }) : normalizedDate = targetDate;

  final DateTime targetDate;
  DateTime normalizedDate;
  final int runId;
  final UpdateResult result;
  final bool force;
  final UpdateProgressCallback? onProgress;
  List<String> marketCandidates = [];

  /// 任一 syncer 撞到 [RateLimitException] 時翻起，後續 API-heavy 步驟自我
  /// 跳過。Syncer 本身已守 `on RateLimitException rethrow` 契約，但 coordinator
  /// 過去用裸 `catch (e)` 把 rethrow 吞成 warning，導致下游 syncer 繼續打同
  /// 一個被限流的 API（最壞情形 _syncOtcCandidatesData 222 檔×3 vendor）。
  bool rateLimitedAbort = false;

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
  List<String> errors = [];
  bool hasRateLimitError = false;
  Map<String, double> currentPrices = {};
  Map<String, double> priceChanges = {};

  /// 記錄錯誤，同時自動偵測 RateLimitException
  void recordError(String message, Object exception) {
    errors.add(message);
    if (exception is RateLimitException) hasRateLimitError = true;
  }

  /// 是否為部分成功（成功但有步驟失敗）
  bool get hasWarnings => errors.isNotEmpty && success;

  /// 警告數量
  int get warningCount => errors.length;

  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';
    if (errors.isNotEmpty) {
      return '分析 $stocksAnalyzed 檔（${errors.length} 項警告）';
    }
    return '分析 $stocksAnalyzed 檔';
  }
}
