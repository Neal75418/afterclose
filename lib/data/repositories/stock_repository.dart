import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/industry_names.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/request_deduplicator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/repositories/stock_repository.dart';

/// 股票主檔 Repository
class StockRepository implements IStockRepository {
  StockRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient;

  final AppDatabase _db;
  final FinMindClient _client;

  /// 上市官方產業別來源（t187ap03_L）。null（如部分工具鏈）＝不覆蓋，
  /// 沿用 FinMind 分類。
  final TwseClient? _twseClient;

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

  /// 取得產業股票數量統計
  @override
  Future<Map<String, int>> getIndustryStockCounts() {
    return _db.getIndustryStockCounts();
  }

  /// 從 FinMind API 同步股票清單
  ///
  /// 建議定期執行（如每週一次）以更新股票清單
  /// 僅同步有效股票代碼（4 位數一般股票 + 00 開頭 ETF）
  @override
  Future<int> syncStockList() async {
    try {
      final stocks = await _client.getStockList();

      // TWSE 官方產業別（免額度）：FinMind 上市電子股多塌陷泛用
      // 「電子工業」（2026-08-01 實測 305 檔 active，台積電在內——
      // 上市半導體/光電細分卡整組失真），官方 t187ap03_L 才有細分碼。
      // fail-soft：抓不到就沿用 FinMind 分類，同步不中斷。
      var officialCodes = const <String, String>{};
      final twse = _twseClient;
      if (twse != null) {
        try {
          officialCodes = await twse.fetchIndustryCodes();
        } catch (e) {
          AppLogger.warning('StockRepo', 'TWSE 官方產業別取得失敗，沿用 FinMind 分類', e);
        }
      }

      // 過濾有效股票代碼：4 位數字（一般股票）或 00 開頭（ETF）
      // 排除 6 位數權證、TDR 等非股票代碼
      final validStockPattern = RegExp(r'^(\d{4}|00\d{3,4})$');

      // FinMind 同一 symbol 可能回多列（細分＋泛用「電子工業」各一），
      // 直灌 upsert 會讓贏家隨回傳順序漂移——去重且細分優先。
      final bySymbol = <String, FinMindStockInfo>{};
      for (final stock in stocks) {
        if (!validStockPattern.hasMatch(stock.stockId)) continue;
        final prev = bySymbol[stock.stockId];
        if (prev == null ||
            (prev.industryCategory == '電子工業' &&
                stock.industryCategory != '電子工業')) {
          bySymbol[stock.stockId] = stock;
        }
      }

      final entries = bySymbol.values.map((stock) {
        final official = stock.market == MarketCode.twse
            ? IndustryNames.nameForTwseCode(officialCodes[stock.stockId] ?? '')
            : null;
        return StockMasterCompanion.insert(
          symbol: stock.stockId,
          name: stock.stockName,
          market: stock.market,
          industry: Value(
            official ?? _normalizeIndustry(stock.industryCategory),
          ),
          isActive: const Value(true),
        );
      }).toList();

      // upsert + deactivate 應為原子操作，避免中途失敗造成不一致
      int deactivated = 0;
      await _db.transaction(() async {
        await _db.upsertStocks(entries);

        // 將不在 API 回傳清單中的股票標記為下市
        final activeSymbols = entries.map((e) => e.symbol.value).toSet();
        deactivated = await _db.deactivateStocksNotIn(activeSymbols);
      });
      if (deactivated > 0) {
        AppLogger.info('StockRepo', '標記 $deactivated 檔股票為下市');
      }

      return entries.length;
    } on RateLimitException catch (e) {
      AppLogger.warning('StockRepo', '股票清單同步觸發 API 速率限制', e);
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync stock list', e);
    }
  }

  /// 正規化產業名稱（FinMind API 回傳的名稱有不一致）
  ///
  /// 例如 TPEx 同一產業可能出現：「其他電子業」與「其他電子類」、
  /// 「居家生活」與「居家生活類」等重複命名。
  /// 對照表定義於 [IndustryNames.normalizationMap]。
  static String _normalizeIndustry(String raw) => IndustryNames.normalize(raw);

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
}
