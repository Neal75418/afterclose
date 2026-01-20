import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';
import 'package:afterclose/data/database/tables/daily_price.dart';
import 'package:afterclose/data/database/tables/daily_institutional.dart';
import 'package:afterclose/data/database/tables/news_tables.dart';
import 'package:afterclose/data/database/tables/analysis_tables.dart';
import 'package:afterclose/data/database/tables/user_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Master data
    StockMaster,
    // Daily market data
    DailyPrice,
    DailyInstitutional,
    // News
    NewsItem,
    NewsStockMap,
    // Analysis results
    DailyAnalysis,
    DailyReason,
    DailyRecommendation,
    // User data
    Watchlist,
    UserNote,
    StrategyCard,
    UpdateRun,
    AppSettings,
    PriceAlert,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing - creates an in-memory database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2: Add PriceAlert table
      if (from < 2) {
        await m.createTable(priceAlert);
      }
    },
  );

  // ==========================================
  // Stock Master Operations
  // ==========================================

  /// Get all active stocks
  Future<List<StockMasterEntry>> getAllActiveStocks() {
    return (select(stockMaster)..where((t) => t.isActive.equals(true))).get();
  }

  /// Get stock by symbol
  Future<StockMasterEntry?> getStock(String symbol) {
    return (select(
      stockMaster,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  /// Upsert stock master data
  Future<void> upsertStock(StockMasterCompanion entry) {
    return into(stockMaster).insertOnConflictUpdate(entry);
  }

  /// Batch upsert stocks
  Future<void> upsertStocks(List<StockMasterCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(stockMaster, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  /// Search stocks by symbol or name (DB-level filtering)
  Future<List<StockMasterEntry>> searchStocks(String query) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(stockMaster)
          ..where((t) => t.isActive.equals(true))
          ..where(
            (t) =>
                t.symbol.lower().like(lowerQuery) |
                t.name.lower().like(lowerQuery),
          ))
        .get();
  }

  /// Get stocks by market (DB-level filtering)
  Future<List<StockMasterEntry>> getStocksByMarket(String market) {
    return (select(stockMaster)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.market.equals(market)))
        .get();
  }

  /// Get multiple stocks by symbols (batch query)
  ///
  /// Returns a map of symbol -> stock entry
  Future<Map<String, StockMasterEntry>> getStocksBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final results = await (select(
      stockMaster,
    )..where((t) => t.symbol.isIn(symbols))).get();

    return {for (final stock in results) stock.symbol: stock};
  }

  // ==========================================
  // Daily Price Operations
  // ==========================================

  /// Get price history for a stock
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(dailyPrice)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.get();
  }

  /// Get latest price for a stock
  Future<DailyPriceEntry?> getLatestPrice(String symbol) {
    return (select(dailyPrice)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get latest prices for multiple symbols (batch query)
  ///
  /// Returns a map of symbol -> latest price entry
  ///
  /// Uses optimized SQL with GROUP BY + MAX(date) subquery to avoid
  /// fetching all historical prices into memory.
  Future<Map<String, DailyPriceEntry>> getLatestPricesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // Build placeholders for SQL IN clause
    final placeholders = List.filled(symbols.length, '?').join(', ');

    // Use optimized query with subquery to get only latest price per symbol
    // This avoids fetching all historical prices (potentially millions of rows)
    final query =
        '''
      SELECT dp.*
      FROM daily_price dp
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM daily_price
        WHERE symbol IN ($placeholders)
        GROUP BY symbol
      ) latest ON dp.symbol = latest.symbol AND dp.date = latest.max_date
    ''';

    final results = await customSelect(
      query,
      variables: symbols.map((s) => Variable.withString(s)).toList(),
      readsFrom: {dailyPrice},
    ).get();

    // Convert query rows to DailyPriceEntry objects
    final result = <String, DailyPriceEntry>{};
    for (final row in results) {
      final entry = DailyPriceEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        open: row.readNullable<double>('open'),
        high: row.readNullable<double>('high'),
        low: row.readNullable<double>('low'),
        close: row.readNullable<double>('close'),
        volume: row.readNullable<double>('volume'),
      );
      result[entry.symbol] = entry;
    }

    return result;
  }

  /// Batch insert prices
  Future<void> insertPrices(List<DailyPriceCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyPrice, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Get price history for multiple symbols (batch query to avoid N+1)
  ///
  /// Returns a map of symbol -> price list, sorted by date ascending
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // Group by symbol
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// Get all prices within a date range (for market-wide analysis)
  ///
  /// Returns prices grouped by symbol
  Future<Map<String, List<DailyPriceEntry>>> getAllPricesInRange({
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final query = select(dailyPrice)
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // Group by symbol
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  // ==========================================
  // Daily Institutional Operations
  // ==========================================

  /// Get institutional data history for a stock
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(dailyInstitutional)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.get();
  }

  /// Get latest institutional data for a stock
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol) {
    return (select(dailyInstitutional)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Batch insert institutional data
  Future<void> insertInstitutionalData(
    List<DailyInstitutionalCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyInstitutional, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Get institutional data for multiple symbols (batch query)
  ///
  /// Returns a map of symbol -> institutional entry list, sorted by date ascending
  Future<Map<String, List<DailyInstitutionalEntry>>>
  getInstitutionalHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    final query = select(dailyInstitutional)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // Group by symbol
    final grouped = <String, List<DailyInstitutionalEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  // ==========================================
  // Daily Analysis Operations
  // ==========================================

  /// Get analysis for date
  Future<List<DailyAnalysisEntry>> getAnalysisForDate(DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.desc(t.score)]))
        .get();
  }

  /// Get analysis for stock
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
  }

  /// Insert analysis result
  Future<void> insertAnalysis(DailyAnalysisCompanion entry) {
    return into(dailyAnalysis).insertOnConflictUpdate(entry);
  }

  /// Get analyses for multiple symbols on a date (batch query)
  ///
  /// Returns a map of symbol -> analysis entry
  Future<Map<String, DailyAnalysisEntry>> getAnalysesBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyAnalysis)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date)))
            .get();

    return {for (final analysis in results) analysis.symbol: analysis};
  }

  // ==========================================
  // Daily Reason Operations
  // ==========================================

  /// Get reasons for stock on date
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return (select(dailyReason)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// Get reasons for multiple symbols on a date (batch query)
  ///
  /// Returns a map of symbol -> list of reasons, sorted by rank
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyReason)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date))
              ..orderBy([
                (t) => OrderingTerm.asc(t.symbol),
                (t) => OrderingTerm.asc(t.rank),
              ]))
            .get();

    // Group by symbol
    final grouped = <String, List<DailyReasonEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// Insert reasons
  Future<void> insertReasons(List<DailyReasonCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyReason, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Replace reasons for a stock on a date (atomic operation)
  Future<void> replaceReasons(
    String symbol,
    DateTime date,
    List<DailyReasonCompanion> entries,
  ) {
    return transaction(() async {
      // Delete existing reasons for this symbol/date
      await (delete(dailyReason)
            ..where((t) => t.symbol.equals(symbol))
            ..where((t) => t.date.equals(date)))
          .go();

      // Insert new reasons
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyReason, entry);
          }
        });
      }
    });
  }

  // ==========================================
  // Recommendation Operations
  // ==========================================

  /// Get today's recommendations
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date) {
    return (select(dailyRecommendation)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// Insert recommendations
  Future<void> insertRecommendations(
    List<DailyRecommendationCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyRecommendation, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Replace recommendations for a date (atomic operation)
  Future<void> replaceRecommendations(
    DateTime date,
    List<DailyRecommendationCompanion> entries,
  ) {
    return transaction(() async {
      // Delete existing recommendations for this date
      await (delete(
        dailyRecommendation,
      )..where((t) => t.date.equals(date))).go();

      // Insert new recommendations
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyRecommendation, entry);
          }
        });
      }
    });
  }

  /// Check if a symbol was recommended within a date range (single query)
  Future<bool> wasSymbolRecommendedInRange(
    String symbol, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result =
        await (select(dailyRecommendation)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// Get all symbols that were recommended within a date range (batch check)
  Future<Set<String>> getRecommendedSymbolsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results =
        await (select(dailyRecommendation)
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
            .get();
    return results.map((r) => r.symbol).toSet();
  }

  // ==========================================
  // News Operations
  // ==========================================

  /// Get news-to-stock mappings for multiple news IDs (batch query)
  ///
  /// Returns a map of newsId -> list of symbols
  Future<Map<String, List<String>>> getNewsStockMappingsBatch(
    List<String> newsIds,
  ) async {
    if (newsIds.isEmpty) return {};

    final results = await (select(
      newsStockMap,
    )..where((t) => t.newsId.isIn(newsIds))).get();

    // Group by newsId
    final grouped = <String, List<String>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.newsId, () => []).add(entry.symbol);
    }

    return grouped;
  }

  // ==========================================
  // Watchlist Operations
  // ==========================================

  /// Get all watchlist items
  Future<List<WatchlistEntry>> getWatchlist() {
    return (select(
      watchlist,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// Add to watchlist
  Future<void> addToWatchlist(String symbol) {
    return into(watchlist).insert(
      WatchlistCompanion.insert(symbol: symbol),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Remove from watchlist
  Future<void> removeFromWatchlist(String symbol) {
    return (delete(watchlist)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// Check if symbol is in watchlist
  Future<bool> isInWatchlist(String symbol) async {
    final result = await (select(
      watchlist,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
    return result != null;
  }

  // ==========================================
  // App Settings Operations (for token storage)
  // ==========================================

  /// Get setting value
  Future<String?> getSetting(String key) async {
    final result = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  /// Set setting value
  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Delete setting
  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  // ==========================================
  // Update Run Operations
  // ==========================================

  /// Create new update run
  Future<int> createUpdateRun(DateTime runDate, String status) {
    return into(
      updateRun,
    ).insert(UpdateRunCompanion.insert(runDate: runDate, status: status));
  }

  /// Update run status
  Future<void> finishUpdateRun(int id, String status, {String? message}) {
    return (update(updateRun)..where((t) => t.id.equals(id))).write(
      UpdateRunCompanion(
        finishedAt: Value(DateTime.now()),
        status: Value(status),
        message: Value(message),
      ),
    );
  }

  /// Get latest update run
  Future<UpdateRunEntry?> getLatestUpdateRun() {
    return (select(updateRun)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ==========================================
  // Price Alert Operations
  // ==========================================

  /// Get all active price alerts
  Future<List<PriceAlertEntry>> getActiveAlerts() {
    return (select(priceAlert)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get all price alerts (active and inactive)
  Future<List<PriceAlertEntry>> getAllAlerts() {
    return (select(
      priceAlert,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// Get all alerts for a symbol
  Future<List<PriceAlertEntry>> getAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get active alerts for a symbol
  Future<List<PriceAlertEntry>> getActiveAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Create a new price alert
  Future<int> createPriceAlert({
    required String symbol,
    required String alertType,
    required double targetValue,
    String? note,
  }) {
    return into(priceAlert).insert(
      PriceAlertCompanion.insert(
        symbol: symbol,
        alertType: alertType,
        targetValue: targetValue,
        note: Value(note),
      ),
    );
  }

  /// Update price alert
  Future<void> updatePriceAlert(int id, PriceAlertCompanion entry) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(entry);
  }

  /// Deactivate a price alert (mark as triggered)
  Future<void> triggerAlert(int id) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(
      PriceAlertCompanion(
        isActive: const Value(false),
        triggeredAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a price alert
  Future<void> deletePriceAlert(int id) {
    return (delete(priceAlert)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all alerts for a symbol
  Future<void> deleteAlertsForSymbol(String symbol) {
    return (delete(priceAlert)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// Check alerts against current prices and return triggered alerts
  Future<List<PriceAlertEntry>> checkAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    final activeAlerts = await getActiveAlerts();
    final triggered = <PriceAlertEntry>[];

    for (final alert in activeAlerts) {
      final currentPrice = currentPrices[alert.symbol];
      final priceChange = priceChanges[alert.symbol];

      if (currentPrice == null) continue;

      bool shouldTrigger = false;

      switch (alert.alertType) {
        case 'ABOVE':
          shouldTrigger = currentPrice >= alert.targetValue;
          break;
        case 'BELOW':
          shouldTrigger = currentPrice <= alert.targetValue;
          break;
        case 'CHANGE_PCT':
          if (priceChange != null) {
            shouldTrigger = priceChange.abs() >= alert.targetValue;
          }
          break;
      }

      if (shouldTrigger) {
        triggered.add(alert);
      }
    }

    return triggered;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'afterclose.db'));
    return NativeDatabase.createInBackground(file);
  });
}
