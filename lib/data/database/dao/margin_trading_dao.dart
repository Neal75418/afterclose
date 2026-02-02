import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Margin trading (融資融券) operations.
extension MarginTradingDao on AppDatabase {
  /// 取得股票的融資融券歷史
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(marginTrading)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新融資融券資料
  Future<MarginTradingEntry?> getLatestMarginTrading(String symbol) {
    return (select(marginTrading)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得指定日期的所有融資融券資料
  Future<List<MarginTradingEntry>> getMarginTradingForDate(DateTime date) {
    // 使用本地時間午夜以匹配資料庫儲存格式
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(marginTrading)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfDay))
          ..where((t) => t.date.isSmallerThanValue(endOfDay)))
        .get();
  }

  /// 取得指定日期的融資融券資料筆數（新鮮度檢查用）
  Future<int> getMarginTradingCountForDate(DateTime date) async {
    // 使用本地時間午夜以匹配資料庫儲存格式
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = marginTrading.symbol.count();
    final query = selectOnly(marginTrading)
      ..addColumns([countExpr])
      ..where(marginTrading.date.isBiggerOrEqualValue(startOfDay))
      ..where(marginTrading.date.isSmallerThanValue(endOfDay));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 批次新增融資融券資料
  Future<void> insertMarginTradingData(
    List<MarginTradingCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(marginTrading, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }
}
