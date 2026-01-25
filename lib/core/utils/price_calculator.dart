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

  /// 標準化日期為本地時間午夜以確保比較一致性
  ///
  /// 使用本地時間以匹配資料庫中儲存的日期格式
  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

  /// 從價格歷史中提取最近 N 筆收盤價供 Sparkline 使用
  ///
  /// [priceHistory] 價格歷史（需按日期升序排列）
  /// [count] 要提取的資料筆數（預設 20）
  ///
  /// 回傳最近 N 筆的收盤價列表（過濾掉 null 值）
  static List<double> extractSparklinePrices(
    List<DailyPriceEntry> priceHistory, {
    int count = 20,
  }) {
    if (priceHistory.isEmpty) return [];

    final startIdx = priceHistory.length > count
        ? priceHistory.length - count
        : 0;
    return priceHistory
        .sublist(startIdx)
        .map((p) => p.close)
        .whereType<double>()
        .toList();
  }

  // ==========================================
  // 成交量計算
  // ==========================================

  /// 計算 N 日平均成交量
  ///
  /// [prices] 價格資料（需按日期升序排列）
  /// [days] 計算的天數（預設 5）
  /// [skipLast] 是否跳過最後一筆（今日），預設 false
  /// [filterZero] 是否過濾停牌日（成交量為 0），預設 false
  ///
  /// 回傳平均成交量，資料不足時回傳 null
  static double? calculateAverageVolume(
    List<DailyPriceEntry> prices, {
    int days = 5,
    bool skipLast = false,
    bool filterZero = false,
  }) {
    if (prices.isEmpty) return null;

    // 從後往前取資料
    var source = prices.reversed;
    if (skipLast) {
      source = source.skip(1);
    }

    final volumes = source
        .take(days)
        .map((p) => p.volume ?? 0.0)
        .where((v) => !filterZero || v > 0)
        .toList();

    if (volumes.isEmpty) return null;

    return volumes.reduce((a, b) => a + b) / volumes.length;
  }

  /// 檢查今日成交量是否超過平均量的倍數
  ///
  /// [prices] 價格資料（需按日期升序排列）
  /// [multiplier] 倍數門檻（預設 1.5）
  /// [days] 計算平均的天數（預設 5）
  ///
  /// 回傳 true 表示今日成交量超過平均量的指定倍數
  static bool isVolumeAboveAverage(
    List<DailyPriceEntry> prices, {
    double multiplier = 1.5,
    int days = 5,
  }) {
    if (prices.isEmpty) return false;

    final todayVolume = prices.last.volume;
    if (todayVolume == null || todayVolume <= 0) return false;

    final avgVolume = calculateAverageVolume(
      prices,
      days: days,
      skipLast: true,
    );

    if (avgVolume == null || avgVolume <= 0) return false;

    return todayVolume >= avgVolume * multiplier;
  }
}
