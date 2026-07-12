import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/daily_institutional.drift.dart';

/// 每日三大法人進出資料操作
mixin InstitutionalDaoMixin on $AppDatabase {
  /// 取得股票的法人資料歷史
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

  /// 取得股票的最新法人資料
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol) {
    return (select(dailyInstitutional)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 批次新增法人資料
  Future<void> insertInstitutionalData(
    List<DailyInstitutionalCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyInstitutional, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 批次取得多檔股票的法人資料（批次查詢）
  ///
  /// 回傳 symbol -> 法人資料列表 的 Map，依日期升冪排序
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

    // 依 symbol 分組
    final grouped = <String, List<DailyInstitutionalEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 取得指定日期的法人資料筆數
  Future<int> getInstitutionalCountForDate(DateTime date) async {
    final countExpr = dailyInstitutional.symbol.count();
    final query = selectOnly(dailyInstitutional)
      ..addColumns([countExpr])
      ..where(dailyInstitutional.date.equals(date));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 清除所有法人資料
  ///
  /// 用於修正單位錯誤後重新同步資料
  Future<int> clearAllInstitutionalData() async {
    return await (delete(dailyInstitutional)).go();
  }

  /// 計算某交易日已寫入的法人資料筆數（backfill per-day resume 判斷用，
  /// 與 [PriceDaoMixin.countPricesByDateAndMarket] 同模式；法人 phase
  /// 兩市場一起跑，故不分市場、比對全市場總數）。
  Future<int> countInstitutionalByDate(DateTime date) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM daily_institutional WHERE date = ?',
      variables: [Variable.withDateTime(date)],
    ).getSingle();
    return result.read<int>('cnt');
  }
}
