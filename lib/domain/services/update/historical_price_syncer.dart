import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/price_repository.dart';

/// 歷史價格資料同步器
///
/// 負責確保分析所需的歷史價格資料完整
class HistoricalPriceSyncer {
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

    final limitedSymbols = _prioritizeSymbols(
      symbolsNeedingData,
      watchlistSymbols: watchlistSymbols,
      popularStocks: popularStocks,
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
    const minRequiredDays = RuleParams.week52Days;
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

      if (prices != null &&
          prices.isNotEmpty &&
          _hasEnoughDataForAge(prices, priceCount, date)) {
        continue;
      }

      result.add(symbol);
    }

    return result;
  }

  /// 檢查較新上市的股票是否已有足夠的資料
  ///
  /// 避免反覆呼叫 API 試圖取得不存在的歷史資料
  bool _hasEnoughDataForAge(
    List<DailyPriceEntry> prices,
    int priceCount,
    DateTime date,
  ) {
    final firstTradeDate = prices.first.date;
    final daysSinceFirstTrade = date.difference(firstTradeDate).inDays;

    if (daysSinceFirstTrade >= 365) return false;

    // 約 71% 的日曆天是交易日
    final expectedTradingDays = (daysSinceFirstTrade * 0.71).round().clamp(
      1,
      365,
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

  /// 依重要性排序並限制同步數量
  ///
  /// 優先順序：自選 > 熱門 > 其他
  List<String> _prioritizeSymbols(
    List<String> symbolsNeedingData, {
    required List<String> watchlistSymbols,
    required List<String> popularStocks,
  }) {
    const maxSyncCount = 60;
    if (symbolsNeedingData.length <= maxSyncCount) {
      return symbolsNeedingData;
    }

    final watchlistSet = watchlistSymbols.toSet();
    final popularSet = popularStocks.toSet();

    final sorted = symbolsNeedingData.toList()
      ..sort((a, b) {
        final aScore =
            (watchlistSet.contains(a) ? 2 : 0) +
            (popularSet.contains(a) ? 1 : 0);
        final bScore =
            (watchlistSet.contains(b) ? 2 : 0) +
            (popularSet.contains(b) ? 1 : 0);
        return bScore.compareTo(aScore);
      });

    AppLogger.info('HistoricalPriceSyncer', '限制同步 $maxSyncCount 檔（優先自選和熱門股）');
    return sorted.take(maxSyncCount).toList();
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
    const batchSize = 2;
    final failedSymbols = <String>[];

    for (var i = 0; i < total; i += batchSize) {
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

      for (final (symbol, count, error) in results) {
        if (error != null) {
          failedSymbols.add(symbol);
        } else {
          historySynced += count;
        }
      }
    }

    final successCount = symbols.length - failedSymbols.length;
    AppLogger.info(
      'HistoricalPriceSyncer',
      '歷史資料同步完成 $successCount/${symbols.length} 檔'
          '${totalNeeded > symbols.length ? " (共需 $totalNeeded 檔)" : ""}',
    );

    return HistoricalPriceSyncResult(
      syncedCount: historySynced,
      symbolsProcessed: successCount,
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
