import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/price_repository.dart';

/// 歷史價格資料同步器
///
/// 負責確保分析所需的歷史價格資料完整
class HistoricalPriceSyncer {
  /// 連續全部失敗的批次數上限，超過即視為 API 限流
  static const _maxConsecutiveFailedBatches = 2;

  const HistoricalPriceSyncer({
    required AppDatabase database,
    required PriceRepository priceRepository,
  }) : _db = database,
       _priceRepo = priceRepository;

  final AppDatabase _db;
  final PriceRepository _priceRepo;

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
    // 整合所有歷史資料來源
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

    final symbolsNeedingData = _findSymbolsNeedingData(
      symbolsForHistory,
      priceHistoryBatch,
      date,
    );

    if (symbolsNeedingData.isEmpty) {
      onProgress?.call('歷史資料已完整');
      return const HistoricalPriceSyncResult(
        syncedCount: 0,
        symbolsProcessed: 0,
      );
    }

    _logSyncDiagnostics(symbolsNeedingData, priceHistoryBatch);

    // 估算每檔平均需要的月度 API 呼叫數
    final avgMonthsPerSymbol = _estimateAvgMonthsNeeded(
      symbolsNeedingData,
      priceHistoryBatch,
    );

    final limitedSymbols = await _prioritizeSymbols(
      symbolsNeedingData,
      watchlistSymbols: watchlistSymbols,
      popularStocks: popularStocks,
      avgMonthsPerSymbol: avgMonthsPerSymbol,
    );

    return _performBatchSync(
      limitedSymbols,
      historyStartDate: historyStartDate,
      endDate: date,
      totalNeeded: symbolsNeedingData.length,
      onProgress: onProgress,
    );
  }

  /// 判斷哪些 symbol 需要補歷史資料
  List<String> _findSymbolsNeedingData(
    List<String> symbols,
    Map<String, List<DailyPriceEntry>> priceHistoryBatch,
    DateTime date,
  ) {
    final result = <String>[];
    const minRequiredDays = IndicatorParams.week52Days;
    const nearThreshold = 180;

    for (final symbol in symbols) {
      final prices = priceHistoryBatch[symbol];
      final priceCount = prices?.length ?? 0;

      if (priceCount >= minRequiredDays) continue;
      if (priceCount >= nearThreshold) continue;

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
        if (daysSinceFirstTrade <= 3 && priceCount < RuleParams.swingWindow) {
          result.add(symbol);
          continue;
        }

        // 其他情況：檢查資料量是否與上市時間相符
        if (_hasEnoughDataForAge(prices, priceCount, date)) {
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

    // 約 71% 的日曆天是交易日
    final expectedTradingDays = (daysSinceFirstTrade * 0.71).round().clamp(
      1,
      daysSinceFirstTrade,
    );

    // 只要資料達到預期的 50% 就視為足夠
    final minAcceptableDays = (expectedTradingDays * 0.5).round();
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
  /// DB 無資料的股票需要 ~14 個月（完整歷史），有部分資料的需要較少。
  /// 用於動態調整 maxSyncCount，避免 Fresh DB 場景一次發出過多請求。
  double _estimateAvgMonthsNeeded(
    List<String> symbols,
    Map<String, List<DailyPriceEntry>> priceHistoryBatch,
  ) {
    if (symbols.isEmpty) return 1;

    var zeroDataCount = 0;
    var partialDataCount = 0;
    for (final symbol in symbols) {
      final priceCount = priceHistoryBatch[symbol]?.length ?? 0;
      if (priceCount == 0) {
        zeroDataCount++;
      } else {
        partialDataCount++;
      }
    }

    // 無資料的需要完整 14 個月；有部分資料的平均需要 4 個月
    const fullMonths = 14;
    const partialMonths = 4;
    final total = zeroDataCount * fullMonths + partialDataCount * partialMonths;
    return total / symbols.length;
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
    const maxMonthlyApiCalls = 300;
    const absoluteMax = 200;
    const absoluteMin = 15;
    final maxSyncCount = (maxMonthlyApiCalls / avgMonthsPerSymbol).ceil().clamp(
      absoluteMin,
      absoluteMax,
    );

    if (avgMonthsPerSymbol > 3) {
      AppLogger.info(
        'HistoricalPriceSyncer',
        '每檔平均需 ${avgMonthsPerSymbol.toStringAsFixed(1)} 個月 API 呼叫，'
            '動態限制為 $maxSyncCount 檔（API 預算 $maxMonthlyApiCalls）',
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
      if (stockMap[symbol]?.market == 'TPEx') {
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
    const batchSize = 5;
    final failedSymbols = <String>[];

    var rateLimited = false;
    var consecutiveFailedBatches = 0;
    var symbolsSucceeded = 0;

    for (var i = 0; i < total; i += batchSize) {
      if (rateLimited) break;
      if (i > 0) await Future.delayed(const Duration(milliseconds: 200));

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
          if (consecutiveFailedBatches >= _maxConsecutiveFailedBatches) {
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
  });

  final int syncedCount;
  final int symbolsProcessed;
  final int totalSymbolsNeeded;
  final List<String> failedSymbols;

  bool get hasFailures => failedSymbols.isNotEmpty;
}
