import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/repositories/price_candidate_filter.dart';

/// TPEX 上櫃股票價格資料來源
///
/// 全市場資料使用 TPEX Open Data，單檔歷史使用 FinMind API。
class TpexPriceSource {
  TpexPriceSource({required TpexClient client, required FinMindClient finMind})
    : _client = client,
      _finMind = finMind;

  final TpexClient _client;
  final FinMindClient _finMind;

  /// 從 FinMind API 取得單檔上櫃股票價格
  Future<List<DailyPriceCompanion>> fetchSingleStockPrices({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _finMind.getDailyPrices(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
      );

      if (data.isEmpty) return [];

      final entries = <DailyPriceCompanion>[];
      for (final price in data) {
        final date = DateTime.tryParse(price.date);
        if (date == null) {
          AppLogger.warning(
            'PriceRepo',
            '上櫃價格日期解析失敗，跳過: $symbol, date=${price.date}',
          );
          continue;
        }
        entries.add(
          DailyPriceCompanion.insert(
            symbol: symbol,
            date: date,
            open: Value(price.open),
            high: Value(price.high),
            low: Value(price.low),
            close: Value(price.close),
            volume: Value(price.volume),
          ),
        );
      }

      return entries;
    } on RateLimitException {
      AppLogger.warning('PriceRepo', '$symbol: 上櫃價格同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync OTC prices for $symbol', e);
    }
  }

  /// 取得全市場上櫃股票價格
  ///
  /// [date] 指定交易日期，避免非交易日取到空資料。
  Future<List<TpexDailyPrice>> fetchAllDailyPrices({DateTime? date}) {
    return _client.getAllDailyPrices(date: date);
  }

  /// 將原始上櫃股票資料轉換為 DB 格式（價格 + 股票主檔 + 候選股）
  ({
    List<DailyPriceCompanion> priceEntries,
    List<StockMasterCompanion> stockEntries,
    List<String> candidates,
    DateTime? dataDate,
  })
  processDailyPrices(List<TpexDailyPrice> prices) {
    final priceEntries = prices
        .where((price) => StockPatterns.isValidCode(price.code))
        .map((price) {
          return DailyPriceCompanion.insert(
            symbol: price.code,
            date: price.date,
            open: Value(price.open),
            high: Value(price.high),
            low: Value(price.low),
            close: Value(price.close),
            volume: Value(price.volume),
            priceChange: Value(price.change),
          );
        })
        .toList();

    final stockEntries = prices
        .where((p) => p.name.isNotEmpty && StockPatterns.isValidCode(p.code))
        .map((price) {
          return StockMasterCompanion.insert(
            symbol: price.code,
            name: price.name,
            market: 'TPEx',
            isActive: const Value(true),
          );
        })
        .toList();

    final candidates = quickFilterPrices(
      prices,
      getCode: (p) => p.code,
      getClose: (p) => p.close,
      getChange: (p) => p.change,
      getVolume: (p) => p.volume,
    );

    return (
      priceEntries: priceEntries,
      stockEntries: stockEntries,
      candidates: candidates,
      dataDate: prices.isNotEmpty ? prices.first.date : null,
    );
  }
}
