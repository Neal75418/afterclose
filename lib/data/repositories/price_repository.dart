import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';

/// Repository for daily price data
///
/// Uses TWSE Open Data as primary source (free, unlimited, all market)
/// Falls back to FinMind for historical data
class PriceRepository implements IPriceRepository {
  PriceRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final TwseClient _twseClient;

  // Note: FinMindClient kept in constructor for backward compatibility
  // but no longer used - TWSE is now the primary data source

  /// Get price history for analysis
  ///
  /// Returns at least [RuleParams.lookbackPrice] days if available
  @override
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    int? days,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final effectiveStartDate =
        startDate ??
        DateTime.now().subtract(
          Duration(days: (days ?? RuleParams.lookbackPrice) + 30),
        );

    return _db.getPriceHistory(
      symbol,
      startDate: effectiveStartDate,
      endDate: endDate,
    );
  }

  /// Get latest price for a stock
  @override
  Future<DailyPriceEntry?> getLatestPrice(String symbol) {
    return _db.getLatestPrice(symbol);
  }

  /// Sync prices for a single stock using TWSE historical API
  ///
  /// Uses TWSE for historical data (free, official source)
  /// OPTIMIZED: Only fetches months that are missing from the database
  @override
  Future<int> syncStockPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final effectiveEndDate = endDate ?? DateTime.now();

      // OPTIMIZATION: Check what data we already have
      final existingHistory = await _db.getPriceHistory(
        symbol,
        startDate: startDate,
        endDate: effectiveEndDate,
      );

      // Calculate which months to fetch (only those with insufficient data)
      final monthsToFetch = <DateTime>[];
      var current = DateTime(startDate.year, startDate.month, 1);
      final end = DateTime(effectiveEndDate.year, effectiveEndDate.month, 1);

      while (!current.isAfter(end)) {
        // Only fetch if we don't have data for this month
        // (or have very little - less than 10 trading days)
        final existingDaysInMonth = existingHistory
            .where(
              (p) =>
                  p.date.year == current.year && p.date.month == current.month,
            )
            .length;
        if (existingDaysInMonth < 10) {
          monthsToFetch.add(current);
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      // If no months need fetching, we're done
      if (monthsToFetch.isEmpty) {
        AppLogger.debug(
          'PriceRepo',
          'syncStockPrices: $symbol already has complete data',
        );
        return 0;
      }

      AppLogger.debug(
        'PriceRepo',
        'syncStockPrices: $symbol needs ${monthsToFetch.length} months '
            '(existing: ${existingHistory.length} days)',
      );

      // Fetch only missing months
      final allPrices = <TwseDailyPrice>[];
      for (var i = 0; i < monthsToFetch.length; i++) {
        final month = monthsToFetch[i];
        try {
          final monthData = await _twseClient.getStockMonthlyPrices(
            code: symbol,
            year: month.year,
            month: month.month,
          );
          allPrices.addAll(monthData);
        } on RateLimitException {
          // Rate limit errors should bubble up for proper backoff handling
          rethrow;
        } catch (e) {
          // Log and continue with other months if one fails
          AppLogger.warning(
            'PriceRepo',
            'Failed to fetch $symbol for ${month.year}/${month.month}',
            e,
          );
        }

        // Rate limiting delay between months (reduced since parallel at stock level)
        if (i < monthsToFetch.length - 1) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      // Filter to requested date range
      final filteredPrices = allPrices.where(
        (p) => !p.date.isBefore(startDate) && !p.date.isAfter(effectiveEndDate),
      );

      final entries = filteredPrices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.code,
          date: price.date,
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      if (entries.isNotEmpty) {
        await _db.insertPrices(entries);
        AppLogger.debug(
          'PriceRepo',
          'syncStockPrices: $symbol inserted ${entries.length} prices '
              '(fetched ${allPrices.length} from API)',
        );
      } else {
        AppLogger.debug(
          'PriceRepo',
          'syncStockPrices: $symbol no prices to insert '
              '(fetched ${allPrices.length} from API)',
        );
      }

      return entries.length;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync prices for $symbol', e);
    }
  }

  /// Sync today's prices for all stocks (batch mode)
  ///
  /// Alias for [syncAllPricesForDate] with default date
  @override
  Future<MarketSyncResult> syncTodayPrices({DateTime? date}) {
    return syncAllPricesForDate(date ?? DateTime.now());
  }

  /// Sync all prices for the latest trading day and return quick-filter candidates
  ///
  /// Primary: TWSE Open Data (free, unlimited, all market)
  ///
  /// Also updates stock_master with stock names from TWSE data.
  ///
  /// Returns [MarketSyncResult] with count and quick-filter candidates.
  @override
  Future<MarketSyncResult> syncAllPricesForDate(
    DateTime date, {
    List<String>? fallbackSymbols,
  }) async {
    try {
      AppLogger.info('PriceRepo', 'syncAllPricesForDate: date=$date');

      // Use TWSE Open Data - free, unlimited, all market in one call!
      final prices = await _twseClient.getAllDailyPrices();

      AppLogger.info('PriceRepo', 'Got ${prices.length} prices from TWSE');

      if (prices.isEmpty) {
        // TWSE might not have data yet (before market close)
        // Or it's a non-trading day
        AppLogger.warning('PriceRepo', 'TWSE returned empty prices');
        return const MarketSyncResult(count: 0, candidates: []);
      }

      // Build price entries
      final priceEntries = prices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.code,
          date: price.date,
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      AppLogger.info('PriceRepo', 'Built ${priceEntries.length} price entries');

      // Build stock master entries from TWSE data (includes stock names!)
      // This ensures stock names are always available even without FinMind API
      final stockEntries = prices.where((p) => p.name.isNotEmpty).map((price) {
        return StockMasterCompanion.insert(
          symbol: price.code,
          name: price.name,
          market: 'TWSE', // TWSE Open Data is for listed stocks
          isActive: const Value(true),
        );
      }).toList();

      AppLogger.info('PriceRepo', 'Built ${stockEntries.length} stock entries');

      // Upsert both prices and stock master
      AppLogger.info('PriceRepo', 'Inserting to database...');
      await Future.wait([
        _db.insertPrices(priceEntries),
        if (stockEntries.isNotEmpty) _db.upsertStocks(stockEntries),
      ]);
      AppLogger.info('PriceRepo', 'Database insert complete');

      // Quick filter: find candidates based on today's data only
      final candidates = _quickFilterCandidates(prices);
      AppLogger.info(
        'PriceRepo',
        'Quick filtered ${candidates.length} candidates',
      );

      return MarketSyncResult(
        count: priceEntries.length,
        candidates: candidates,
      );
    } on NetworkException {
      rethrow;
    } catch (e, stack) {
      AppLogger.error('PriceRepo', 'Failed to sync prices', e, stack);
      throw DatabaseException('Failed to sync prices from TWSE', e);
    }
  }

  /// Quick filter candidates from today's market data
  ///
  /// Criteria (any one triggers):
  /// 1. Price change >= 2% (significant movement)
  /// 2. Near limit up (漲停) or limit down (跌停)
  /// 3. Price change >= 1.5% with high volume potential
  ///
  /// Returns up to ~100 symbols for further analysis
  List<String> _quickFilterCandidates(List<TwseDailyPrice> prices) {
    final candidates = <_QuickCandidate>[];

    for (final price in prices) {
      // Skip if missing critical data
      if (price.close == null || price.close! <= 0) continue;
      if (price.change == null) continue;

      // Skip ETFs, warrants, etc. (symbols not starting with digit or too short)
      if (price.code.length < 4) continue;
      if (!RegExp(r'^\d').hasMatch(price.code)) continue;

      // Calculate price change percentage
      final prevClose = price.close! - price.change!;
      if (prevClose <= 0) continue;

      final changePercent = (price.change! / prevClose).abs() * 100;

      // Criteria 1: Significant price movement (>= 2%)
      if (changePercent >= 2.0) {
        candidates.add(
          _QuickCandidate(
            symbol: price.code,
            score: changePercent * 10, // Higher change = higher priority
          ),
        );
        continue;
      }

      // Criteria 2: Near limit (接近漲跌停, ~9-10%)
      if (changePercent >= 9.0) {
        candidates.add(
          _QuickCandidate(
            symbol: price.code,
            score: 100.0, // High priority for limit moves
          ),
        );
        continue;
      }

      // Criteria 3: Moderate movement (1.5%+) - lower priority
      if (changePercent >= 1.5) {
        candidates.add(
          _QuickCandidate(symbol: price.code, score: changePercent * 5),
        );
      }
    }

    // Sort by score (highest first) and take top 100
    candidates.sort((a, b) => b.score.compareTo(a.score));

    return candidates.take(100).map((c) => c.symbol).toList();
  }

  /// Sync prices for a list of specific symbols (free account fallback)
  ///
  /// Fetches prices one-by-one with rate limiting awareness.
  /// Only fetches data that is missing from the database.
  ///
  /// [onProgress] - callback for progress updates (current, total, symbol)
  /// [delayBetweenRequests] - delay between API calls to avoid rate limits
  Future<int> _syncPricesForSymbols(
    List<String> symbols,
    DateTime date, {
    void Function(int current, int total, String symbol)? onProgress,
    Duration delayBetweenRequests = const Duration(milliseconds: 200),
  }) async {
    var totalSynced = 0;
    final errors = <String>[];

    // Historical data range for analysis (lookback + buffer)
    final historyStartDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 30),
    );

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      onProgress?.call(i + 1, symbols.length, symbol);

      try {
        // Check what data we already have
        final latestPrice = await _db.getLatestPrice(symbol);
        final latestDate = latestPrice?.date;

        // Skip if we already have today's data
        if (latestDate != null && _isSameDay(latestDate, date)) {
          continue;
        }

        // Determine what range to fetch
        DateTime fetchStartDate;
        if (latestDate == null) {
          // No data at all - fetch full history
          fetchStartDate = historyStartDate;
        } else if (latestDate.isBefore(historyStartDate)) {
          // Data is too old - fetch full history
          fetchStartDate = historyStartDate;
        } else {
          // Have some data - fetch from day after latest
          fetchStartDate = latestDate.add(const Duration(days: 1));
        }

        // Skip if fetch start is after target date
        if (fetchStartDate.isAfter(date)) {
          continue;
        }

        final count = await syncStockPrices(
          symbol,
          startDate: fetchStartDate,
          endDate: date,
        );
        totalSynced += count;

        // Rate limiting delay between requests
        if (i < symbols.length - 1 && delayBetweenRequests.inMilliseconds > 0) {
          await Future.delayed(delayBetweenRequests);
        }
      } on RateLimitException {
        // Stop immediately on rate limit
        rethrow;
      } catch (e) {
        // Log error but continue with other symbols
        errors.add('$symbol: $e');
      }
    }

    // If all symbols failed, throw an exception
    if (totalSynced == 0 && errors.isNotEmpty && symbols.isNotEmpty) {
      throw DatabaseException(
        'Failed to sync any prices. Errors: ${errors.take(3).join("; ")}',
      );
    }

    return totalSynced;
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Sync prices for multiple specific symbols (public API for update service)
  ///
  /// Use this when you have a specific list of stocks to update.
  /// Only fetches missing data - skips stocks that are already up to date.
  ///
  /// [onProgress] - callback for progress updates (current, total, symbol)
  @override
  Future<int> syncPricesForSymbols(
    List<String> symbols, {
    required DateTime targetDate,
    void Function(int current, int total, String symbol)? onProgress,
  }) async {
    return _syncPricesForSymbols(symbols, targetDate, onProgress: onProgress);
  }

  /// Get symbols that need price updates for a given date
  ///
  /// Returns symbols that don't have price data for the target date.
  /// Uses batch query to avoid N+1 performance issue.
  @override
  Future<List<String>> getSymbolsNeedingUpdate(
    List<String> symbols,
    DateTime targetDate,
  ) async {
    if (symbols.isEmpty) return [];

    // Batch query instead of N+1 individual queries
    final latestPrices = await _db.getLatestPricesBatch(symbols);

    return symbols.where((symbol) {
      final latestPrice = latestPrices[symbol];
      return latestPrice == null || !_isSameDay(latestPrice.date, targetDate);
    }).toList();
  }

  /// Get price change percentage
  @override
  Future<double?> getPriceChange(String symbol) async {
    final history = await getPriceHistory(symbol, days: 2);
    if (history.length < 2) return null;

    final today = history.last;
    final yesterday = history[history.length - 2];

    if (today.close == null || yesterday.close == null) return null;
    if (yesterday.close == 0) return null;

    final change = ((today.close! - yesterday.close!) / yesterday.close!) * 100;
    // Guard against NaN/Infinity from very small denominators
    return change.isFinite ? change : null;
  }

  /// Get 20-day volume moving average
  @override
  Future<double?> getVolumeMA20(String symbol) async {
    final history = await getPriceHistory(symbol, days: RuleParams.volMa + 5);
    if (history.length < RuleParams.volMa) return null;

    final recent = history.reversed.take(RuleParams.volMa).toList();
    final validVolumes = recent
        .where((p) => p.volume != null)
        .map((p) => p.volume!);

    if (validVolumes.isEmpty) return null;

    return validVolumes.reduce((a, b) => a + b) / validVolumes.length;
  }

  // ==================================================
  // Batch Methods (N+1 optimization)
  // ==================================================

  /// Get price changes for multiple symbols in one query
  ///
  /// Returns a map of symbol -> price change percentage
  /// More efficient than calling [getPriceChange] in a loop
  ///
  /// Throws [DatabaseException] if database query fails
  @override
  Future<Map<String, double?>> getPriceChangesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 5));

      // Single batch query for all symbols (includes latest price)
      final priceHistories = await _db.getPriceHistoryBatch(
        symbols,
        startDate: startDate,
        endDate: today,
      );

      final result = <String, double?>{};

      for (final symbol in symbols) {
        final history = priceHistories[symbol];

        if (history == null || history.length < 2) {
          result[symbol] = null;
          continue;
        }

        // Use the last two entries from history directly
        final todayClose = history.last.close;
        final prevClose = history[history.length - 2].close;

        if (todayClose == null || prevClose == null || prevClose == 0) {
          result[symbol] = null;
          continue;
        }

        final change = ((todayClose - prevClose) / prevClose) * 100;
        // Guard against NaN/Infinity from very small denominators
        result[symbol] = change.isFinite ? change : null;
      }

      return result;
    } catch (e) {
      throw DatabaseException('Failed to fetch price changes batch', e);
    }
  }

  /// Get 20-day volume moving averages for multiple symbols in one query
  ///
  /// Returns a map of symbol -> volume MA
  /// More efficient than calling [getVolumeMA20] in a loop
  ///
  /// Throws [DatabaseException] if database query fails
  @override
  Future<Map<String, double?>> getVolumeMA20Batch(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    try {
      final today = DateTime.now();
      final startDate = today.subtract(
        const Duration(days: RuleParams.volMa + 10),
      );

      // Single batch query for all symbols
      final priceHistories = await _db.getPriceHistoryBatch(
        symbols,
        startDate: startDate,
        endDate: today,
      );

      final result = <String, double?>{};

      for (final symbol in symbols) {
        final history = priceHistories[symbol];

        if (history == null || history.length < RuleParams.volMa) {
          result[symbol] = null;
          continue;
        }

        final recent = history.reversed.take(RuleParams.volMa).toList();
        final validVolumes = recent
            .where((p) => p.volume != null)
            .map((p) => p.volume!)
            .toList();

        if (validVolumes.isEmpty) {
          result[symbol] = null;
          continue;
        }

        result[symbol] =
            validVolumes.reduce((a, b) => a + b) / validVolumes.length;
      }

      return result;
    } catch (e) {
      throw DatabaseException('Failed to fetch volume MA batch', e);
    }
  }
}

/// Helper class for quick candidate filtering
class _QuickCandidate {
  const _QuickCandidate({required this.symbol, required this.score});

  final String symbol;
  final double score;
}
