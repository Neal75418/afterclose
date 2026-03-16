import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';

/// Insider transfer (內部人股權轉讓) operations.
mixin InsiderTransferDaoMixin on $AppDatabase {
  /// 取得指定股票的近期轉讓申報記錄
  ///
  /// 預設取最近 20 筆，按申報日期降冪排列。
  Future<List<InsiderTransferEntry>> getRecentTransfers(
    String symbol, {
    int limit = 20,
  }) {
    return (select(insiderTransfer)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.reportDate)])
          ..limit(limit))
        .get();
  }

  /// 取得指定日期之後的轉讓申報記錄（全市場）
  Future<List<InsiderTransferEntry>> getTransfersSince(DateTime since) {
    return (select(insiderTransfer)
          ..where((t) => t.reportDate.isBiggerOrEqualValue(since))
          ..orderBy([(t) => OrderingTerm.desc(t.reportDate)]))
        .get();
  }

  /// 批次新增內部人轉讓記錄
  Future<void> insertInsiderTransfers(
    List<InsiderTransferCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(insiderTransfer, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }
}
