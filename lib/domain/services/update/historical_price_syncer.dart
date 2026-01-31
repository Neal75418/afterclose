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

    final symbolsNeedingData = <String>[];
    const minRequiredDays = RuleParams.week52Days;

    for (final symbol in symbolsForHistory) {
      final prices = priceHistoryBatch[symbol];
      final priceCount = prices?.length ?? 0;

      if (priceCount < minRequiredDays) {
        // 接近完整資料時（>= 180 天）可以跳過
        const nearThreshold = 180;
        if (priceCount >= nearThreshold) {
          continue;
        }

        // 檢查是否為較新的股票（資料天數已符合其上市天數的預期）
        // 避免反覆呼叫 API 試圖取得不存在的歷史資料
        if (prices != null && prices.isNotEmpty) {
          final firstTradeDate = prices.first.date;
          final daysSinceFirstTrade = date.difference(firstTradeDate).inDays;

          if (daysSinceFirstTrade < 365) {
            // 計算預期交易天數（約 71% 的日曆天是交易日）
            final expectedTradingDays = (daysSinceFirstTrade * 0.71)
                .round()
                .clamp(1, 365);

            // 只要資料達到預期的 50% 就視為足夠
            final minAcceptableDays = (expectedTradingDays * 0.5).round();
            if (priceCount >= minAcceptableDays) {
              continue;
            }
          }
        } else if (priceCount == 0) {
          // 完全無資料，需要同步
          symbolsNeedingData.add(symbol);
          continue;
        }

        symbolsNeedingData.add(symbol);
      }
    }

    if (symbolsNeedingData.isEmpty) {
      onProgress?.call('歷史資料已完整');
      return const HistoricalPriceSyncResult(
        syncedCount: 0,
        symbolsProcessed: 0,
      );
    }

    // 記錄需要同步的股票及其原因（便於診斷）
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

    // 若需要同步的股票過多，限制數量避免 API 超限
    // 優先同步自選清單和熱門股
    const maxSyncCount = 60;
    var limitedSymbols = symbolsNeedingData;
    if (symbolsNeedingData.length > maxSyncCount) {
      final watchlistSet = watchlistSymbols.toSet();
      final popularSet = popularStocks.toSet();

      // 優先排序：自選 > 熱門 > 其他
      limitedSymbols = symbolsNeedingData.toList()
        ..sort((a, b) {
          final aScore =
              (watchlistSet.contains(a) ? 2 : 0) +
              (popularSet.contains(a) ? 1 : 0);
          final bScore =
              (watchlistSet.contains(b) ? 2 : 0) +
              (popularSet.contains(b) ? 1 : 0);
          return bScore.compareTo(aScore);
        });
      limitedSymbols = limitedSymbols.take(maxSyncCount).toList();

      AppLogger.info('HistoricalPriceSyncer', '限制同步 $maxSyncCount 檔（優先自選和熱門股）');
    }

    // 批次同步歷史資料
    final total = limitedSymbols.length;
    var historySynced = 0;
    const batchSize = 2;
    final failedSymbols = <String>[];

    for (var i = 0; i < total; i += batchSize) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 200));

      final batchEnd = (i + batchSize).clamp(0, total);
      final batch = limitedSymbols.sublist(i, batchEnd);

      onProgress?.call('歷史資料 (${i + 1}~$batchEnd / $total)');

      final futures = batch.map((symbol) async {
        try {
          final count = await _priceRepo.syncStockPrices(
            symbol,
            startDate: historyStartDate,
            endDate: date,
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

    final successCount = limitedSymbols.length - failedSymbols.length;
    AppLogger.info(
      'HistoricalPriceSyncer',
      '歷史資料同步完成 $successCount/${limitedSymbols.length} 檔'
          '${symbolsNeedingData.length > limitedSymbols.length ? " (共需 ${symbolsNeedingData.length} 檔)" : ""}',
    );

    return HistoricalPriceSyncResult(
      syncedCount: historySynced,
      symbolsProcessed: successCount,
      totalSymbolsNeeded: symbolsNeedingData.length,
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
