part of 'package:afterclose/data/database/app_database.dart';

/// Dividend history (股利歷史) operations.
mixin _DividendDaoMixin on _$AppDatabase {
  /// 取得股票的股利歷史（依年度降冪排序）
  Future<List<DividendHistoryEntry>> getDividendHistory(String symbol) {
    return (select(dividendHistory)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.year)]))
        .get();
  }

  /// 批次新增股利資料
  Future<void> insertDividendData(
    List<DividendHistoryCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dividendHistory, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票最新的股利年度（新鮮度檢查用）
  Future<int?> getLatestDividendYear(String symbol) async {
    final result =
        await (select(dividendHistory)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.year)])
              ..limit(1))
            .getSingleOrNull();
    return result?.year;
  }
}
