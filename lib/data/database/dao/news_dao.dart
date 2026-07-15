import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/news_tables.drift.dart';

/// 新聞相關資料存取
mixin NewsDaoMixin on $AppDatabase {
  // ==================================================
  // 新聞操作
  // ==================================================

  /// 批次取得多則新聞的股票關聯（批次查詢）
  ///
  /// 回傳 newsId -> 股票代碼列表 的 Map
  Future<Map<String, List<String>>> getNewsStockMappingsBatch(
    List<String> newsIds,
  ) async {
    if (newsIds.isEmpty) return {};

    final results = await (select(
      newsStockMap,
    )..where((t) => t.newsId.isIn(newsIds))).get();

    // 依 newsId 分組
    final grouped = <String, List<String>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.newsId, () => []).add(entry.symbol);
    }

    return grouped;
  }

  // ==================================================
  // 每日提及數快照（新聞熱度發現層）
  // ==================================================

  /// 快照 upsert（(date,kind,itemKey) 覆蓋——供每日回補冪等重寫）
  Future<void> upsertMentionCounts(List<NewsMentionDailyCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final r in rows) {
        b.insert(newsMentionDaily, r, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 窗內全量覆寫：先刪 [from, to]（含端點）日期範圍內全部快照列再批次寫入，
  /// 使重算對「已消失的 key」也冪等（殘留列歸零）
  Future<void> replaceMentionCountsInWindow({
    required DateTime from,
    required DateTime to,
    required List<NewsMentionDailyCompanion> rows,
  }) async {
    await transaction(() async {
      await (delete(newsMentionDaily)..where(
            (t) =>
                t.date.isBiggerOrEqualValue(from) &
                t.date.isSmallerOrEqualValue(to),
          ))
          .go();
      if (rows.isNotEmpty) {
        await batch((b) {
          for (final r in rows) {
            b.insert(newsMentionDaily, r, mode: InsertMode.insertOrReplace);
          }
        });
      }
    });
  }

  /// 讀取快照（date >= from），未來回測用；測試亦用此驗證寫入
  Future<List<NewsMentionDailyEntry>> getMentionCounts({
    required DateTime from,
  }) {
    return (select(newsMentionDaily)
          ..where((t) => t.date.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }
}
