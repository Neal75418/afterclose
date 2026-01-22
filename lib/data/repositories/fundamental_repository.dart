import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for fundamental data (營收, PE, PBR, 殖利率)
class FundamentalRepository {
  FundamentalRepository({
    required AppDatabase db,
    required FinMindClient finMind,
  }) : _db = db,
       _finMind = finMind;

  final AppDatabase _db;
  final FinMindClient _finMind;

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
  return FundamentalRepository(db: db, finMind: finMind);
});
