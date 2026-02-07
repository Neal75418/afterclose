part of 'package:afterclose/data/database/app_database.dart';

/// Holding distribution (股權分散) operations.
mixin _HoldingDistributionDaoMixin on _$AppDatabase {
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

  /// 批次取得多檔股票的最新股權分散資料
  ///
  /// TDCC 資料共用同一週日期，以全域最新日期查詢。
  Future<Map<String, List<HoldingDistributionEntry>>>
  getLatestHoldingDistributionBatch(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    // 取得全域最新日期（TDCC 每週統一更新）
    final dateResult = await customSelect(
      'SELECT MAX(date) as max_date FROM holding_distribution',
      readsFrom: {holdingDistribution},
    ).getSingleOrNull();
    final maxDate = dateResult?.read<DateTime?>('max_date');
    if (maxDate == null) return {};

    final results =
        await (select(holdingDistribution)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(maxDate)))
            .get();

    final map = <String, List<HoldingDistributionEntry>>{};
    for (final entry in results) {
      map.putIfAbsent(entry.symbol, () => []).add(entry);
    }
    return map;
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
