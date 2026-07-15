import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:afterclose/domain/services/update/news_mention_snapshot_service.dart';

class MockNewsRepository extends Mock implements INewsRepository {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

NewsItemEntry news(String id, String title, DateTime publishedAt) =>
    NewsItemEntry(
      id: id,
      source: '鉅亨網',
      title: title,
      url: 'https://example.com/$id',
      category: 'OTHER',
      publishedAt: publishedAt,
      fetchedAt: publishedAt,
    );

void main() {
  late AppDatabase db;
  late MockNewsRepository newsRepo;
  late NewsMentionSnapshotService service;
  final now = DateTime(2026, 7, 15, 20, 0);

  setUp(() async {
    db = AppDatabase.forTesting();
    // 匹配字典需要 stock_master
    await db.batch((b) {
      b.insertAll(db.stockMaster, [
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
      ]);
    });
    newsRepo = MockNewsRepository();
    service = NewsMentionSnapshotService(
      database: db,
      newsRepository: newsRepo,
      clock: _FixedClock(now),
    );
  });

  tearDown(() async => db.close());

  test('近 3 日提及數落地（stock 與 theme）', () async {
    when(() => newsRepo.getRecentNews(days: any(named: 'days'))).thenAnswer(
      (_) async => [
        news('a', '台積電法說 AI 需求強', DateTime(2026, 7, 15, 9)),
        news('b', '台積電再創高', DateTime(2026, 7, 14, 9)),
        news('c', '記憶體漲價', DateTime(2026, 7, 15, 10)),
      ],
    );

    await service.snapshotRecentDays();

    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 13));
    final stock715 = rows.singleWhere(
      (r) => r.kind == 'stock' && r.itemKey == '2330' && r.date.day == 15,
    );
    expect(stock715.mentionCount, 1);
    expect(stock715.dictionaryVersion, greaterThanOrEqualTo(1));
    expect(rows.any((r) => r.kind == 'theme' && r.itemKey == '記憶體'), isTrue);
    expect(rows.any((r) => r.kind == 'theme' && r.itemKey == 'AI'), isTrue);
  });

  test('重跑冪等（同日重寫不重複累加）', () async {
    when(
      () => newsRepo.getRecentNews(days: any(named: 'days')),
    ).thenAnswer((_) async => [news('a', '台積電再創高', DateTime(2026, 7, 15, 9))]);
    await service.snapshotRecentDays();
    await service.snapshotRecentDays();
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 15));
    expect(
      rows.where((r) => r.kind == 'stock' && r.itemKey == '2330'),
      hasLength(1),
    );
    expect(rows.first.mentionCount, 1);
  });

  test('殘留列修正：窗內 stale key 重算為 0 時應被刪除（非殘留）', () async {
    // 預先插入一筆「窗內日期、9999」的殘留列，模擬字典異動或個股下市
    // 導致舊值不再有對應新聞，但重算計數為 0（不會被 upsert 觸及）
    await db.upsertMentionCounts([
      NewsMentionDailyCompanion.insert(
        date: DateTime(2026, 7, 14),
        kind: 'stock',
        itemKey: '9999',
        mentionCount: 3,
        dictionaryVersion: 1,
      ),
    ]);

    when(
      () => newsRepo.getRecentNews(days: any(named: 'days')),
    ).thenAnswer((_) async => [news('a', '台積電再創高', DateTime(2026, 7, 15, 9))]);

    await service.snapshotRecentDays();

    final rows = await db.getMentionCounts(from: DateTime(2026, 1, 1));
    expect(
      rows.any((r) => r.itemKey == '9999'),
      isFalse,
      reason: '窗內 stale 列應在全量覆寫後歸零消失',
    );
    expect(
      rows.any(
        (r) => r.kind == 'stock' && r.itemKey == '2330' && r.date.day == 15,
      ),
      isTrue,
      reason: '真實提及數應正常寫入',
    );
  });
}
