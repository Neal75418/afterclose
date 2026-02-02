import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Trading warning (注意股票/處置股票) operations.
extension TradingWarningDao on AppDatabase {
  /// 取得股票的警示歷史
  Future<List<TradingWarningEntry>> getWarningHistory(
    String symbol, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(tradingWarning)..where((t) => t.symbol.equals(symbol));

    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  /// 取得股票目前生效的警示
  Future<List<TradingWarningEntry>> getActiveWarnings(String symbol) {
    return (select(tradingWarning)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 取得所有目前生效的警示（全市場）
  Future<List<TradingWarningEntry>> getAllActiveWarnings() {
    return (select(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 依類型取得所有目前生效的警示
  Future<List<TradingWarningEntry>> getActiveWarningsByType(String type) {
    return (select(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.warningType.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 檢查股票是否有目前生效的警示
  Future<bool> hasActiveWarning(String symbol) async {
    final result =
        await (select(tradingWarning)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// 檢查股票是否為處置股
  Future<bool> isDisposalStock(String symbol) async {
    final result =
        await (select(tradingWarning)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.equals('DISPOSAL'))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// 批次檢查多檔股票是否為處置股（批次查詢）
  Future<Set<String>> getDisposalStocksBatch(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.equals('DISPOSAL')))
            .get();

    return results.map((r) => r.symbol).toSet();
  }

  /// 批次取得多檔股票的警示資料 Map
  ///
  /// 用於 Isolate 評分時傳遞警示資料。
  /// 優先回傳 DISPOSAL（處置股），若無則回傳 ATTENTION（注意股）。
  Future<Map<String, TradingWarningEntry>> getActiveWarningsMapBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..orderBy([
                // DISPOSAL 優先於 ATTENTION
                (t) => OrderingTerm.desc(t.warningType),
              ]))
            .get();

    final map = <String, TradingWarningEntry>{};
    for (final entry in results) {
      // 只保留第一筆（DISPOSAL 優先）
      if (!map.containsKey(entry.symbol)) {
        map[entry.symbol] = entry;
      }
    }
    return map;
  }

  /// 批次新增警示資料
  Future<void> insertWarningData(List<TradingWarningCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(tradingWarning, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 更新過期的警示狀態
  ///
  /// 將處置結束日已過的警示標記為非生效
  Future<int> updateExpiredWarnings() async {
    final now = DateTime.now();
    return (update(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.disposalEndDate.isSmallerThanValue(now)))
        .write(const TradingWarningCompanion(isActive: Value(false)));
  }

  /// 取得指定日期的警示資料筆數（新鮮度檢查用）
  Future<int> getWarningCountForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = tradingWarning.symbol.count();
    final query = selectOnly(tradingWarning)
      ..addColumns([countExpr])
      ..where(tradingWarning.date.isBiggerOrEqualValue(startOfDay))
      ..where(tradingWarning.date.isSmallerThanValue(endOfDay));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得最新警示資料的同步時間
  ///
  /// 用於新鮮度檢查，避免重複同步。
  Future<DateTime?> getLatestWarningSyncTime() async {
    final query = select(tradingWarning)
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.date;
  }
}
