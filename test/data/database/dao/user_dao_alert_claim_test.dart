import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/database/app_database.dart';

/// 觸發的原子性(2026-08-08 code review L4)。
///
/// app 內的輪詢與 launchd CLI(每 5 分鐘)跑在**兩個 process、同一個
/// SQLite**。原本的 triggerAlert 是無條件 UPDATE,兩邊可能都讀到
/// triggeredAt==null、都通知 → 使用者收到重複警報(一個系統通知、
/// 一個 app 通知)。改為條件式 UPDATE + 回傳是否搶到。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting());
  tearDown(() async => db.close());

  Future<int> seed() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '3231', name: '緯創', market: 'TWSE'),
    ]);
    return db.createPriceAlert(
      symbol: '3231',
      alertType: 'BELOW',
      targetValue: 179.95,
    );
  }

  test('🚨 第一次觸發搶到、第二次搶不到(跨 process 去重)', () async {
    final id = await seed();
    expect(await db.claimAlertTrigger(id), isTrue, reason: '第一個 process 搶到');
    expect(await db.claimAlertTrigger(id), isFalse, reason: '第二個看到已觸發,不重複通知');
  });

  test('搶到後狀態正確:已停用且有觸發時間', () async {
    final id = await seed();
    await db.claimAlertTrigger(id, now: DateTime(2026, 8, 10, 10, 30));
    final a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
    expect(a.isActive, isFalse);
    expect(a.triggeredAt, DateTime(2026, 8, 10, 10, 30));
  });

  test('不存在的 id 回 false,不拋例外', () async {
    expect(await db.claimAlertTrigger(999999), isFalse);
  });
}
