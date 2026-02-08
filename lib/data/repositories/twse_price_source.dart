import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/price_candidate_filter.dart';

/// TWSE 上市股票價格資料來源
///
/// 封裝 TWSE API 呼叫與資料轉換邏輯。
class TwsePriceSource {
  TwsePriceSource({required TwseClient client}) : _client = client;

  final TwseClient _client;

  /// 從 TWSE API 取得指定月份的價格，轉換為 DB 格式
  ///
  /// 逐月抓取，跳過失敗的月份。API 請求間加入延遲避免 rate limit。
  Future<List<DailyPriceCompanion>> fetchMonthlyPrices({
    required String symbol,
    required List<DateTime> months,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allPrices = <TwseDailyPrice>[];

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      try {
        final monthData = await _client.getStockMonthlyPrices(
          code: symbol,
          year: month.year,
          month: month.month,
        );
        allPrices.addAll(monthData);
      } on RateLimitException {
        AppLogger.warning('PriceRepo', '$symbol: 上市價格同步觸發 API 速率限制');
        rethrow;
      } catch (e) {
        AppLogger.warning(
          'PriceRepo',
          '$symbol: ${month.year}-${month.month} 月份價格取得失敗',
          e,
        );
      }

      if (i < months.length - 1) {
        await Future.delayed(
          const Duration(milliseconds: ApiConfig.priceBatchQueryDelayMs),
        );
      }
    }

    // 過濾至請求的日期範圍
    return allPrices
        .where((p) => !p.date.isBefore(startDate) && !p.date.isAfter(endDate))
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
  }

  /// 取得全市場上市股票今日價格
  Future<List<TwseDailyPrice>> fetchAllDailyPrices() {
    return _client.getAllDailyPrices();
  }

  /// 將原始上市股票資料轉換為 DB 格式（價格 + 股票主檔 + 候選股）
  ({
    List<DailyPriceCompanion> priceEntries,
    List<StockMasterCompanion> stockEntries,
    List<String> candidates,
    DateTime? dataDate,
  })
  processDailyPrices(List<TwseDailyPrice> prices) {
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
            market: 'TWSE',
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
