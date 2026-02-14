import 'package:afterclose/data/database/app_database.dart';

/// 股票主檔資料儲存庫介面
///
/// 提供股票清單的查詢與同步功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IStockRepository {
  /// 取得所有上市中的股票
  Future<List<StockMasterEntry>> getAllStocks();

  /// 依代碼取得股票
  Future<StockMasterEntry?> getStock(String symbol);

  /// 依名稱或代碼搜尋股票
  Future<List<StockMasterEntry>> searchStocks(String query);

  /// 依市場篩選股票
  Future<List<StockMasterEntry>> getStocksByMarket(String market);

  /// 檢查股票是否存在
  Future<bool> stockExists(String symbol);

  /// 從遠端 API 同步股票清單
  Future<int> syncStockList();
}
