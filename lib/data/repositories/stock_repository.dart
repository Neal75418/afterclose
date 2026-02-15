import 'package:drift/drift.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/request_deduplicator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/repositories/stock_repository.dart';

/// 股票主檔 Repository
class StockRepository implements IStockRepository {
  StockRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  /// Request deduplicator for getAllStocks
  final _stockListDedup = RequestDeduplicator<List<StockMasterEntry>>();

  /// 取得所有上市中的股票
  ///
  /// 使用 Request Deduplication 防止同時多次查詢
  @override
  Future<List<StockMasterEntry>> getAllStocks() {
    return _stockListDedup.call('all_stocks', () => _db.getAllActiveStocks());
  }

  /// 依代碼取得股票
  @override
  Future<StockMasterEntry?> getStock(String symbol) {
    return _db.getStock(symbol);
  }

  /// 從 FinMind API 同步股票清單
  ///
  /// 建議定期執行（如每週一次）以更新股票清單
  /// 僅同步有效股票代碼（4 位數一般股票 + 00 開頭 ETF）
  @override
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

      // 將不在 API 回傳清單中的股票標記為下市
      final activeSymbols = entries.map((e) => e.symbol.value).toSet();
      final deactivated = await _db.deactivateStocksNotIn(activeSymbols);
      if (deactivated > 0) {
        AppLogger.info('StockRepo', '標記 $deactivated 檔股票為下市');
      }

      return entries.length;
    } on RateLimitException {
      AppLogger.warning('StockRepo', '股票清單同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync stock list', e);
    }
  }

  /// 依名稱或代碼搜尋股票（Database 層級過濾）
  @override
  Future<List<StockMasterEntry>> searchStocks(String query) {
    return _db.searchStocks(query);
  }

  /// 依市場篩選股票（Database 層級過濾）
  @override
  Future<List<StockMasterEntry>> getStocksByMarket(String market) {
    return _db.getStocksByMarket(market);
  }

  /// 檢查股票是否存在
  @override
  Future<bool> stockExists(String symbol) async {
    final stock = await getStock(symbol);
    return stock != null;
  }
}
