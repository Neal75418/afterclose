import 'package:drift/drift.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// 股票主檔 Repository
class StockRepository {
  StockRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  /// 取得所有上市中的股票
  Future<List<StockMasterEntry>> getAllStocks() {
    return _db.getAllActiveStocks();
  }

  /// 依代碼取得股票
  Future<StockMasterEntry?> getStock(String symbol) {
    return _db.getStock(symbol);
  }

  /// 從 FinMind API 同步股票清單
  ///
  /// 建議定期執行（如每週一次）以更新股票清單
  /// 僅同步有效股票代碼（4 位數一般股票 + 00 開頭 ETF）
  Future<int> syncStockList() async {
    try {
      final stocks = await _client.getStockList();

      // 過濾有效股票代碼：4 位數字（一般股票）或 00 開頭（ETF）
      // 排除 6 位數權證、TDR 等非股票代碼
      final validStockPattern = RegExp(r'^(\d{4}|00\d{3,4})$');

      final entries = stocks
          .where((stock) => validStockPattern.hasMatch(stock.stockId))
          .map((stock) {
            return StockMasterCompanion.insert(
              symbol: stock.stockId,
              name: stock.stockName,
              market: stock.market,
              industry: Value(stock.industryCategory),
              isActive: const Value(true),
            );
          })
          .toList();

      await _db.upsertStocks(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync stock list', e);
    }
  }

  /// 依名稱或代碼搜尋股票（Database 層級過濾）
  Future<List<StockMasterEntry>> searchStocks(String query) {
    return _db.searchStocks(query);
  }

  /// 依市場篩選股票（Database 層級過濾）
  Future<List<StockMasterEntry>> getStocksByMarket(String market) {
    return _db.getStocksByMarket(market);
  }

  /// 檢查股票是否存在
  Future<bool> stockExists(String symbol) async {
    final stock = await getStock(symbol);
    return stock != null;
  }
}
