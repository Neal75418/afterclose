import 'package:afterclose/data/database/app_database.dart';

/// 股價相關計算工具
class PriceCalculator {
  PriceCalculator._();

  /// 根據價格歷史計算漲跌幅百分比
  ///
  /// 以下情況回傳 null：
  /// - latestPrice 為 null
  /// - history 資料少於 2 筆（若 history 包含 latestPrice 日期）
  /// - history 資料為空（若 history 不包含 latestPrice 日期）
  /// - 前一日收盤價為 null 或零
  ///
  /// 注意：此函數會根據 history 是否包含 latestPrice 的日期來決定
  /// 使用哪一筆資料作為前一日價格：
  /// - 若 history.last 與 latestPrice 同日，使用 history[length-2]
  /// - 若 history.last 早於 latestPrice，使用 history.last
  static double? calculatePriceChange(
    List<DailyPriceEntry> history,
    DailyPriceEntry? latestPrice,
  ) {
    if (latestPrice == null || latestPrice.close == null) return null;
    if (history.isEmpty) return null;

    final latestClose = latestPrice.close!;
    final latestDate = _normalizeDate(latestPrice.date);
    final historyLastDate = _normalizeDate(history.last.date);

    // 判斷 history 是否已包含 latestPrice 的日期
    final historyIncludesLatest = historyLastDate == latestDate;

    double? prevClose;
    if (historyIncludesLatest) {
      // history 包含最新價格，前一日是倒數第二筆
      if (history.length < 2) return null;
      prevClose = history[history.length - 2].close;
    } else {
      // history 不包含最新價格，前一日是 history 的最後一筆
      prevClose = history.last.close;
    }

    if (prevClose == null || prevClose == 0) return null;

    return ((latestClose - prevClose) / prevClose) * 100;
  }

  /// 標準化日期為 UTC 午夜以確保比較一致性
  static DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// 直接由兩個價格計算漲跌幅
  static double? calculatePriceChangeFromPrices(
    double? currentPrice,
    double? previousPrice,
  ) {
    if (currentPrice == null || previousPrice == null || previousPrice == 0) {
      return null;
    }
    return ((currentPrice - previousPrice) / previousPrice) * 100;
  }

  /// 批次計算多檔股票的漲跌幅
  ///
  /// 輸入股票代號對應的價格歷史與最新價格，
  /// 回傳股票代號對應的漲跌幅百分比。
  static Map<String, double?> calculatePriceChangesBatch(
    Map<String, List<DailyPriceEntry>> priceHistories,
    Map<String, DailyPriceEntry> latestPrices,
  ) {
    final result = <String, double?>{};

    for (final symbol in latestPrices.keys) {
      final history = priceHistories[symbol];
      final latestPrice = latestPrices[symbol];

      if (history == null || history.isEmpty) {
        result[symbol] = null;
        continue;
      }

      result[symbol] = calculatePriceChange(history, latestPrice);
    }

    return result;
  }
}
