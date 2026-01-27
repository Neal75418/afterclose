import 'dart:math' as math;

import 'package:afterclose/data/database/app_database.dart';

/// 測試資料生成工具
///
/// 提供共用的價格資料產生器，減少測試程式碼重複，確保測試資料一致性。

// ==========================================
// 基礎價格生成
// ==========================================

/// 建立單一 DailyPriceEntry，未指定欄位使用預設值。
DailyPriceEntry createTestPrice({
  String symbol = 'TEST',
  required DateTime date,
  double? open,
  double? high,
  double? low,
  double? close,
  double? volume,
}) {
  return DailyPriceEntry(
    symbol: symbol,
    date: date,
    open: open,
    high: high ?? (close != null ? close * 1.02 : null),
    low: low ?? (close != null ? close * 0.98 : null),
    close: close,
    volume: volume,
  );
}

/// 生成基礎價格附近小幅震盪的價格資料。
List<DailyPriceEntry> generateFlatPrices({
  required int days,
  required double basePrice,
  double volume = 1000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    // 基礎價格附近的小幅變動
    final variation = (i % 3 - 1) * 0.1; // -0.1, 0, or +0.1
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: basePrice + variation,
      volume: volume,
    );
  });
}

/// 生成固定價格資料（無波動）。
List<DailyPriceEntry> generateConstantPrices({
  required int days,
  required double basePrice,
  double volume = 1000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: basePrice,
      high: basePrice * 1.01,
      low: basePrice * 0.99,
      close: basePrice,
      volume: volume,
    );
  });
}

/// 根據指定價格清單生成價格資料。
///
/// 用於需要精確控制每天收盤價的測試案例。
List<DailyPriceEntry> generatePriceHistoryFromList({
  required List<double> prices,
  String symbol = 'TEST',
  DateTime? startDate,
}) {
  final days = prices.length;
  final start = startDate ?? DateTime.now().subtract(Duration(days: days - 1));
  return List.generate(days, (i) {
    return createTestPrice(
      symbol: symbol,
      date: start.add(Duration(days: i)),
      close: prices[i],
    );
  });
}

// ==========================================
// 趨勢型態生成
// ==========================================

/// 生成上升趨勢價格資料。
List<DailyPriceEntry> generateUptrendPrices({
  required int days,
  double startPrice = 100.0,
  double dailyGain = 0.5,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final price = startPrice + (i * dailyGain);
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: price,
    );
  });
}

/// 生成下降趨勢價格資料。
List<DailyPriceEntry> generateDowntrendPrices({
  required int days,
  double startPrice = 120.0,
  double dailyLoss = 0.5,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final price = startPrice - (i * dailyLoss);
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: price + 0.5,
      high: price + 1.0,
      low: price - 1.0,
      close: price,
      volume: 1000,
    );
  });
}

/// 生成波動價格（正弦波型態），用於支撐/壓力測試。
List<DailyPriceEntry> generateSwingPrices({
  required int days,
  double basePrice = 100.0,
  double amplitude = 10.0,
  int periodDays = 20,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final phase = (i % periodDays) / periodDays * 2 * math.pi;
    final price = basePrice + amplitude * math.sin(phase);

    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: price - 0.5,
      high: price + 3.0,
      low: price - 3.0,
      close: price,
      volume: 1000,
    );
  });
}

// ==========================================
// 反轉型態生成
// ==========================================

/// 生成更高低點型態，用於弱轉強反轉測試。
///
/// 型態說明：
/// - 第 0-24 天：建立下降趨勢，低點約 80
/// - 第 25-44 天：更深跌勢，低點達 65（最低點）
/// - 第 45-64 天：恢復階段，低點維持約 72（高於 65）
///
/// 規則引擎比較：
/// - 近期窗口（最後 20 天）：第 45-64 天最低點 ≈ 72
/// - 前期窗口（第 25-44 天）：最低點 ≈ 65
/// 結果：72 > 65 → 偵測到更高低點
List<DailyPriceEntry> generateHigherLowPattern({
  required int days,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();

  return List.generate(days, (i) {
    double price;
    double low;

    if (i < 25) {
      // 階段一：初始下降趨勢，低點約 80
      price = 100.0 - (i * 0.6); // 100 → 85
      low = price - 5.0; // lows: 95 → 80
    } else if (i < 45) {
      // 階段二：深跌，低點達 65（最低）
      price = 85.0 - ((i - 25) * 0.5); // 85 → 75
      low = price - 10.0; // lows: 75 → 65
    } else {
      // 階段三：恢復期，價格平穩但低點更高
      price = 75.0 - ((i - 45) * 0.1); // 75 → 73
      low = price - 3.0; // lows: 72 → 70 (all higher than 65)
    }

    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: price + 0.5,
      high: price + 1.0,
      low: low,
      close: price,
      volume: 1000,
    );
  });
}

// ==========================================
// 異常型態生成
// ==========================================

/// 生成最後一天成交量爆增的價格資料。
/// 最後一天同時有 3% 價格變動（滿足 minPriceChangeForVolume 門檻）。
List<DailyPriceEntry> generatePricesWithVolumeSpike({
  required int days,
  required double normalVolume,
  required double spikeVolume,
  double basePrice = 100.0,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    // 最後一天：開盤於基準價，收盤高 3% 以滿足 minPriceChangeForVolume (1.5%)
    final open = isToday ? basePrice : basePrice;
    final close = isToday ? basePrice * 1.03 : basePrice; // +3% on spike day
    return DailyPriceEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: open,
      high: close * 1.01,
      low: open * 0.99,
      close: close,
      volume: isToday ? spikeVolume : normalVolume,
    );
  });
}

/// 生成最後一天價格爆增的資料。
List<DailyPriceEntry> generatePricesWithPriceSpike({
  required int days,
  required double basePrice,
  required double changePercent,
  double volume = 1000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  final todayPrice = basePrice * (1 + changePercent / 100);

  return List.generate(days, (i) {
    final isToday = i == days - 1;
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: isToday ? todayPrice : basePrice,
      volume: volume,
    );
  });
}

/// 生成突破型態價格資料（滿足 MA20 和成交量確認條件）。
///
/// 用於測試 BreakoutRule：
/// - 前 N-1 天在 basePrice 附近盤整（建立 MA20）
/// - 最後一天突破至 breakoutPrice
/// - 最後一天成交量為 breakoutVolume（需 >= 2x 均量）
List<DailyPriceEntry> generatePricesWithBreakout({
  required int days,
  required double basePrice,
  required double breakoutPrice,
  required double normalVolume,
  required double breakoutVolume,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    final close = isToday ? breakoutPrice : basePrice;
    return DailyPriceEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: isToday ? basePrice : basePrice,
      high: close * 1.01,
      low: (isToday ? basePrice : close) * 0.99,
      close: close,
      volume: isToday ? breakoutVolume : normalVolume,
    );
  });
}

/// 生成跌破型態價格資料（滿足 MA20 和成交量確認條件）。
///
/// 用於測試 BreakdownRule：
/// - 前 N-1 天在 basePrice 附近盤整（建立 MA20）
/// - 最後一天跌破至 breakdownPrice
/// - 最後一天成交量為 breakdownVolume（需 >= 2x 均量）
List<DailyPriceEntry> generatePricesWithBreakdown({
  required int days,
  required double basePrice,
  required double breakdownPrice,
  required double normalVolume,
  required double breakdownVolume,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    final close = isToday ? breakdownPrice : basePrice;
    return DailyPriceEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      open: isToday ? basePrice : basePrice,
      high: (isToday ? basePrice : close) * 1.01,
      low: close * 0.99,
      close: close,
      volume: isToday ? breakdownVolume : normalVolume,
    );
  });
}

// ==========================================
// 法人資料生成
// ==========================================

/// 生成法人賣買轉向測試用資料。
List<DailyInstitutionalEntry> generateInstitutionalHistory({
  required int days,
  required double prevDirection,
  required double todayDirection,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      foreignNet: isToday ? todayDirection : prevDirection / 3,
      investmentTrustNet: 0,
      dealerNet: 0,
    );
  });
}

// ==========================================
// 新聞資料生成
// ==========================================

/// 建立測試用新聞項目。
NewsItemEntry createTestNewsItem({
  required String id,
  String title = 'Test News',
  String source = 'TestSource',
  String category = 'OTHER',
  String url = 'https://example.com/news',
  DateTime? publishedAt,
  DateTime? fetchedAt,
}) {
  final now = DateTime.now();
  return NewsItemEntry(
    id: id,
    url: url,
    title: title,
    source: source,
    category: category,
    publishedAt: publishedAt ?? now,
    fetchedAt: fetchedAt ?? now,
  );
}
