import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async => db.close());

  NewsMentionDailyCompanion row(
    DateTime date,
    String kind,
    String key,
    int count,
  ) => NewsMentionDailyCompanion.insert(
    date: date,
    kind: kind,
    itemKey: key,
    mentionCount: count,
    dictionaryVersion: 1,
  );

  test('upsert 寫入與讀回', () async {
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 15), 'stock', '2330', 5),
      row(DateTime(2026, 7, 15), 'theme', '記憶體', 8),
    ]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 1));
    expect(rows, hasLength(2));
  });

  test('同 (date,kind,key) 重寫覆蓋（冪等回補）', () async {
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 15), 'stock', '2330', 3),
    ]);
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 15), 'stock', '2330', 7),
    ]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 1));
    expect(rows.single.mentionCount, 7);
  });

  test('from 過濾', () async {
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 1), 'stock', '2330', 1),
      row(DateTime(2026, 7, 15), 'stock', '2330', 2),
    ]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 10));
    expect(rows.single.mentionCount, 2);
  });

  test('replaceMentionCountsInWindow 刪除窗內舊列並寫入新列，窗外不受影響', () async {
    // 窗內殘留列（重算後應消失的 stale key）
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 13), 'stock', '9999', 4),
    ]);
    // 窗外列（不應被刪除）
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 1), 'stock', '2330', 1),
    ]);

    await db.replaceMentionCountsInWindow(
      from: DateTime(2026, 7, 13),
      to: DateTime(2026, 7, 15),
      rows: [row(DateTime(2026, 7, 15), 'stock', '2330', 6)],
    );

    final rows = await db.getMentionCounts(from: DateTime(2026, 1, 1));
    expect(
      rows.any((r) => r.itemKey == '9999'),
      isFalse,
      reason: '窗內 stale 列應被刪除',
    );
    expect(
      rows.any((r) => r.date == DateTime(2026, 7, 1) && r.itemKey == '2330'),
      isTrue,
      reason: '窗外列不應受影響',
    );
    expect(
      rows.any(
        (r) =>
            r.date == DateTime(2026, 7, 15) &&
            r.itemKey == '2330' &&
            r.mentionCount == 6,
      ),
      isTrue,
      reason: '新列應寫入',
    );
  });
}
