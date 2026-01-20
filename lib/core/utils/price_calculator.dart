import 'package:afterclose/data/database/app_database.dart';

/// Utility for price-related calculations
class PriceCalculator {
  PriceCalculator._();

  /// Calculate price change percentage from price history
  ///
  /// Returns null if:
  /// - latestClose is null
  /// - history has less than 2 entries
  /// - previous close is null or zero
  static double? calculatePriceChange(
    List<DailyPriceEntry> history,
    double? latestClose,
  ) {
    if (latestClose == null || history.length < 2) return null;

    final prevClose = history[history.length - 2].close;
    if (prevClose == null || prevClose == 0) return null;

    return ((latestClose - prevClose) / prevClose) * 100;
  }

  /// Calculate price change from two prices directly
  static double? calculatePriceChangeFromPrices(
    double? currentPrice,
    double? previousPrice,
  ) {
    if (currentPrice == null || previousPrice == null || previousPrice == 0) {
      return null;
    }
    return ((currentPrice - previousPrice) / previousPrice) * 100;
  }

  /// Calculate price change for multiple stocks (batch)
  ///
  /// Takes a map of symbol -> price history and latest prices,
  /// returns a map of symbol -> price change percentage
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

      result[symbol] = calculatePriceChange(history, latestPrice?.close);
    }

    return result;
  }
}
