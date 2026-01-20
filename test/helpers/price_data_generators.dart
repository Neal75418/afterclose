import 'dart:math' as math;

import 'package:afterclose/data/database/app_database.dart';

/// Shared test helpers for generating price data across multiple test files.
/// This reduces code duplication and ensures consistent test data generation.

// ==========================================
// Basic Price Generation
// ==========================================

/// Creates a single DailyPriceEntry with defaults for missing fields.
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

/// Generates flat prices with small variation around basePrice.
List<DailyPriceEntry> generateFlatPrices({
  required int days,
  required double basePrice,
  double volume = 1000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    // Small random-like variation around base price
    final variation = (i % 3 - 1) * 0.1; // -0.1, 0, or +0.1
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: basePrice + variation,
      volume: volume,
    );
  });
}

/// Generates prices at a constant level (no variation).
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

// ==========================================
// Trend Pattern Generation
// ==========================================

/// Generates prices in an uptrend pattern.
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

/// Generates prices in a downtrend pattern.
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

/// Generates swing prices (sine wave pattern) for support/resistance testing.
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
// Reversal Pattern Generation
// ==========================================

/// Generates a higher low pattern for W2S reversal testing.
///
/// Pattern explanation:
/// - Days 0-24: Establish downtrend with lows around 80
/// - Days 25-44: Deeper decline, lows reach 65 (the lowest point)
/// - Days 45-64: Recovery phase, lows stay around 72 (higher than 65)
///
/// The rule engine compares:
/// - Recent window (last 20 days): min low from days 45-64 ≈ 72
/// - Previous window (days 25-44): min low ≈ 65
/// Result: 72 > 65 → higher low detected
List<DailyPriceEntry> generateHigherLowPattern({
  required int days,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();

  return List.generate(days, (i) {
    double price;
    double low;

    if (i < 25) {
      // Phase 1: Initial downtrend, lows around 80
      price = 100.0 - (i * 0.6); // 100 → 85
      low = price - 5.0; // lows: 95 → 80
    } else if (i < 45) {
      // Phase 2: Deep decline, lows reach 65 (minimum)
      price = 85.0 - ((i - 25) * 0.5); // 85 → 75
      low = price - 10.0; // lows: 75 → 65
    } else {
      // Phase 3: Recovery, prices flat but lows are higher
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
// Spike Pattern Generation
// ==========================================

/// Generates prices with a volume spike on the last day.
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
    return createTestPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: basePrice,
      volume: isToday ? spikeVolume : normalVolume,
    );
  });
}

/// Generates prices with a price spike on the last day.
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

// ==========================================
// Institutional Data Generation
// ==========================================

/// Generates institutional data for direction reversal testing.
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
// News Data Generation
// ==========================================

/// Creates a news item for testing.
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
