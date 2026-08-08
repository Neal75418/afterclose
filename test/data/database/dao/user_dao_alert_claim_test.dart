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

  test('搶到後寫入觸發時間,但**不**消費提醒', () async {
    // 2026-08-08 四次審查:舊版認領時一併寫 isActive=false,於是補償
    // (釋放)也得寫回 true,就會覆蓋使用者中途手動停用的動作。
    // 新語意:triggeredAt = 機器互斥,isActive = 使用者意圖,兩者分離。
    final id = await seed();
    await db.claimAlertTrigger(id, now: DateTime(2026, 8, 10, 10, 30));
    final a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
    expect(a.isActive, isTrue, reason: '認領只是取得通知權,還沒送出就不算用掉');
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
      // ⚠️ 不可用 `returnsNormally`:releaseAlertClaim 是 async,例外會被
      // 包進回傳的 Future、**永遠不會同步拋出**,那條斷言在任何實作下都
      // 會綠(把整個 body 換成 throw 也照樣過)(2026-08-08 四次審查 I-4)
      await expectLater(db.releaseAlertClaim(999999), completes);
    });

    test('🚨 不可複活使用者刻意停用的提醒', () async {
      // 交錯(2026-08-08 四次審查 Q1):CLI 認領後進入 osascript 迴圈
      // (每筆都是一次 Process.run,N 筆就是 N 次往返),這段真空期間
      // 使用者在 app 裡把提醒關掉。若釋放無條件寫 isActive=true,
      // 使用者剛親手關掉的提醒會自己復活,下一輪再叫他一次。
      final id = await seed();
      await db.claimAlertTrigger(id, now: DateTime(2026, 8, 10, 10, 30));

      // 使用者停用(只動 isActive,不動 triggeredAt)
      await db.updatePriceAlert(
        id,
        const PriceAlertCompanion(isActive: Value(false)),
      );

      await db.releaseAlertClaim(id, stamp: DateTime(2026, 8, 10, 10, 30));

      final a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
      expect(a.isActive, isFalse, reason: 'isActive 是使用者意圖,機器的補償動作不可覆寫它');
      expect(a.triggeredAt, isNull, reason: '認領本身仍要撤銷,才不會卡在中間狀態');
    });

    test('🚨 釋放必須認得自己的認領,不可抹掉別人剛寫的', () async {
      // 交錯(Q2-b):CLI 認領(T1)→ 使用者把開關撥回 ON(重置)→
      // GUI 重新認領(T2)並成功通知 → CLI 這時才發現自己失敗、去釋放。
      // 若釋放不比對 stamp,會把 T2 一起抹掉 → 同一次觸價被通知兩次。
      final id = await seed();
      final t1 = DateTime(2026, 8, 10, 10, 30);
      final t2 = DateTime(2026, 8, 10, 10, 31);

      await db.claimAlertTrigger(id, now: t1);
      await db.releaseAlertClaim(id, stamp: t1); // 模擬重置
      await db.claimAlertTrigger(id, now: t2); // 另一方重新認領

      await db.releaseAlertClaim(id, stamp: t1); // 遲來的釋放,帶舊 stamp

      final a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
      expect(a.triggeredAt, t2, reason: '別人的認領必須完好,否則會重複通知');
    });

    test('認領只當互斥鍵,不消費提醒;消費是另一個動作', () async {
      // isActive 是使用者意圖,triggeredAt 是機器互斥——兩把鑰匙不可共用
      // 一副鎖(Q4)。認領成功但尚未送出時,提醒仍應是 active。
      final id = await seed();
      await db.claimAlertTrigger(id);
      var a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
      expect(a.isActive, isTrue, reason: '認領 ≠ 消費,還沒送出就不算用掉');

      await db.consumeAlertClaim(id);
      a = (await db.getAllAlerts()).firstWhere((x) => x.id == id);
      expect(a.isActive, isFalse, reason: '送出成功才消費');
    });
  });
}
