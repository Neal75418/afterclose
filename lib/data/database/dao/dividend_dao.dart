import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';

/// 股利歷史操作
mixin DividendDaoMixin on $AppDatabase {
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

  /// 批次取得多檔股票的股利歷史
  Future<Map<String, List<DividendHistoryEntry>>> getDividendHistoryBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final result =
        await (select(dividendHistory)
              ..where((t) => t.symbol.isIn(symbols))
              ..orderBy([(t) => OrderingTerm.desc(t.year)]))
            .get();

    final map = <String, List<DividendHistoryEntry>>{};
    for (final entry in result) {
      map.putIfAbsent(entry.symbol, () => []).add(entry);
    }
    return map;
  }
}
