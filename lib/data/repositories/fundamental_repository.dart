import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for fundamental data (營收, PE, PBR, 殖利率)
class FundamentalRepository {
  FundamentalRepository({
    required AppDatabase db,
    required FinMindClient finMind,
    TwseClient? twse,
  }) : _db = db,
       _finMind = finMind,
       _twse = twse ?? TwseClient();

  final AppDatabase _db;
  final FinMindClient _finMind;
  final TwseClient _twse;

  /// Sync monthly revenue data for a stock
  ///
  /// Returns the number of records synced
  Future<int> syncMonthlyRevenue({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _finMind.getMonthlyRevenue(
        stockId: symbol,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
      );

      if (data.isEmpty) return 0;

      // Calculate growth rates
      final withGrowth = FinMindRevenue.calculateGrowthRates(data);

      // Convert to database entries
      final entries = withGrowth.map((r) {
        // Use first day of the month as date
        final date = DateTime(r.revenueYear, r.revenueMonth);
        return MonthlyRevenueCompanion.insert(
          symbol: symbol,
          date: date,
          revenueYear: r.revenueYear,
          revenueMonth: r.revenueMonth,
          revenue: r.revenue,
          momGrowth: Value(r.momGrowth),
          yoyGrowth: Value(r.yoyGrowth),
        );
      }).toList();

      await _db.insertMonthlyRevenue(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning(
        'FundamentalRepository',
        'Failed to sync monthly revenue for $symbol',
        e,
      );
      return 0;
    }
  }

  /// Sync PE/PBR/DividendYield data for a stock
  ///
  /// Returns the number of records synced
  Future<int> syncValuationData({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _finMind.getPERData(
        stockId: symbol,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
      );

      if (data.isEmpty) return 0;

      // Convert to database entries
      final entries = data.map((r) {
        // Parse date string to DateTime
        final parsedDate = DateTime.tryParse(r.date) ?? DateTime.now();
        return StockValuationCompanion.insert(
          symbol: symbol,
          date: parsedDate,
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList();

      await _db.insertValuationData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning(
        'FundamentalRepository',
        'Failed to sync valuation data for $symbol',
        e,
      );
      return 0;
    }
  }

  /// Sync valuation data for ALL stocks using TWSE BWIBBU_d (Free, Unlimited)
  ///
  /// Replaces individual FinMind calls for daily updates.
  Future<int> syncAllMarketValuation(
    DateTime date, {
    bool force = false,
  }) async {
    try {
      if (!force) {
        final existingCount = await _db.getValuationCountForDate(date);
        if (existingCount > 1000) return existingCount;
      }
      final data = await _twse.getAllStockValuation(date: date);

      if (data.isEmpty) return 0;

      // Convert to database entries
      // Filter out invalid data (PE usually > 0, Yield >= 0)
      final entries = data.map((r) {
        return StockValuationCompanion.insert(
          symbol: r.code,
          date: r.date,
          // TWSE PE is often '-' if negative earnings, returned as null by parser
          // FinMind returns 0 or null?
          // We store null if not available.
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList();

      await _db.insertValuationData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning(
        'FundamentalRepository',
        'Failed to sync all market valuation for $date',
        e,
      );
      return 0;
    }
  }

  /// Sync monthly revenue for ALL stocks using TWSE Open Data (Free, Unlimited)
  ///
  /// Replaces individual FinMind calls for recent monthly updates.
  /// Hits https://openapi.twse.com.tw/v1/opendata/t187ap05_L
  ///
  /// Returns: Number of records synced, or -1 if skipped (already have data)
  Future<int> syncAllMarketRevenue(DateTime date, {bool force = false}) async {
    try {
      // NOTE: OpenData only returns the LATEST month.
      // We cannot specify a date. We just fetch what's available.

      final data = await _twse.getAllMonthlyRevenue();

      if (data.isEmpty) return 0;

      // VERSION CHECK: Check if we already have data for this month
      // This avoids redundant API calls and database writes
      final sample = data.first;
      final dataYear = sample.year;
      final dataMonth = sample.month;

      if (!force) {
        final existingCount = await _db.getRevenueCountForYearMonth(
          dataYear,
          dataMonth,
        );
        // If we already have >1000 records for this month, skip
        // (Full market usually has ~1800+ stocks)
        if (existingCount > 1000) {
          AppLogger.info(
            'FundamentalRepository',
            'Revenue data for $dataYear/$dataMonth already exists '
                '($existingCount records), skipping sync',
          );
          return -1; // Signal: skipped
        }
      }

      AppLogger.info(
        'FundamentalRepository',
        'Syncing revenue for $dataYear/$dataMonth (${data.length} stocks)',
      );

      final entries = data.map((r) {
        final recordDate = DateTime(r.year, r.month);
        return MonthlyRevenueCompanion.insert(
          symbol: r.code,
          date: recordDate,
          revenueYear: r.year,
          revenueMonth: r.month,
          revenue: r.revenue,
          momGrowth: Value(r.momGrowth),
          yoyGrowth: Value(r.yoyGrowth),
        );
      }).toList();

      await _db.insertMonthlyRevenue(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning(
        'FundamentalRepository',
        'Failed to sync all market revenue',
        e,
      );
      return 0;
    }
  }

  /// Sync all fundamental data for a stock
  Future<({int revenue, int valuation})> syncAll({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await Future.wait([
      syncMonthlyRevenue(
        symbol: symbol,
        startDate: startDate,
        endDate: endDate,
      ),
      syncValuationData(symbol: symbol, startDate: startDate, endDate: endDate),
    ]);

    return (revenue: results[0], valuation: results[1]);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Provider for FundamentalRepository
final fundamentalRepositoryProvider = Provider<FundamentalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final finMind = ref.watch(finMindClientProvider);
  // TwseClient usually doesn't need provider as it holds no state/auth,
  // but if we had one we could inject it. For now repo creates it or accepts null.
  return FundamentalRepository(db: db, finMind: finMind);
});
