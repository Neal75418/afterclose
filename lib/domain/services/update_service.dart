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

/// 每日市場資料更新協調服務
///
/// 實作 10 步驟每日更新流程：
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

  /// 預設熱門台股（免費帳號備用清單）
  ///
  /// 這些是常被追蹤的高成交量股票
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

  /// 取得或建立 ScoringService（延遲初始化）
  ScoringService get _scoring =>
      _scoringService ??
      ScoringService(
        analysisService: _analysisService,
        ruleEngine: _ruleEngine,
        analysisRepository: _analysisRepo,
      );

  /// 執行完整每日更新流程
  ///
  /// 回傳 [UpdateResult] 包含更新詳情
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool forceFetch = false,
    UpdateProgressCallback? onProgress,
  }) async {
    var targetDate = forDate ?? DateTime.now();

    // 智慧回溯：若為預設「現在」但非交易日（如週六），
    // 自動回溯至最近交易日以確保分析最新市場狀態
    if (forDate == null && !_isTradingDay(targetDate)) {
      final lastTradingDay = TaiwanCalendar.getPreviousTradingDay(targetDate);
      AppLogger.info(
        'UpdateService',
        'Non-trading day detected ($targetDate). Auto-adjusting to last trading day: $lastTradingDay',
      );
      targetDate = lastTradingDay;
    }

    var normalizedDate = _normalizeDate(targetDate);

    // Create update run record
    final runId = await _db.createUpdateRun(
      normalizedDate,
      UpdateStatus.partial.code,
    );

    final result = UpdateResult(date: normalizedDate);

    try {
      // 步驟 1：檢查是否為交易日（雙重檢查，雖然回溯應已處理）
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

      // 步驟 2：更新股票清單（每週更新即可）
      onProgress?.call(2, 10, '更新股票清單');

      // 檢查資料庫是否為空或不完整（首次執行需初始化）
      final existingStocks = await _stockRepo.getAllStocks();
      // 台股約有 1000+ 檔股票，若過少則需同步
      final needsInit = existingStocks.length < 500;

      if (forceFetch || needsInit || _shouldUpdateStockList(targetDate)) {
        try {
          final stockCount = await _stockRepo.syncStockList();
          result.stocksUpdated = stockCount;
        } catch (e) {
          result.errors.add('股票清單更新失敗: $e');
        }
      }

      // 步驟 3：取得每日價格（TWSE - 全市場）並快速篩選候選股票
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

        // 日期校正：若 TWSE 回傳不同日期的資料（如昨日），
        // 則後續所有資料取得（法人、估值等）都使用該日期
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
            // 備註：我們不更新 'runId' 記錄日期，保留為「執行日期」
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

      // 步驟 3.5：確保分析所需的歷史資料存在
      // 現包含：自選清單 + 熱門股 + 市場候選股（來自快速篩選）
      // 最佳化：平行取得 + 智慧跳過
      onProgress?.call(4, 10, '取得歷史資料');
      try {
        AppLogger.info(
          'UpdateService',
          'Step 3.5: Checking historical data...',
        );
        // 整合所有歷史資料來源
        final watchlist = await _db.getWatchlist();

        // 找出本地已有足夠資料的股票（「現有資料策略」）
        // 確保之前追蹤過的股票即使今日成交量低也會繼續被分析
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
          ...marketCandidates, // 來自全市場的快速篩選候選股
          ...existingDataSymbols, // 新增：包含已驗證的本地股票
        }.toList();

        AppLogger.info(
          'UpdateService',
          'symbolsForHistory: ${symbolsForHistory.length} '
              '(watchlist=${watchlist.length}, popular=${_popularStocks.length}, '
              'candidates=${marketCandidates.length}, existing=${existingDataSymbols.length})',
        );

        // 檢查哪些股票需要歷史資料
        final historyStartDate = normalizedDate.subtract(
          const Duration(days: RuleParams.historyRequiredDays),
        );

        // 修正：檢查實際資料筆數，而非僅最新日期
        // 分析至少需要 RuleParams.swingWindow 天的資料
        final priceHistoryBatch = await _db.getPriceHistoryBatch(
          symbolsForHistory,
          startDate: historyStartDate,
          endDate: normalizedDate,
        );

        final symbolsNeedingData = <String>[];
        var skippedNewlyListed = 0;
        for (final symbol in symbolsForHistory) {
          final prices = priceHistoryBatch[symbol];
          final priceCount = prices?.length ?? 0;

          // 分析至少需要 swingWindow 天的資料
          if (priceCount < RuleParams.swingWindow) {
            // 最佳化：檢查是否為新上市股票
            // 若股票首筆交易日距今不足 swingWindow 天，
            // 代表 API 沒有更多歷史資料可抓，直接跳過
            if (prices != null && prices.isNotEmpty) {
              final firstTradeDate = prices.first.date;
              final daysSinceFirstTrade = normalizedDate
                  .difference(firstTradeDate)
                  .inDays;
              if (daysSinceFirstTrade < RuleParams.swingWindow) {
                // 新上市股票，無需嘗試抓取更多資料
                skippedNewlyListed++;
                continue;
              }
            }
            symbolsNeedingData.add(symbol);
          }
        }

        AppLogger.info(
          'UpdateService',
          'symbolsNeedingData: ${symbolsNeedingData.length} out of ${symbolsForHistory.length} '
              '(need >= ${RuleParams.swingWindow} days, skipped $skippedNewlyListed newly listed)',
        );

        // 僅對實際需要的股票取得資料
        if (symbolsNeedingData.isEmpty) {
          AppLogger.info('UpdateService', 'Historical data already complete');
          onProgress?.call(4, 10, '歷史資料已完整');
        } else {
          // 最佳化：控制並發的平行取得
          final total = symbolsNeedingData.length;
          var completed = 0;
          var historySynced = 0;

          // 以 2 個為一批處理以提升吞吐量
          // BatchSize 2 = 約 12 個並行請求
          // 搭配 200ms 批次間隔，目標約 2 秒/批
          const batchSize = 2;
          final failedSymbols = <String>[];

          for (var i = 0; i < total; i += batchSize) {
            // 節流：批次間短暫休息
            // 200ms 是重置連線狀態的最小間隔
            if (i > 0) await Future.delayed(const Duration(milliseconds: 200));

            final batchEnd = (i + batchSize).clamp(0, total);
            final batch = symbolsNeedingData.sublist(i, batchEnd);

            onProgress?.call(
              4,
              10,
              '歷史資料 (${completed + 1}~$batchEnd / $total)',
            );

            // 平行取得批次資料，追蹤失敗
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
                // 記錄錯誤以供除錯（僅前 3 個失敗以避免日誌過多）
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

          // 回報失敗的股票（如有）
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

      // 步驟 4：取得法人資料（TWSE T86 - 全市場）
      // 取得當日 + 回補近期資料以確保連續買賣規則運作
      onProgress?.call(4, 10, '取得法人資料');
      final institutionalRepo = _institutionalRepo;
      if (institutionalRepo != null) {
        try {
          AppLogger.info(
            'UpdateService',
            'Step 4: Syncing all market institutional data...',
          );

          // 1. 同步今日（目標日期）
          await institutionalRepo.syncAllMarketInstitutional(
            normalizedDate,
            force: forceFetch,
          );

          // 2. 回補近期資料（最近 5 個交易日）
          // 確保「連 3 日買超」等規則對新用戶/股票也能運作
          const backfillDays = 5;
          var syncedDays = 1;

          for (var i = 1; i < backfillDays; i++) {
            final backDate = normalizedDate.subtract(Duration(days: i));
            // 檢查交易日邏輯（簡單檢查通常足夠）
            if (_isTradingDay(backDate)) {
              // 節流以遵守伺服器限制
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
                // 記錄但繼續（回補為盡力而為）
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
          // 使用較大數字表示成功（因為同步了全市場）
          result.institutionalUpdated = syncedDays * 1000;
        } catch (e) {
          result.errors.add('法人資料更新失敗: $e');
        }
      }

      // 步驟 4.5：取得擴展市場資料（第 4 階段：持股、當沖、籌碼集中度）
      onProgress?.call(4, 10, '取得籌碼資料');
      final marketRepo = _marketDataRepo;
      if (marketRepo != null) {
        try {
          // 首先：從 TWSE 批次同步當沖資料（免費、快速、全股）
          AppLogger.info(
            'UpdateService',
            'Step 4.5a: Syncing day trading data from TWSE...',
          );
          try {
            final dayTradingCount = await marketRepo.syncAllDayTradingFromTwse(
              date: normalizedDate,
            );
            AppLogger.info(
              'UpdateService',
              'Step 4.5a complete: synced $dayTradingCount day trading records',
            );
          } catch (e) {
            AppLogger.warning(
              'UpdateService',
              'TWSE day trading sync failed, will try FinMind fallback',
              e,
            );
          }

          // 步驟 4.5b：從 TWSE 批次同步融資融券資料（免費、快速、全股）
          AppLogger.info(
            'UpdateService',
            'Step 4.5b: Syncing margin trading data from TWSE...',
          );
          try {
            final marginTradingCount = await marketRepo
                .syncAllMarginTradingFromTwse(date: normalizedDate);
            AppLogger.info(
              'UpdateService',
              'Step 4.5b complete: synced $marginTradingCount margin trading records',
            );
          } catch (e) {
            AppLogger.warning(
              'UpdateService',
              'TWSE margin trading sync failed',
              e,
            );
          }

          // 接著：為自選清單 + 熱門股同步其他市場資料
          final watchlist = await _db.getWatchlist();
          final symbolsForMarketData = <String>{
            ...watchlist.map((w) => w.symbol),
            ..._popularStocks,
          }.toList();

          AppLogger.info(
            'UpdateService',
            'Step 4.5c: Syncing shareholding data for ${symbolsForMarketData.length} stocks...',
          );

          final marketDataStartDate = normalizedDate.subtract(
            const Duration(
              days: RuleParams.foreignShareholdingLookbackDays + 5,
            ),
          );

          // 並發限制的平行同步以避免 API 過載
          const chunkSize = 5;
          var syncedCount = 0;
          var errorCount = 0;

          // 分塊處理以控制並發度
          for (var i = 0; i < symbolsForMarketData.length; i += chunkSize) {
            final chunk = symbolsForMarketData.skip(i).take(chunkSize).toList();

            // 在塊內平行同步每檔股票的資料
            final futures = chunk.map((symbol) async {
              try {
                // 對每檔股票平行執行兩個同步
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

            // 等待此塊中所有 future 完成
            final results = await Future.wait(futures);
            syncedCount += results.where((r) => r).length;
          }

          // 備註：syncHoldingDistribution（股權分散表）需付費會員
          // 因此刻意不在此呼叫

          AppLogger.info(
            'UpdateService',
            'Step 4.5 complete: synced $syncedCount/${symbolsForMarketData.length} stocks',
          );
        } catch (e) {
          result.errors.add('籌碼資料更新失敗: $e');
        }
      }

      // 步驟 4.6：取得基本面資料（營收、PE、PBR、殖利率）
      final fundamentalRepo = _fundamentalRepo;
      if (fundamentalRepo != null) {
        onProgress?.call(4, 10, '取得基本面資料 (PE/PBR)');
        try {
          // 1. 估值：全市場（TWSE 免費 - BWIBBU_d）
          AppLogger.info(
            'UpdateService',
            'Step 4.6: Syncing full market valuation (TWSE)...',
          );
          final valCount = await fundamentalRepo.syncAllMarketValuation(
            normalizedDate,
            force: forceFetch,
          );

          // 2. 營收：全市場（TWSE Open Data - 免費、無限制）
          // 使用 https://openapi.twse.com.tw/v1/opendata/t187ap05_L
          // 一次回傳所有股票最新可用月份的營收！
          onProgress?.call(4, 10, '取得營收資料 (全市場)');

          AppLogger.info(
            'UpdateService',
            'Step 4.6: Syncing full market revenue (TWSE Open Data)...',
          );

          final revenueCount = await fundamentalRepo.syncAllMarketRevenue(
            normalizedDate,
          );

          AppLogger.info(
            'UpdateService',
            'Step 4.6 complete: Valuation=$valCount, Revenue=$revenueCount stocks',
          );
        } catch (e) {
          result.errors.add('基本面資料更新失敗: $e');
        }
      }

      // 步驟 5：取得 RSS 新聞
      onProgress?.call(5, 10, '取得新聞資料');
      try {
        final newsResult = await _newsRepo.syncNews();
        result.newsUpdated = newsResult.itemsAdded;
        if (newsResult.hasErrors) {
          for (final error in newsResult.errors) {
            result.errors.add('RSS 錯誤: $error');
          }
        }

        // 清理舊新聞（超過 30 天）
        final deletedNews = await _newsRepo.cleanupOldNews(olderThanDays: 30);
        if (deletedNews > 0) {
          AppLogger.info('UpdateService', '已清理 $deletedNews 則過期新聞');
        }
      } catch (e) {
        result.errors.add('新聞更新失敗: $e');
      }

      // 步驟 6：取得所有有足夠歷史資料可分析的股票
      // 這使全市場分析無需額外 API 呼叫
      onProgress?.call(6, 10, '篩選候選股票');
      var candidates = <String>[];
      try {
        AppLogger.info('UpdateService', 'Step 6: Finding analyzable stocks...');

        // 查詢資料庫中所有有足夠歷史資料的股票
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

        // 使用所有可分析股票作為候選
        // 優先順序：自選清單優先，接著熱門股，最後是其餘市場
        final watchlist = await _db.getWatchlist();
        final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();
        final popularSet = _popularStocks.toSet();

        // 建立排序後的候選清單
        final orderedCandidates = <String>[];

        // 1. 自選清單股票優先（若有足夠資料）
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

        // 3. 快速篩選的市場候選股第三
        for (final symbol in marketCandidates) {
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
        // 以空候選清單繼續 - 將不產生推薦
      }

      // 步驟 7-8：執行分析並套用規則引擎
      onProgress?.call(7, 10, '執行分析');
      var scoredStocks = <ScoredStock>[];
      try {
        AppLogger.info(
          'UpdateService',
          'Step 7-8: Analyzing ${candidates.length} candidates...',
        );

        // 預先批次載入所有必要資料
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
          // 新增：取得營收歷史以供月增規則使用
          _db.getRecentMonthlyRevenueBatch(candidates, months: 6),
        ];

        final batchResults = await Future.wait(futures);
        final pricesMap = batchResults[0] as Map<String, List<DailyPriceEntry>>;
        final newsMap = batchResults[1] as Map<String, List<NewsItemEntry>>;
        final institutionalMap = instRepo != null
            ? batchResults[2] as Map<String, List<DailyInstitutionalEntry>>
            : <String, List<DailyInstitutionalEntry>>{};

        // 除錯：驗證 T86 資料載入
        int stocksWithInst = 0;
        institutionalMap.forEach((k, v) {
          if (v.isNotEmpty) stocksWithInst++;
        });
        AppLogger.info(
          'UpdateService',
          'DEBUG T86: Loaded institutional data for $stocksWithInst out of ${candidates.length} candidates',
        );
        final revenueMap = batchResults[3] as Map<String, MonthlyRevenueEntry>;
        final valuationMap =
            batchResults[4] as Map<String, StockValuationEntry>;
        final revenueHistoryMap =
            batchResults[5] as Map<String, List<MonthlyRevenueEntry>>;

        // 取得近期已推薦的股票代碼以供冷卻期使用
        final recentlyRecommended = await _analysisRepo
            .getRecentlyRecommendedSymbols();

        // 使用 ScoringService
        scoredStocks = await _scoring.scoreStocks(
          candidates: candidates,
          date: normalizedDate,
          pricesMap: pricesMap,
          newsMap: newsMap,
          institutionalMap: institutionalMap,
          revenueMap: revenueMap,
          valuationMap: valuationMap,
          revenueHistoryMap: revenueHistoryMap,
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
        // 以空評分股票繼續 - 將不產生推薦
      }

      // 步驟 9：產生前 10 名推薦
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

      // 步驟 10：標記完成
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

      // 擷取價格資料以供警示檢查
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
        // 非關鍵：警示資料擷取失敗不應導致更新失敗
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

  /// 產生並儲存每日推薦
  ///
  /// 依 [RuleParams.topNMinTurnover] 過濾，確保僅流動性高的股票
  /// 出現在最終推薦中
  Future<void> _generateRecommendations(
    List<ScoredStock> scoredStocks,
    DateTime date,
  ) async {
    // 依最小成交金額過濾前 N 名（確保僅高流動性股票）
    final liquidStocks = scoredStocks
        .where((s) => s.turnover >= RuleParams.topNMinTurnover)
        .toList();

    // 從過濾後清單取前 N 名
    final topN = liquidStocks.take(RuleParams.dailyTopN).toList();

    AppLogger.info(
      'UpdateService',
      'Recommendations: ${scoredStocks.length} scored → '
          '${liquidStocks.length} liquid (>=${(RuleParams.topNMinTurnover / 1000000).round()}M) → '
          '${topN.length} top N',
    );

    // 儲存推薦
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

  /// 檢查日期是否為交易日（台股市場）
  ///
  /// 使用 [TaiwanCalendar] 檢查週末與國定假日
  bool _isTradingDay(DateTime date) {
    return TaiwanCalendar.isTradingDay(date);
  }

  /// 檢查股票清單是否應更新（每週）
  bool _shouldUpdateStockList(DateTime date) {
    // 週一或從未更新過時更新
    return date.weekday == DateTime.monday;
  }

  /// 正規化日期為當日開始（UTC）
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// 為第 4 階段訊號建立 MarketDataContext
  ///
  /// 取得外資持股、當沖、籌碼集中度資料
  /// 若無市場資料則回傳 null
  Future<MarketDataContext?> _buildMarketDataContext(String symbol) async {
    final repo = _marketDataRepo;
    if (repo == null) return null;

    try {
      // 取得持股資料
      final shareholdingHistory = await repo.getShareholdingHistory(
        symbol,
        days: RuleParams.foreignShareholdingLookbackDays + 5,
      );

      double? foreignSharesRatio;
      double? foreignSharesRatioChange;

      if (shareholdingHistory.length >= 2) {
        final latest = shareholdingHistory.first;
        foreignSharesRatio = latest.foreignSharesRatio;

        // 計算回溯期間的變化
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

      // 取得當沖資料
      final dayTrading = await repo.getLatestDayTrading(symbol);
      final dayTradingRatio = dayTrading?.dayTradingRatio;

      // 取得籌碼集中度
      final concentrationRatio = await repo.getConcentrationRatio(symbol);

      // 若無有意義的資料則回傳 null
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
      // 記錄錯誤但不讓分析失敗
      AppLogger.warning(
        'UpdateService',
        '_buildMarketDataContext failed for $symbol: $e',
      );
      return null;
    }
  }
}

/// 更新進度回呼
typedef UpdateProgressCallback =
    void Function(int currentStep, int totalSteps, String message);

/// 每日更新結果
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

  /// 警示檢查用價格資料（價格同步後填入）
  Map<String, double> currentPrices = {};
  Map<String, double> priceChanges = {};

  /// 摘要訊息
  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';

    return '分析 $stocksAnalyzed 檔，產生 $recommendationsGenerated 個推薦';
  }
}
