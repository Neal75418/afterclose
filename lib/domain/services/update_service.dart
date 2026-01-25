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
        'UpdateSvc',
        '非交易日 ($targetDate)，自動調整至上個交易日: $lastTradingDay',
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

    // 建立更新上下文以在步驟間共享狀態
    final ctx = _UpdateContext(
      targetDate: normalizedDate,
      runId: runId,
      result: result,
      forceFetch: forceFetch,
      onProgress: onProgress,
    );

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
        final syncResult = await _priceRepo.syncAllPricesForDate(
          normalizedDate,
          force: forceFetch,
        );

        // 日期校正：若 TWSE 回傳不同日期的資料（如昨日），
        // 則後續所有資料取得（法人、估值等）都使用該日期
        if (syncResult.dataDate != null) {
          final dataDate = _normalizeDate(syncResult.dataDate!);
          if (dataDate.year != normalizedDate.year ||
              dataDate.month != normalizedDate.month ||
              dataDate.day != normalizedDate.day) {
            normalizedDate = dataDate;
            ctx.normalizedDate = dataDate;
          }
        }

        result.pricesUpdated = syncResult.count;
        marketCandidates = syncResult.candidates;
        ctx.marketCandidates = marketCandidates;
      } catch (e) {
        AppLogger.warning('UpdateSvc', '步驟 3: 價格同步失敗');
        result.errors.add('價格資料更新失敗: $e');
      }

      // 步驟 3.5：確保分析所需的歷史資料存在
      ctx.reportProgress(4, 10, '取得歷史資料');
      try {
        final historySynced = await _syncHistoricalPrices(ctx: ctx);
        if (historySynced > 0) {
          result.pricesUpdated += historySynced;
        }
      } catch (e) {
        result.errors.add('歷史資料更新失敗: $e');
      }

      // 步驟 4：取得法人資料（TWSE T86 - 全市場）
      ctx.reportProgress(4, 10, '取得法人資料');
      try {
        result.institutionalUpdated = await _syncInstitutionalData(ctx: ctx);
      } catch (e) {
        result.errors.add('法人資料更新失敗: $e');
      }

      // 步驟 4.5：取得擴展市場資料（第 4 階段：持股、當沖、籌碼集中度）
      onProgress?.call(4, 10, '取得籌碼資料');
      final marketRepo = _marketDataRepo;
      if (marketRepo != null) {
        try {
          var dayTradingCount = 0;
          var marginCount = 0;

          // 從 TWSE 批次同步當沖資料
          try {
            dayTradingCount = await marketRepo.syncAllDayTradingFromTwse(
              date: normalizedDate,
              forceRefresh: true,
            );
          } catch (_) {}

          // 從 TWSE 批次同步融資融券資料
          try {
            marginCount = await marketRepo.syncAllMarginTradingFromTwse(
              date: normalizedDate,
            );
          } catch (_) {}

          // 為自選清單 + 熱門股同步其他市場資料
          final watchlist = await _db.getWatchlist();
          final symbolsForMarketData = <String>{
            ...watchlist.map((w) => w.symbol),
            ..._popularStocks,
          }.toList();

          final marketDataStartDate = normalizedDate.subtract(
            const Duration(
              days: RuleParams.foreignShareholdingLookbackDays + 5,
            ),
          );

          // 並發限制的平行同步
          const chunkSize = 5;
          var syncedCount = 0;

          for (var i = 0; i < symbolsForMarketData.length; i += chunkSize) {
            final chunk = symbolsForMarketData.skip(i).take(chunkSize).toList();

            final futures = chunk.map((symbol) async {
              try {
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
              } catch (_) {
                return false;
              }
            });

            final results = await Future.wait(futures);
            syncedCount += results.where((r) => r).length;
          }

          AppLogger.info(
            'UpdateSvc',
            '步驟 4.5: 當沖=$dayTradingCount, 融資=$marginCount, 持股=$syncedCount',
          );
        } catch (e) {
          result.errors.add('籌碼資料更新失敗: $e');
        }
      }

      // 步驟 4.6：取得基本面資料（營收、PE、PBR、殖利率）
      final fundamentalRepo = _fundamentalRepo;
      if (fundamentalRepo != null) {
        onProgress?.call(4, 10, '取得基本面資料');
        try {
          final valCount = await fundamentalRepo.syncAllMarketValuation(
            normalizedDate,
            force: forceFetch,
          );
          onProgress?.call(4, 10, '取得營收資料');
          final revenueCount = await fundamentalRepo.syncAllMarketRevenue(
            normalizedDate,
          );

          AppLogger.info('UpdateSvc', '步驟 4.6: 估值=$valCount, 營收=$revenueCount');
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
          AppLogger.info('UpdateSvc', '已清理 $deletedNews 則過期新聞');
        }
      } catch (e) {
        result.errors.add('新聞更新失敗: $e');
      }

      // 步驟 6：篩選候選股票
      ctx.reportProgress(6, 10, '篩選候選股票');
      var candidates = <String>[];
      try {
        candidates = await _filterCandidates(ctx: ctx);
        result.candidatesFound = candidates.length;
      } catch (e) {
        AppLogger.error('UpdateSvc', '步驟 6 失敗', e);
        result.errors.add('候選股票篩選失敗: $e');
      }

      // 步驟 7-8：執行分析並套用規則引擎
      ctx.reportProgress(7, 10, '執行分析');
      var scoredStocks = <ScoredStock>[];
      try {
        scoredStocks = await _analyzeStocks(ctx: ctx, candidates: candidates);
        result.stocksAnalyzed = scoredStocks.length;
      } catch (e) {
        AppLogger.error('UpdateSvc', '步驟 7-8 失敗', e);
        result.errors.add('股票分析失敗: $e');
      }

      // 步驟 9：產生前 10 名推薦
      onProgress?.call(9, 10, '產生推薦');
      try {
        await _generateRecommendations(scoredStocks, normalizedDate);
        result.recommendationsGenerated = scoredStocks
            .take(RuleParams.dailyTopN)
            .length;
        AppLogger.info(
          'UpdateSvc',
          '步驟 9: 推薦 ${result.recommendationsGenerated} 檔',
        );
      } catch (e) {
        result.errors.add('推薦產生失敗: $e');
      }

      // 步驟 10：標記完成
      onProgress?.call(10, 10, '完成');
      final dateStr = '${normalizedDate.month}/${normalizedDate.day}';
      AppLogger.info(
        'UpdateSvc',
        '完成 ($dateStr): 價格=${result.pricesUpdated}, 分析=${result.stocksAnalyzed}, 推薦=${result.recommendationsGenerated}',
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
        AppLogger.warning('UpdateSvc', '警示價格擷取失敗', e);
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

  /// 正規化日期為當日開始（本地時間）
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ============================================================
  // 步驟提取方法（從 runDailyUpdate 拆分）
  // ============================================================

  /// 步驟 3.5：同步歷史價格資料
  ///
  /// 確保分析所需的股票有足夠的歷史資料（52 週）
  /// 整合：自選清單 + 熱門股 + 市場候選股 + 既有資料股票
  Future<int> _syncHistoricalPrices({required _UpdateContext ctx}) async {
    // 整合所有歷史資料來源
    final watchlist = await _db.getWatchlist();

    // 找出本地已有足夠資料的股票
    final historyLookbackStart = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.swingWindow + 20),
    );
    final existingDataSymbols = await _db.getSymbolsWithSufficientData(
      minDays: RuleParams.swingWindow,
      startDate: historyLookbackStart,
      endDate: ctx.normalizedDate,
    );

    final symbolsForHistory = <String>{
      ...watchlist.map((w) => w.symbol),
      ..._popularStocks,
      ...ctx.marketCandidates,
      ...existingDataSymbols,
    }.toList();

    final historyStartDate = ctx.normalizedDate.subtract(
      const Duration(days: RuleParams.historyRequiredDays),
    );

    // 檢查哪些股票需要歷史資料
    final priceHistoryBatch = await _db.getPriceHistoryBatch(
      symbolsForHistory,
      startDate: historyStartDate,
      endDate: ctx.normalizedDate,
    );

    final symbolsNeedingData = <String>[];
    const minRequiredDays = RuleParams.week52Days;

    for (final symbol in symbolsForHistory) {
      final prices = priceHistoryBatch[symbol];
      final priceCount = prices?.length ?? 0;

      if (priceCount < minRequiredDays) {
        const nearThreshold = 200;
        if (priceCount >= nearThreshold) {
          continue;
        }

        if (prices != null && prices.isNotEmpty) {
          final firstTradeDate = prices.first.date;
          final daysSinceFirstTrade = ctx.normalizedDate
              .difference(firstTradeDate)
              .inDays;
          final expectedTradingDays = (daysSinceFirstTrade * 0.71).round();

          if (priceCount >= expectedTradingDays - 30) {
            continue;
          }
        }
        symbolsNeedingData.add(symbol);
      }
    }

    if (symbolsNeedingData.isEmpty) {
      ctx.reportProgress(4, 10, '歷史資料已完整');
      return 0;
    }

    // 批次同步歷史資料
    final total = symbolsNeedingData.length;
    var historySynced = 0;
    const batchSize = 2;
    final failedSymbols = <String>[];

    for (var i = 0; i < total; i += batchSize) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 200));

      final batchEnd = (i + batchSize).clamp(0, total);
      final batch = symbolsNeedingData.sublist(i, batchEnd);

      ctx.reportProgress(4, 10, '歷史資料 (${i + 1}~$batchEnd / $total)');

      final futures = batch.map((symbol) async {
        try {
          final count = await _priceRepo.syncStockPrices(
            symbol,
            startDate: historyStartDate,
            endDate: ctx.normalizedDate,
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
        } else {
          historySynced += count;
        }
      }
    }

    final successCount = symbolsNeedingData.length - failedSymbols.length;
    AppLogger.info(
      'UpdateSvc',
      '步驟 3.5: 歷史資料 $successCount/${symbolsNeedingData.length} 檔',
    );

    if (failedSymbols.isNotEmpty) {
      ctx.result.errors.add('歷史資料同步失敗 (${failedSymbols.length} 檔)');
    }

    return historySynced;
  }

  /// 步驟 4：同步法人資料
  Future<int> _syncInstitutionalData({required _UpdateContext ctx}) async {
    final institutionalRepo = _institutionalRepo;
    if (institutionalRepo == null) return 0;

    // 1. 同步今日
    await institutionalRepo.syncAllMarketInstitutional(
      ctx.normalizedDate,
      force: ctx.forceFetch,
    );

    // 2. 回補近期資料
    const backfillDays = 5;
    var syncedDays = 1;

    for (var i = 1; i < backfillDays; i++) {
      final backDate = ctx.normalizedDate.subtract(Duration(days: i));
      if (_isTradingDay(backDate)) {
        await Future.delayed(const Duration(milliseconds: 1000));
        ctx.reportProgress(4, 10, '取得法人資料 (${backDate.month}/${backDate.day})');
        try {
          await institutionalRepo.syncAllMarketInstitutional(backDate);
          syncedDays++;
        } catch (_) {}
      }
    }

    AppLogger.info('UpdateSvc', '步驟 4: 法人資料 $syncedDays 天');
    return syncedDays * 1000;
  }

  /// 步驟 6：篩選候選股票
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

    // 建立排序後的候選清單
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

  /// 步驟 7-8：執行分析並套用規則引擎
  ///
  /// 對候選股票評分並產生分析結果
  Future<List<ScoredStock>> _analyzeStocks({
    required _UpdateContext ctx,
    required List<String> candidates,
  }) async {
    // 預先批次載入所有必要資料
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
    ];

    final batchResults = await Future.wait(futures);
    final pricesMap = batchResults[0] as Map<String, List<DailyPriceEntry>>;
    final newsMap = batchResults[1] as Map<String, List<NewsItemEntry>>;
    final institutionalMap = instRepo != null
        ? batchResults[2] as Map<String, List<DailyInstitutionalEntry>>
        : <String, List<DailyInstitutionalEntry>>{};
    final revenueMap = batchResults[3] as Map<String, MonthlyRevenueEntry>;
    final valuationMap = batchResults[4] as Map<String, StockValuationEntry>;
    final revenueHistoryMap =
        batchResults[5] as Map<String, List<MonthlyRevenueEntry>>;

    // 取得近期已推薦的股票代碼以供冷卻期使用
    final recentlyRecommended = await _analysisRepo
        .getRecentlyRecommendedSymbols();

    // 清除當日舊的分析和原因記錄
    await _analysisRepo.clearReasonsForDate(ctx.normalizedDate);
    await _analysisRepo.clearAnalysisForDate(ctx.normalizedDate);

    // 使用 ScoringService 在背景 Isolate 評分（避免 UI 凍結）
    // 注意：Isolate 不支援 marketDataBuilder 和 onProgress
    // 市場資料上下文（Phase 4 訊號）在批量評分時不使用，個股分析仍可使用
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
    );

    AppLogger.info('UpdateSvc', '步驟 7-8: 評分 ${scoredStocks.length} 檔');

    return scoredStocks;
  }
}

/// 更新進度回呼
typedef UpdateProgressCallback =
    void Function(int currentStep, int totalSteps, String message);

/// 更新流程內部上下文
///
/// 在各更新步驟間共享狀態，避免過多參數傳遞
class _UpdateContext {
  _UpdateContext({
    required this.targetDate,
    required this.runId,
    required this.result,
    this.forceFetch = false,
    this.onProgress,
  }) : normalizedDate = targetDate;

  /// 目標更新日期
  final DateTime targetDate;

  /// 正規化後的日期（可能因資料來源校正而變更）
  DateTime normalizedDate;

  /// 資料庫更新記錄 ID
  final int runId;

  /// 更新結果累積器
  final UpdateResult result;

  /// 是否強制重新取得資料
  final bool forceFetch;

  /// 進度回呼
  final UpdateProgressCallback? onProgress;

  /// 市場候選股票（來自步驟 3 的快速篩選）
  List<String> marketCandidates = [];

  /// 評分後的股票清單
  List<ScoredStock> scoredStocks = [];

  /// 回報進度
  void reportProgress(int step, int total, String message) {
    onProgress?.call(step, total, message);
  }
}

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
