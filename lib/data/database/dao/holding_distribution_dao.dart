import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Holding distribution (股權分散) operations.
extension HoldingDistributionDao on AppDatabase {
  /// 取得股票在指定日期的股權分散資料
  Future<List<HoldingDistributionEntry>> getHoldingDistribution(
    String symbol, {
    required DateTime date,
  }) {
    return (select(holdingDistribution)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date)))
        .get();
  }

  /// 取得股票的最新股權分散資料
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) async {
    // 先取得最新日期
    final latestDate = await customSelect(
      'SELECT MAX(date) as max_date FROM holding_distribution WHERE symbol = ?',
      variables: [Variable.withString(symbol)],
      readsFrom: {holdingDistribution},
    ).getSingleOrNull();

    if (latestDate == null) return [];
    final maxDate = latestDate.read<DateTime?>('max_date');
    if (maxDate == null) return [];

    return (select(holdingDistribution)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(maxDate)))
        .get();
  }

  /// 批次新增股權分散資料
  Future<void> insertHoldingDistribution(
    List<HoldingDistributionCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(holdingDistribution, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票的最新股權分散日期（新鮮度檢查用）
  Future<DateTime?> getLatestHoldingDistributionDate(String symbol) async {
    final result = await customSelect(
      'SELECT MAX(date) as max_date FROM holding_distribution WHERE symbol = ?',
      variables: [Variable.withString(symbol)],
      readsFrom: {holdingDistribution},
    ).getSingleOrNull();
    return result?.read<DateTime?>('max_date');
  }
}
