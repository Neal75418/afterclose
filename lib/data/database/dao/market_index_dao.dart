import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 大盤指數歷史資料存取
extension MarketIndexDao on AppDatabase {
  // ==========================================
  // 大盤指數歷史操作
  // ==========================================

  /// 批次寫入大盤指數資料（upsert on conflict (date, name)）
  Future<void> upsertMarketIndices(List<MarketIndexCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(
          marketIndex,
          entry,
          onConflict: DoUpdate(
            (_) => entry,
            target: [marketIndex.date, marketIndex.name],
          ),
        );
      }
    });
  }

  /// 取得指定指數名稱的近 N 日歷史
  Future<List<MarketIndexEntry>> getIndexHistory(
    String indexName, {
    int days = 30,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days + 10));
    return (select(marketIndex)
          ..where(
            (t) => t.name.equals(indexName) & t.date.isBiggerThanValue(cutoff),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.date)])
          ..limit(days))
        .get();
  }

  /// 取得多個指數的近 N 日歷史（批次）
  Future<Map<String, List<MarketIndexEntry>>> getIndexHistoryBatch(
    List<String> indexNames, {
    int days = 30,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days + 10));
    final rows =
        await (select(marketIndex)
              ..where(
                (t) =>
                    t.name.isIn(indexNames) & t.date.isBiggerThanValue(cutoff),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();

    final result = <String, List<MarketIndexEntry>>{};
    for (final row in rows) {
      result.putIfAbsent(row.name, () => []).add(row);
    }
    return result;
  }

  /// 取得最新的指數日期
  Future<DateTime?> getLatestMarketIndexDate() async {
    final result = await customSelect(
      'SELECT MAX(date) as max_date FROM market_index',
    ).getSingleOrNull();
    if (result == null) return null;
    final val = result.data['max_date'];
    if (val == null) return null;
    // storeDateTimeAsText: date 儲存為 ISO 8601 文字
    return DateTime.tryParse(val.toString());
  }
}
