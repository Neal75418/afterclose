import 'package:drift/drift.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// Repository for stock master data
class StockRepository {
  StockRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  /// Get all active stocks from local database
  Future<List<StockMasterEntry>> getAllStocks() {
    return _db.getAllActiveStocks();
  }

  /// Get stock by symbol
  Future<StockMasterEntry?> getStock(String symbol) {
    return _db.getStock(symbol);
  }

  /// Sync stock list from FinMind API
  ///
  /// This should be called periodically (e.g., weekly) to update the stock list
  Future<int> syncStockList() async {
    try {
      final stocks = await _client.getStockList();

      final entries = stocks.map((stock) {
        return StockMasterCompanion.insert(
          symbol: stock.stockId,
          name: stock.stockName,
          market: stock.market,
          industry: Value(stock.industryCategory),
          isActive: const Value(true),
        );
      }).toList();

      await _db.upsertStocks(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync stock list', e);
    }
  }

  /// Search stocks by name or symbol (uses DB-level filtering)
  Future<List<StockMasterEntry>> searchStocks(String query) {
    return _db.searchStocks(query);
  }

  /// Get stocks by market (uses DB-level filtering)
  Future<List<StockMasterEntry>> getStocksByMarket(String market) {
    return _db.getStocksByMarket(market);
  }

  /// Check if stock exists
  Future<bool> stockExists(String symbol) async {
    final stock = await getStock(symbol);
    return stock != null;
  }
}
