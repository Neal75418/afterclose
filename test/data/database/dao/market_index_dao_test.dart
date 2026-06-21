import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  // 固定「現在」時點，避免測試依賴系統時間
  final now = DateTime(2026, 6, 15);

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('MarketIndexDao.getIndexHistoryBatch', () {
    test('excludes future-dated rows (上界防護)', () async {
      const name = '發行量加權股價指數';

      await db.upsertMarketIndices([
        MarketIndexCompanion.insert(
          date: DateTime(2026, 6, 13),
          name: name,
          close: 22000.0,
          change: 10.0,
          changePercent: 0.05,
        ),
        MarketIndexCompanion.insert(
          date: DateTime(2026, 6, 14),
          name: name,
          close: 22050.0,
          change: 50.0,
          changePercent: 0.23,
        ),
        // 未來髒資料：應永遠不被讀出
        MarketIndexCompanion.insert(
          date: DateTime(2026, 12, 18),
          name: name,
          close: 99999.0,
          change: 0.0,
          changePercent: 0.0,
        ),
      ]);

      final history = await db.getIndexHistoryBatch(
        [name],
        days: 120,
        now: now,
      );

      final rows = history[name] ?? [];
      expect(rows.length, 2);
      // 未來的 99999 不應出現
      expect(rows.any((r) => r.close == 99999.0), isFalse);
      // 最新一筆應為 6/14 而非 12/18
      expect(rows.last.date, DateTime(2026, 6, 14));
    });

    test('includes the boundary date equal to now', () async {
      const name = '發行量加權股價指數';

      await db.upsertMarketIndices([
        MarketIndexCompanion.insert(
          date: now, // 恰好等於上界
          name: name,
          close: 22100.0,
          change: 50.0,
          changePercent: 0.23,
        ),
      ]);

      final history = await db.getIndexHistoryBatch(
        [name],
        days: 120,
        now: now,
      );

      expect(history[name]?.length, 1);
    });
  });
}
