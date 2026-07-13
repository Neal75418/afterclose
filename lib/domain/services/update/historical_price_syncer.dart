import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/price_repository.dart';

/// 歷史價格資料同步器
///
/// 負責確保分析所需的歷史價格資料完整。兩段式：
/// - **Phase 0 市場日快照回補**：偵測 lookback 窗內「整個市場缺資料」的
///   交易日，逐日以 1 次 API 呼叫回補該市場全部股票（TWSE MI_INDEX /
///   TPEx afterTrading 歷史端點）。非自選股不再受 per-symbol 早退門檻
///   （180 天）餓死——52 週規則需要 250 天。
/// - **Phase 1 per-symbol 回補**：FinMind 逐檔逐月，處理個股殘缺
///   （新上市、恢復交易等 phase 0 覆蓋不到的情境）。
class HistoricalPriceSyncer {
  const HistoricalPriceSyncer({
    required AppDatabase database,
    required PriceRepository priceRepository,
    this.marketDayCallDelay = const Duration(
      milliseconds: ApiConfig.priceRequestDelayMs,
    ),
  }) : _db = database,
       _priceRepo = priceRepository;

  final AppDatabase _db;
  final PriceRepository _priceRepo;

  /// 市場日快照回補的呼叫間隔（測試注入 [Duration.zero]）
  final Duration marketDayCallDelay;

  /// 同步歷史價格資料
  ///
  /// 確保分析所需的股票有足夠的歷史資料（52 週）
  /// 整合：自選清單 + 熱門股 + 市場候選股 + 既有資料股票
  Future<HistoricalPriceSyncResult> syncHistoricalPrices({
    required DateTime date,
    required List<String> watchlistSymbols,
    required List<String> popularStocks,
    required List<String> marketCandidates,
    void Function(String message)? onProgress,
  }) async {
    // Phase 0：市場日快照回補（整市場缺漏日，1 呼叫補全市場一天）
    final marketDayRows = await _syncMissingMarketDays(
      date: date,
      onProgress: onProgress,
    );

    // Phase 1：整合所有歷史資料來源
    final historyLookbackStart = date.subtract(
      const Duration(days: RuleParams.swingWindow + 20),
    );
    final existingDataSymbols = await _db.getSymbolsWithSufficientData(
      minDays: RuleParams.swingWindow,
      startDate: historyLookbackStart,
      endDate: date,
    );

    final symbolsForHistory = <String>{
      ...watchlistSymbols,
      ...popularStocks,
      ...marketCandidates,
      ...existingDataSymbols,
    }.toList();

    final historyStartDate = date.subtract(
      const Duration(days: RuleParams.historyRequiredDays),
    );

    // 檢查哪些股票需要歷史資料
    final priceHistoryBatch = await _db.getPriceHistoryBatch(
      symbolsForHistory,
      startDate: historyStartDate,
      endDate: date,
    );

    // 自選 + 熱門 = priority locked。它們不適用 lenient nearThreshold
    // 早退門檻（180 天）— 因 52w high/low rule 嚴格要求 250 天，priority
    // 股需要追到 250 才算「夠」。否則 popular 大型權值股（2330/2317/2454）
    // 會卡在 220-240 天區間永遠不被同步，52w rule 永久無法觸發。
    final priorityLocked = <String>{...watchlistSymbols, ...popularStocks};

    final symbolsNeedingData = _findSymbolsNeedingData(
      symbolsForHistory,
      priceHistoryBatch,
      date,
      priorityLocked: priorityLocked,
    );

    if (symbolsNeedingData.isEmpty) {
      onProgress?.call('歷史資料已完整');
      return HistoricalPriceSyncResult(
        syncedCount: 0,
        symbolsProcessed: 0,
        marketDayRows: marketDayRows,
      );
    }

    _logSyncDiagnostics(symbolsNeedingData, priceHistoryBatch);

    // 估算每檔平均需要的月度 API 呼叫數
    final avgMonthsPerSymbol = _estimateAvgMonthsNeeded(
      symbolsNeedingData,
      priceHistoryBatch,
      historyStartDate: historyStartDate,
      endDate: date,
    );

    final limitedSymbols = await _prioritizeSymbols(
      symbolsNeedingData,
      watchlistSymbols: watchlistSymbols,
      popularStocks: popularStocks,
      avgMonthsPerSymbol: avgMonthsPerSymbol,
    );

    final batchResult = await _performBatchSync(
      limitedSymbols,
      historyStartDate: historyStartDate,
      endDate: date,
      totalNeeded: symbolsNeedingData.length,
      onProgress: onProgress,
    );
    return HistoricalPriceSyncResult(
      syncedCount: batchResult.syncedCount,
      symbolsProcessed: batchResult.symbolsProcessed,
      totalSymbolsNeeded: batchResult.totalSymbolsNeeded,
      failedSymbols: batchResult.failedSymbols,
      marketDayRows: marketDayRows,
    );
  }

  /// Phase 0：市場日快照回補
  ///
  /// 掃描 `[date - historyRequiredDays, date - 1]` 窗內每個交易日
  /// （[TaiwanCalendar]，新→舊），該日該市場筆數 < 市場股數 ×
  /// [ApiConfig.historicalMarketDayMinCoverageRatio] 即視為缺漏，
  /// 以 [PriceRepository.backfillTwsePricesByDate] /
  /// [PriceRepository.backfillTpexPricesByDate] 一次補齊該市場一天。
  ///
  /// 防護：
  /// - 單次上限 [ApiConfig.historicalMarketDayMaxCallsPerRun]
  /// - 連續零筆 [ApiConfig.historicalMarketDayMaxConsecutiveZeroDays]
  ///   中止（端點失效 / 日曆未知休市）
  /// - RateLimit / Network 中止 phase 0 但不外拋——phase 1 走 FinMind，
  ///   不同 API 來源不受牽連
  /// - 股票主檔為空（fresh DB 首次更新，尚未同步股票清單）→ 跳過
  ///
  /// 回傳實際寫入的價格列數。
  Future<int> _syncMissingMarketDays({
    required DateTime date,
    void Function(String message)? onProgress,
  }) async {
    // 各市場目標股票集合與缺漏門檻
    final targets = <String, Set<String>>{};
    final thresholds = <String, int>{};
    for (final market in [MarketCode.twse, MarketCode.tpex]) {
      final stocks = await _db.getStocksByMarket(market);
      if (stocks.isEmpty) continue;
      targets[market] = stocks.map((s) => s.symbol).toSet();
      thresholds[market] =
          (stocks.length * ApiConfig.historicalMarketDayMinCoverageRatio)
              .ceil();
    }
    if (targets.isEmpty) return 0;

    // 掃描缺漏（日, 市場），今日不含（由每日同步負責），新→舊
    final endDay = DateTime(date.year, date.month, date.day);
    final windowStart = endDay.subtract(
      const Duration(days: RuleParams.historyRequiredDays),
    );
    final tasks = <(DateTime, String)>[];
    for (
      var day = endDay.subtract(const Duration(days: 1));
      !day.isBefore(windowStart) &&
          tasks.length < ApiConfig.historicalMarketDayMaxCallsPerRun;
      day = day.subtract(const Duration(days: 1))
    ) {
      if (!TaiwanCalendar.isTradingDay(day)) continue;
      for (final market in targets.keys) {
        if (tasks.length >= ApiConfig.historicalMarketDayMaxCallsPerRun) {
          break;
        }
        final count = await _db.countPricesByDateAndMarket(day, market);
        if (count < thresholds[market]!) tasks.add((day, market));
      }
    }
    if (tasks.isEmpty) return 0;

    AppLogger.info(
      'HistoricalPriceSyncer',
      '市場日快照回補: ${tasks.length} 個(日,市場)缺漏，開始逐日回補',
    );

    var totalRows = 0;
    var consecutiveZero = 0;
    var processed = 0;
    for (final (day, market) in tasks) {
      if (processed > 0) await Future.delayed(marketDayCallDelay);
      processed++;
      onProgress?.call('市場日回補 ($processed/${tasks.length})');
      try {
        final added = market == MarketCode.twse
            ? await _priceRepo.backfillTwsePricesByDate(
                date: day,
                targetSymbols: targets[market]!,
              )
            : await _priceRepo.backfillTpexPricesByDate(
                date: day,
                targetSymbols: targets[market]!,
              );
        if (added > 0) {
          totalRows += added;
          consecutiveZero = 0;
        } else {
          consecutiveZero++;
        }
      } on RateLimitException {
        AppLogger.warning(
          'HistoricalPriceSyncer',
          '市場日回補 API 限流，中止 phase 0（phase 1 照常）',
        );
        break;
      } on NetworkException {
        AppLogger.warning(
          'HistoricalPriceSyncer',
          '市場日回補網路異常，中止 phase 0（phase 1 照常）',
        );
        break;
      } on Exception catch (e) {
        // 單日失敗（如 DatabaseException）：計入零筆 streak 後續行，
        // 連續失敗同樣觸發中止
        consecutiveZero++;
        AppLogger.warning(
          'HistoricalPriceSyncer',
          '市場日回補失敗 $market ${day.year}-${day.month}-${day.day}: $e',
        );
      }
      if (consecutiveZero >=
          ApiConfig.historicalMarketDayMaxConsecutiveZeroDays) {
        AppLogger.warning(
          'HistoricalPriceSyncer',
          '市場日回補連續 $consecutiveZero 日零筆，推測端點異常，中止 phase 0',
        );
        break;
      }
    }

    AppLogger.info(
      'HistoricalPriceSyncer',
      '市場日快照回補完成: +$totalRows 列（$processed/${tasks.length} 日）',
    );
    return totalRows;
  }

  /// 判斷哪些 symbol 需要補歷史資料
  ///
  /// [priorityLocked] 為自選 + 熱門股 union — 它們不適用 [nearThreshold]
  /// lenient 早退（180 天），必須追到 [minRequiredDays]（250 天）才算夠。
  /// 與下游 52w high/low rule 的硬性需求對齊；non-priority 股維持 180
  /// 早退避免無效追打。
  List<String> _findSymbolsNeedingData(
    List<String> symbols,
    Map<String, List<DailyPriceEntry>> priceHistoryBatch,
    DateTime date, {
    Set<String> priorityLocked = const {},
  }) {
    final result = <String>[];
    const minRequiredDays = IndicatorParams.week52Days;
    const nearThreshold = IndicatorParams.historyNearCompleteThreshold;

    for (final symbol in symbols) {
      final prices = priceHistoryBatch[symbol];
      final priceCount = prices?.length ?? 0;

      if (priceCount >= minRequiredDays) continue;

      // Priority 股（watchlist + popular）的早退條件**只認嚴格 250 天**。
      // 對它們 skip nearThreshold + _hasEnoughDataForAge — 因下游 52w
      // high/low rule 嚴格要求 250 交易日，priority 股若卡在 200-240
      // 區間會永遠補不到，相關規則永久無法觸發（2026-06 production：
      // 2330/2317/2454 等 popular 全卡 221/250）。
      // Non-priority 股維持原本 lenient 早退避免無效追打。
      final isPriority = priorityLocked.contains(symbol);

      if (!isPriority && priceCount >= nearThreshold) continue;

      if (priceCount == 0) {
        result.add(symbol);
        continue;
      }

      // 對已有資料的股票，檢查是否為近期上市且資料已足夠
      // 避免反覆向 TWSE 查詢不存在的歷史資料
      if (prices != null && prices.isNotEmpty) {
        final firstTradeDate = prices.first.date;
        final daysSinceFirstTrade = date.difference(firstTradeDate).inDays;

        // Fresh DB 場景：首筆資料是最近 3 天內（可能只從今日同步取得），
        // 且資料量極少 → 仍需補歷史
        // 例外：若首筆資料日期 > 今天 - 3 天，且最後一筆已是最新，
        // 且已有 > 1 天的歷史（代表曾同步過），視為新上市而非 fresh DB
        if (daysSinceFirstTrade <= 3 && priceCount < RuleParams.swingWindow) {
          final lastDate = prices.last.date;
          final isUpToDate = date.difference(lastDate).inDays <= 1;
          final hasMultipleDays = priceCount > 1;
          if (isUpToDate && hasMultipleDays && daysSinceFirstTrade > 0) {
            // 新上市股票：有多天資料且已是最新，走 _hasEnoughDataForAge 判斷
          } else {
            result.add(symbol);
            continue;
          }
        }

        // 其他情況：檢查資料量是否與上市時間相符
        // Priority 股 skip 此 ratio check — 它們追的是「is 250 enough」
        // 而非「is data-density acceptable for current age」。
        if (!isPriority && _hasEnoughDataForAge(prices, priceCount, date)) {
          continue;
        }
      }

      result.add(symbol);
    }

    return result;
  }

  /// 檢查股票的資料量是否與其上市時間相符
  ///
  /// 避免反覆同步數據源無法提供更多資料的股票
  bool _hasEnoughDataForAge(
    List<DailyPriceEntry> prices,
    int priceCount,
    DateTime date,
  ) {
    final firstTradeDate = prices.first.date;
    final daysSinceFirstTrade = date.difference(firstTradeDate).inDays;

    // 今天才上市（daysSinceFirstTrade == 0），有任何資料就算足夠
    if (daysSinceFirstTrade <= 0) return priceCount > 0;

    // 約 71% 的日曆天是交易日
    final expectedTradingDays =
        (daysSinceFirstTrade * DataFreshness.tradingDayRatio).round().clamp(
          1,
          daysSinceFirstTrade,
        );

    // 只要資料達到預期的 50% 就視為足夠
    final minAcceptableDays =
        (expectedTradingDays * DataFreshness.minAcceptableDataRatio).round();
    return priceCount >= minAcceptableDays;
  }

  /// 記錄需要同步的股票診斷資訊
  void _logSyncDiagnostics(
    List<String> symbolsNeedingData,
    Map<String, List<DailyPriceEntry>> priceHistoryBatch,
  ) {
    if (symbolsNeedingData.length <= 10) {
      final details = symbolsNeedingData
          .map((symbol) {
            final prices = priceHistoryBatch[symbol];
            final priceCount = prices?.length ?? 0;
            final firstDate = prices?.isNotEmpty == true
                ? '${prices!.first.date.month}/${prices.first.date.day}'
                : 'N/A';
            return '$symbol($priceCount 天,起:$firstDate)';
          })
          .join(', ');
      AppLogger.info('HistoricalPriceSyncer', '需要歷史資料: $details');
    } else {
      AppLogger.info(
        'HistoricalPriceSyncer',
        '需要歷史資料的股票: ${symbolsNeedingData.length} 檔',
      );
    }
  }

  /// 估算每檔股票平均需要的月度 API 呼叫數
  ///
  /// 鏡像 [PriceRepository.syncStockPrices] 第 134–161 行的月份迭代邏輯：
  ///   1. 對 `[historyStartDate, endDate]` 視窗內每個月份，
  ///   2. 跳過上市前的月份（cached ≥ 60 天時才信 firstKnownDate 作上市日代理），
  ///   3. 凡 cached days < [DataFreshness.minTradingDaysPerMonth] 的月份就計入。
  ///
  /// 早期版本對所有非零 symbol 一律假設 4 個月（[historicalPartialSyncMonths]，
  /// 已移除）。但實際 API 呼叫數取決於 cached 資料如何分佈於月份桶 — 若 222
  /// 天散落在 9 個月，缺口可能是 6 個月而非 4。低估會讓 maxSyncCount 估高，
  /// 超出真實 API budget 觸發限流（2026-06 production 案例：估 75 檔 × 4 月
  /// = 300 calls 預算，實打 75 × ~15 月 = 1125，跑到 16 檔就被擋）。
  double _estimateAvgMonthsNeeded(
    List<String> symbols,
    Map<String, List<DailyPriceEntry>> priceHistoryBatch, {
    required DateTime historyStartDate,
    required DateTime endDate,
  }) {
    if (symbols.isEmpty) return 1;

    // 預先計算視窗內月份清單（與 PriceRepository 的 while 迴圈邊界一致）
    final windowMonths = <(int, int)>[];
    var cur = DateTime(historyStartDate.year, historyStartDate.month, 1);
    final windowEnd = DateTime(endDate.year, endDate.month, 1);
    while (!cur.isAfter(windowEnd)) {
      windowMonths.add((cur.year, cur.month));
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    final totalWindowMonths = windowMonths.length;

    var totalMonthsNeeded = 0;
    for (final symbol in symbols) {
      final prices = priceHistoryBatch[symbol];
      if (prices == null || prices.isEmpty) {
        // 無資料：整個視窗都需抓取
        totalMonthsNeeded += totalWindowMonths;
        continue;
      }

      // group by (year, month) — 與 PriceRepository 第 128–132 行對齊
      final daysByMonth = <(int, int), int>{};
      for (final p in prices) {
        final key = (p.date.year, p.date.month);
        daysByMonth[key] = (daysByMonth[key] ?? 0) + 1;
      }

      // 鏡像 firstKnownDate 上市日邏輯（≥ 60 天才信任）
      // PriceRepository.syncStockPrices line 121–125
      final firstKnownDate = prices.length >= 60 ? prices.first.date : null;
      final firstKnownMonth = firstKnownDate != null
          ? (firstKnownDate.year, firstKnownDate.month)
          : null;

      var monthsNeeded = 0;
      for (final month in windowMonths) {
        // 跳過上市前月份
        if (firstKnownMonth != null) {
          final (fy, fm) = firstKnownMonth;
          final (my, mm) = month;
          if (my < fy || (my == fy && mm < fm)) continue;
        }
        final days = daysByMonth[month] ?? 0;
        if (days < DataFreshness.minTradingDaysPerMonth) {
          monthsNeeded++;
        }
      }
      totalMonthsNeeded += monthsNeeded;
    }

    return totalMonthsNeeded / symbols.length;
  }

  /// 依重要性排序並限制同步數量
  ///
  /// 優先順序：自選 > 熱門 > 其他
  /// 確保 TWSE 和 TPEX 都按比例分配到名額
  ///
  /// [avgMonthsPerSymbol] 越大代表每檔需要越多 API 呼叫，
  /// 動態降低同步數量避免觸發限流。
  Future<List<String>> _prioritizeSymbols(
    List<String> symbolsNeedingData, {
    required List<String> watchlistSymbols,
    required List<String> popularStocks,
    required double avgMonthsPerSymbol,
  }) async {
    // 以月度 API 呼叫預算計算動態上限
    // 正常日（avgMonths ≈ 1）→ 200 檔
    // Fresh DB（avgMonths ≈ 14）→ ~21 檔
    final maxSyncCount =
        (ApiConfig.historicalPriceMaxMonthlyApiCalls / avgMonthsPerSymbol)
            .ceil()
            .clamp(
              ApiConfig.historicalPriceMinSyncCount,
              ApiConfig.historicalPriceMaxSyncCount,
            );

    if (avgMonthsPerSymbol > 3) {
      AppLogger.info(
        'HistoricalPriceSyncer',
        '每檔平均需 ${avgMonthsPerSymbol.toStringAsFixed(1)} 個月 API 呼叫，'
            '動態限制為 $maxSyncCount 檔（API 預算 ${ApiConfig.historicalPriceMaxMonthlyApiCalls}）',
      );
    }

    if (symbolsNeedingData.length <= maxSyncCount) {
      return symbolsNeedingData;
    }

    final watchlistSet = watchlistSymbols.toSet();
    final popularSet = popularStocks.toSet();

    // 分成優先股（自選+熱門）和一般股
    final prioritySymbols = <String>[];
    final otherSymbols = <String>[];

    for (final symbol in symbolsNeedingData) {
      if (watchlistSet.contains(symbol) || popularSet.contains(symbol)) {
        prioritySymbols.add(symbol);
      } else {
        otherSymbols.add(symbol);
      }
    }

    // 排序優先股（自選 > 熱門）
    prioritySymbols.sort((a, b) {
      final aScore =
          (watchlistSet.contains(a) ? 2 : 0) + (popularSet.contains(a) ? 1 : 0);
      final bScore =
          (watchlistSet.contains(b) ? 2 : 0) + (popularSet.contains(b) ? 1 : 0);
      return bScore.compareTo(aScore);
    });

    final priorityCount = prioritySymbols.length.clamp(0, maxSyncCount);
    final remainingSlots = maxSyncCount - priorityCount;

    if (remainingSlots <= 0) {
      AppLogger.info('HistoricalPriceSyncer', '限制同步 $maxSyncCount 檔（全為自選/熱門）');
      return prioritySymbols.take(maxSyncCount).toList();
    }

    // 查詢市場資訊，按比例分配名額給 TWSE 和 TPEX
    final stockMap = await _db.getStocksBatch(otherSymbols);
    final twseOther = <String>[];
    final tpexOther = <String>[];

    for (final symbol in otherSymbols) {
      if (stockMap[symbol]?.market == MarketCode.tpex) {
        tpexOther.add(symbol);
      } else {
        twseOther.add(symbol);
      }
    }

    // 按市場比例分配（確保少數市場至少分到 1 個名額）
    final totalOther = twseOther.length + tpexOther.length;
    int tpexSlots;
    int twseSlots;

    if (totalOther == 0 || tpexOther.isEmpty) {
      tpexSlots = 0;
      twseSlots = remainingSlots;
    } else if (twseOther.isEmpty) {
      tpexSlots = remainingSlots;
      twseSlots = 0;
    } else {
      tpexSlots = (remainingSlots * tpexOther.length / totalOther)
          .round()
          .clamp(1, remainingSlots - 1);
      twseSlots = remainingSlots - tpexSlots;
    }

    final result = <String>[
      ...prioritySymbols.take(priorityCount),
      ...twseOther.take(twseSlots),
      ...tpexOther.take(tpexSlots),
    ];

    AppLogger.info(
      'HistoricalPriceSyncer',
      '限制同步 ${result.length} 檔'
          '（優先 $priorityCount, '
          'TWSE ${twseOther.take(twseSlots).length}, '
          'TPEx ${tpexOther.take(tpexSlots).length}）',
    );
    return result;
  }

  /// 執行批次同步
  Future<HistoricalPriceSyncResult> _performBatchSync(
    List<String> symbols, {
    required DateTime historyStartDate,
    required DateTime endDate,
    required int totalNeeded,
    void Function(String message)? onProgress,
  }) async {
    final total = symbols.length;
    var historySynced = 0;
    const batchSize = ApiConfig.historicalPriceBatchSize;
    final failedSymbols = <String>[];

    var rateLimited = false;
    var consecutiveFailedBatches = 0;
    var symbolsSucceeded = 0;

    for (var i = 0; i < total; i += batchSize) {
      if (rateLimited) break;
      if (i > 0) {
        await Future.delayed(
          const Duration(milliseconds: ApiConfig.priceRequestDelayMs),
        );
      }

      final batchEnd = (i + batchSize).clamp(0, total);
      final batch = symbols.sublist(i, batchEnd);

      onProgress?.call('歷史資料 (${i + 1}~$batchEnd / $total)');

      final futures = batch.map((symbol) async {
        try {
          final count = await _priceRepo.syncStockPrices(
            symbol,
            startDate: historyStartDate,
            endDate: endDate,
          );
          return (symbol, count, null as Object?);
        } catch (e) {
          return (symbol, 0, e);
        }
      });

      final results = await Future.wait(futures);

      var batchHasSuccess = false;
      for (final (symbol, count, error) in results) {
        if (error is RateLimitException) {
          rateLimited = true;
          failedSymbols.add(symbol);
          AppLogger.warning(
            'HistoricalPriceSyncer',
            '$symbol: API 限流，中止剩餘歷史資料同步',
          );
        } else if (error is NetworkException) {
          rateLimited = true;
          failedSymbols.add(symbol);
          AppLogger.warning(
            'HistoricalPriceSyncer',
            '$symbol: 網路異常，中止剩餘歷史資料同步',
          );
        } else if (error != null) {
          failedSymbols.add(symbol);
        } else {
          historySynced += count;
          batchHasSuccess = true;
          symbolsSucceeded++;
        }
      }

      // 防禦性 circuit breaker：連續多批全部失敗時視為 API 限流
      // 即使錯誤類型不是 RateLimitException（如 NetworkException），
      // 連續失敗也代表 API 不可用，應停止發送無效請求
      if (!rateLimited) {
        if (batchHasSuccess) {
          consecutiveFailedBatches = 0;
        } else {
          consecutiveFailedBatches++;
          if (consecutiveFailedBatches >=
              ApiConfig.historicalPriceMaxConsecutiveFailedBatches) {
            rateLimited = true;
            AppLogger.warning(
              'HistoricalPriceSyncer',
              '連續 $consecutiveFailedBatches 批全部失敗，推測 API 限流，中止同步',
            );
          }
        }
      }
    }

    AppLogger.info(
      'HistoricalPriceSyncer',
      '歷史資料同步完成 $symbolsSucceeded/${symbols.length} 檔'
          '${totalNeeded > symbols.length ? " (共需 $totalNeeded 檔)" : ""}',
    );

    return HistoricalPriceSyncResult(
      syncedCount: historySynced,
      symbolsProcessed: symbolsSucceeded,
      totalSymbolsNeeded: totalNeeded,
      failedSymbols: failedSymbols,
    );
  }
}

/// 歷史價格同步結果
class HistoricalPriceSyncResult {
  const HistoricalPriceSyncResult({
    required this.syncedCount,
    required this.symbolsProcessed,
    this.totalSymbolsNeeded = 0,
    this.failedSymbols = const [],
    this.marketDayRows = 0,
  });

  final int syncedCount;
  final int symbolsProcessed;
  final int totalSymbolsNeeded;
  final List<String> failedSymbols;

  /// Phase 0（市場日快照回補）寫入的價格列數
  final int marketDayRows;

  bool get hasErrors => failedSymbols.isNotEmpty;
}
