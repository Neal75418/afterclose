import 'package:afterclose/data/database/app_database.dart';

/// Interface for price data repository
///
/// Enables mocking in tests and allows for different implementations
/// (e.g., local database, remote API, in-memory cache).
abstract class IPriceRepository {
  // ==========================================
  // Price Data Queries
  // ==========================================

  /// Get price history for analysis
  ///
  /// Returns at least [RuleParams.lookbackPrice] days if available
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    int? days,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get latest price for a stock
  Future<DailyPriceEntry?> getLatestPrice(String symbol);

  /// Get price change percentage
  Future<double?> getPriceChange(String symbol);

  /// Get 20-day volume moving average
  Future<double?> getVolumeMA20(String symbol);

  /// Get price changes for multiple symbols in one query
  Future<Map<String, double>> getPriceChangesBatch(List<String> symbols);

  /// Get 20-day volume moving averages for multiple symbols in one query
  Future<Map<String, double>> getVolumeMA20Batch(List<String> symbols);

  // ==========================================
  // Sync Operations
  // ==========================================

  /// Sync prices for a single stock using TWSE historical API
  Future<int> syncStockPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// Sync today's prices for all stocks (batch mode)
  Future<MarketSyncResult> syncTodayPrices({DateTime? date});

  /// Sync all prices for the latest trading day and return quick-filter candidates
  Future<MarketSyncResult> syncAllPricesForDate(
    DateTime date, {
    List<String>? fallbackSymbols,
  });

  /// Sync prices for multiple specific symbols
  Future<int> syncPricesForSymbols(
    List<String> symbols, {
    required DateTime targetDate,
    void Function(int current, int total, String symbol)? onProgress,
  });

  /// Get symbols that need price updates for a given date
  Future<List<String>> getSymbolsNeedingUpdate(
    List<String> symbols,
    DateTime targetDate,
  );
}

/// Result of syncing all market prices
class MarketSyncResult {
  const MarketSyncResult({required this.count, required this.candidates});

  final int count;
  final List<String> candidates;
}
