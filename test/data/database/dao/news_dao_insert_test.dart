import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

/// insertNewsWithMappings 的重跑冪等守門：穩定 id + insertOrIgnore
/// 是重大訊息每日檔累積不重複的載體，必須有真 DB 驗證（審查 i 項）。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '1537', name: '廣隆', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test('同一公告寫兩次：news_item 與股票關聯各僅一筆', () async {
    final newsRow = NewsItemCompanion.insert(
      id: 'mops_1537_1150723_151812',
      source: '重大訊息',
      title: '1537 廣隆｜受邀參加法人說明會',
      content: const Value('說明全文'),
      url: 'https://mops.twse.com.tw/mops/web/t05st01',
      category: 'ANNOUNCEMENT',
      publishedAt: DateTime.utc(2026, 7, 23, 7, 18, 12),
    );
    final mapRow = NewsStockMapCompanion.insert(
      newsId: 'mops_1537_1150723_151812',
      symbol: '1537',
    );

    await db.insertNewsWithMappings([newsRow], [mapRow]);
    await db.insertNewsWithMappings([newsRow], [mapRow]); // 隔日重跑

    final items = await db.select(db.newsItem).get();
    final maps = await db.select(db.newsStockMap).get();
    expect(items, hasLength(1));
    expect(maps, hasLength(1));
    expect(items.single.source, '重大訊息');
  });
}
