import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';

/// 股票清單同步器
///
/// 負責同步上市櫃股票清單
class StockListSyncer {
  const StockListSyncer({required StockRepository stockRepository})
    : _stockRepo = stockRepository;

  final StockRepository _stockRepo;

  /// 同步股票清單
  ///
  /// 從 TWSE/TPEx 取得最新股票清單
  Future<StockListSyncResult> syncStockList() async {
    try {
      final count = await _stockRepo.syncStockList();

      AppLogger.info('StockListSyncer', '股票清單同步完成: $count 檔');

      return StockListSyncResult(stockCount: count, success: true);
    } catch (e) {
      AppLogger.warning('StockListSyncer', '股票清單同步失敗: $e');

      return StockListSyncResult(
        stockCount: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 取得現有股票數量
  Future<int> getExistingStockCount() async {
    final stocks = await _stockRepo.getAllStocks();
    return stocks.length;
  }

  /// 檢查是否需要初始化股票清單
  ///
  /// 台股約有 1000+ 檔股票，若過少則需同步
  Future<bool> needsInitialization({int minStockCount = 500}) async {
    final count = await getExistingStockCount();
    return count < minStockCount;
  }

  /// 檢查是否應更新股票清單（每週一）
  bool shouldUpdateStockList(DateTime date) {
    return date.weekday == DateTime.monday;
  }

  /// 智慧同步股票清單
  ///
  /// 根據條件判斷是否需要同步：
  /// - 強制更新
  /// - 資料庫為空或不完整
  /// - 週一例行更新
  Future<StockListSyncResult> smartSync({
    required DateTime date,
    bool force = false,
  }) async {
    final needsInit = await needsInitialization();
    final shouldUpdate = shouldUpdateStockList(date);

    if (force || needsInit || shouldUpdate) {
      return syncStockList();
    }

    return const StockListSyncResult(
      stockCount: 0,
      success: true,
      skipped: true,
    );
  }
}

/// 股票清單同步結果
class StockListSyncResult {
  const StockListSyncResult({
    required this.stockCount,
    required this.success,
    this.error,
    this.skipped = false,
  });

  final int stockCount;
  final bool success;
  final String? error;
  final bool skipped;
}
