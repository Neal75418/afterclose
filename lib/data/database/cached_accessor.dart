import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Cached accessor for batch database queries.
///
/// Wraps [AppDatabase] batch methods with 30-second TTL caching
/// to reduce redundant queries during update cycles.
///
/// Usage:
/// ```dart
/// final accessor = CachedDatabaseAccessor(db: _db, cache: _cache);
/// final prices = await accessor.getLatestPricesBatch(symbols);
/// ```
class CachedDatabaseAccessor {
  CachedDatabaseAccessor({
    required AppDatabase db,
    required BatchQueryCacheManager cache,
  })  : _db = db,
        _cache = cache;

  final AppDatabase _db;
  final BatchQueryCacheManager _cache;

  /// Get latest prices for multiple symbols with caching.
  Future<Map<String, DailyPriceEntry>> getLatestPricesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // Check cache first
    final cached = _cache.getLatestPrices<DailyPriceEntry>(symbols);
    if (cached != null) {
      return cached;
    }

    // Fetch from database
    final result = await _db.getLatestPricesBatch(symbols);

    // Cache the result
    _cache.cacheLatestPrices(symbols, result);

    return result;
  }

  /// Get price history for multiple symbols with caching.
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    // Check cache first
    final cached = _cache.getPriceHistory<DailyPriceEntry>(
      symbols,
      startDate,
      endDate,
    );
    if (cached != null) {
      return cached;
    }

    // Fetch from database
    final result = await _db.getPriceHistoryBatch(
      symbols,
      startDate: startDate,
      endDate: endDate,
    );

    // Cache the result
    _cache.cachePriceHistory(symbols, startDate, endDate, result);

    return result;
  }

  /// Get analyses for multiple symbols with caching.
  Future<Map<String, DailyAnalysisEntry>> getAnalysesBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    // Check cache first
    final cached = _cache.getAnalyses<DailyAnalysisEntry>(symbols, date);
    if (cached != null) {
      return cached;
    }

    // Fetch from database
    final result = await _db.getAnalysesBatch(symbols, date);

    // Cache the result
    _cache.cacheAnalyses(symbols, date, result);

    return result;
  }

  /// Get reasons for multiple symbols with caching.
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    // Check cache first
    final cached = _cache.getReasons<DailyReasonEntry>(symbols, date);
    if (cached != null) {
      return cached;
    }

    // Fetch from database
    final result = await _db.getReasonsBatch(symbols, date);

    // Cache the result
    _cache.cacheReasons(symbols, date, result);

    return result;
  }

  /// Get stocks batch (not cached - stock data rarely changes).
  Future<Map<String, StockMasterEntry>> getStocksBatch(
    List<String> symbols,
  ) {
    return _db.getStocksBatch(symbols);
  }

  /// Clear all cached data.
  ///
  /// Call this after data mutations (e.g., after update completes).
  void invalidateCache() {
    _cache.clearAll();
  }

  // ==================================================
  // Type-Safe Batch Loading (Dart 3 Records)
  // ==================================================

  /// Load all data for a stock list screen in a single type-safe call.
  ///
  /// Returns a Record with named fields for compile-time type safety,
  /// eliminating the need for manual casting from `results[0] as Map<...>`.
  ///
  /// Usage:
  /// ```dart
  /// final data = await _cachedDb.loadStockListData(
  ///   symbols: allSymbols,
  ///   analysisDate: dateCtx.today,
  ///   historyStart: dateCtx.historyStart,
  /// );
  /// // Type-safe access - no casting needed!
  /// final stockName = data.stocks[symbol]?.name;
  /// final latestPrice = data.latestPrices[symbol]?.close;
  /// ```
  Future<StockListBatchData> loadStockListData({
    required List<String> symbols,
    required DateTime analysisDate,
    required DateTime historyStart,
    DateTime? historyEnd,
  }) async {
    if (symbols.isEmpty) {
      return (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        analyses: <String, DailyAnalysisEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      );
    }

    final effectiveHistoryEnd = historyEnd ?? analysisDate;

    // Parallel fetch all data with caching
    final results = await Future.wait([
      getStocksBatch(symbols),
      getLatestPricesBatch(symbols),
      getAnalysesBatch(symbols, analysisDate),
      getReasonsBatch(symbols, analysisDate),
      getPriceHistoryBatch(
        symbols,
        startDate: historyStart,
        endDate: effectiveHistoryEnd,
      ),
    ]);

    // Return typed Record - no casting needed by caller!
    return (
      stocks: results[0] as Map<String, StockMasterEntry>,
      latestPrices: results[1] as Map<String, DailyPriceEntry>,
      analyses: results[2] as Map<String, DailyAnalysisEntry>,
      reasons: results[3] as Map<String, List<DailyReasonEntry>>,
      priceHistories: results[4] as Map<String, List<DailyPriceEntry>>,
    );
  }

  /// Load data for scan screen (no analyses in batch load, fetched separately).
  ///
  /// Scan screen gets analyses from getAnalysisForDate(), so this excludes it.
  Future<ScanBatchData> loadScanData({
    required List<String> symbols,
    required DateTime analysisDate,
    required DateTime historyStart,
    DateTime? historyEnd,
  }) async {
    if (symbols.isEmpty) {
      return (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      );
    }

    final effectiveHistoryEnd = historyEnd ?? analysisDate;

    final results = await Future.wait([
      getStocksBatch(symbols),
      getLatestPricesBatch(symbols),
      getReasonsBatch(symbols, analysisDate),
      getPriceHistoryBatch(
        symbols,
        startDate: historyStart,
        endDate: effectiveHistoryEnd,
      ),
    ]);

    return (
      stocks: results[0] as Map<String, StockMasterEntry>,
      latestPrices: results[1] as Map<String, DailyPriceEntry>,
      reasons: results[2] as Map<String, List<DailyReasonEntry>>,
      priceHistories: results[3] as Map<String, List<DailyPriceEntry>>,
    );
  }
}

/// Type-safe batch data for stock list screens (Today, Watchlist).
///
/// Uses Dart 3 Record syntax for compile-time type safety.
typedef StockListBatchData = ({
  Map<String, StockMasterEntry> stocks,
  Map<String, DailyPriceEntry> latestPrices,
  Map<String, DailyAnalysisEntry> analyses,
  Map<String, List<DailyReasonEntry>> reasons,
  Map<String, List<DailyPriceEntry>> priceHistories,
});

/// Type-safe batch data for scan screen.
typedef ScanBatchData = ({
  Map<String, StockMasterEntry> stocks,
  Map<String, DailyPriceEntry> latestPrices,
  Map<String, List<DailyReasonEntry>> reasons,
  Map<String, List<DailyPriceEntry>> priceHistories,
});
