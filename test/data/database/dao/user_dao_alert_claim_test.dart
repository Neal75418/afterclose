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

  group('釋放認領(2026-08-08 三次審查 C-1)', () {
    // 認領必須發生在通知**之前**(否則兩個 process 會重複通知),但這也
    // 意味著「已認領」不等於「已送達」。通知失敗時若不釋放,該筆就變成
    // isActive=false + triggeredAt!=null——**兩條路徑的 pending 過濾都
    // 會永久跳過它**,使用者沒收到通知,收盤那條也再看不到。這正是本
    // 專案反覆出現的「副作用先寫、驗證後做」。
    test('🚨 認領後釋放 → 回到可再次認領的狀態', () async {
      final id = await seed();
      expect(await db.claimAlertTrigger(id), isTrue);

      await db.releaseAlertClaim(id);

      final a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
      expect(a.triggeredAt, isNull, reason: '沒送達就不算觸發過');
      expect(a.isActive, isTrue, reason: '必須重新變回待監控,否則永遠不會再檢查');
      expect(
        await db.claimAlertTrigger(id),
        isTrue,
        reason: '下一輪(或另一個 process)要能重新搶到',
      );
    });

    test('釋放不存在的 id → 安靜跳過,不拋例外', () async {
      expect(() => db.releaseAlertClaim(999999), returnsNormally);
    });
  });
}
