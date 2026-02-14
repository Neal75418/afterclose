part of 'package:afterclose/data/database/app_database.dart';

/// 新聞相關資料存取
mixin _NewsDaoMixin on _$AppDatabase {
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
}
