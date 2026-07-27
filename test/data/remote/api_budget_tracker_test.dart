import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/remote/api_budget_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake clock that yields a fixed [DateTime] (test-controlled).
class _FakeClock implements AppClock {
  _FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
  void setNow(DateTime t) => _now = t;
}

void main() {
  group('ApiBudgetTracker', () {
    test('defaults to FinMind 600/hr budget when no override given', () {
      final t = ApiBudgetTracker();
      expect(t.budgetFor(ApiVendor.finMind), 600);
    });

    test('custom budget overrides default', () {
      final t = ApiBudgetTracker(hourlyBudget: {ApiVendor.finMind: 10});
      expect(t.budgetFor(ApiVendor.finMind), 10);
    });

    test('checkBudget passes when no calls recorded', () {
      final t = ApiBudgetTracker();
      expect(() => t.checkBudget(ApiVendor.finMind), returnsNormally);
    });

    test('recordCall increments callsInLastHourFor', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(clock: clock);
      t.recordCall(ApiVendor.finMind);
      t.recordCall(ApiVendor.finMind);
      t.recordCall(ApiVendor.finMind);
      expect(t.callsInLastHourFor(ApiVendor.finMind), 3);
    });

    test('checkBudget throws RateLimitException when budget exceeded', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(
        hourlyBudget: {ApiVendor.finMind: 3},
        clock: clock,
      );
      t.recordCall(ApiVendor.finMind);
      t.recordCall(ApiVendor.finMind);
      t.recordCall(ApiVendor.finMind);
      expect(
        () => t.checkBudget(ApiVendor.finMind),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('sliding window expires entries older than 1hr', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(
        hourlyBudget: {ApiVendor.finMind: 5},
        clock: clock,
      );
      // 5 calls at t=0
      for (var i = 0; i < 5; i++) {
        t.recordCall(ApiVendor.finMind);
      }
      expect(
        () => t.checkBudget(ApiVendor.finMind),
        throwsA(isA<RateLimitException>()),
      );

      // advance > 1hr — old entries should expire
      clock.advance(const Duration(hours: 1, minutes: 1));
      expect(t.callsInLastHourFor(ApiVendor.finMind), 0);
      expect(() => t.checkBudget(ApiVendor.finMind), returnsNormally);
    });

    test('markRateLimited triggers 1hr cooldown blocking all checkBudget', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(clock: clock);
      t.markRateLimited(ApiVendor.finMind);
      expect(t.isRateLimited(ApiVendor.finMind), isTrue);
      expect(
        () => t.checkBudget(ApiVendor.finMind),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('cooldown clears after 1hr', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(clock: clock);
      t.markRateLimited(ApiVendor.finMind);
      clock.advance(const Duration(hours: 1, minutes: 1));
      expect(t.isRateLimited(ApiVendor.finMind), isFalse);
      expect(() => t.checkBudget(ApiVendor.finMind), returnsNormally);
    });

    test('per-vendor budgets are independent', () {
      final clock = _FakeClock(DateTime.utc(2026, 6, 9, 12));
      final t = ApiBudgetTracker(
        hourlyBudget: {ApiVendor.finMind: 2, ApiVendor.twse: 100},
        clock: clock,
      );
      t.recordCall(ApiVendor.finMind);
      t.recordCall(ApiVendor.finMind);
      // FinMind exhausted but TWSE should still work
      expect(
        () => t.checkBudget(ApiVendor.finMind),
        throwsA(isA<RateLimitException>()),
      );
      expect(() => t.checkBudget(ApiVendor.twse), returnsNormally);
    });

    test('cooldown for one vendor does not block another', () {
      final t = ApiBudgetTracker();
      t.markRateLimited(ApiVendor.finMind);
      expect(t.isRateLimited(ApiVendor.finMind), isTrue);
      expect(t.isRateLimited(ApiVendor.twse), isFalse);
      expect(() => t.checkBudget(ApiVendor.twse), returnsNormally);
    });
  });

  // 重啟後計數歸零，但 FinMind 伺服器端的額度不會忘記
  //
  // 2026-07-27 19:20 正式日誌：
  //   [FinMind] TaiwanStockShareholding(2886): 402 API 額度耗盡
  //   [ApiBudgetTracker] finMind 撞 rate limit，1hr cooldown 開始 (已用 42/600)
  // **本地計數 42、伺服器說已耗盡**。成因是 app 於 19:09 重啟：
  // `_callTimestamps` / `_rateLimitedAt` 都是純記憶體（且 provider 是 plain
  // Provider，隨 process 消滅），而 18:31~18:37 三輪約 560 次呼叫仍在
  // FinMind 伺服器端的窗內 → 560 + 42 ≈ 602 越線。
  //
  // 誤差方向不對稱：**帶過去只會高估**（高估＝少補一點，安全）；
  // **歸零是低估**（低估＝撞 402，就是今天）。故即使 FinMind 伺服器端的
  // 窗語意與本地不完全一致，延續計數仍嚴格優於歸零。
  group('跨重啟延續（restore / persist）', () {
    final t0 = DateTime(2026, 7, 27, 19, 20);

    test('🚨 restore 後窗內呼叫數要延續，不得歸零', () async {
      final clock = _FakeClock(t0);
      final store = _FakeBudgetStore();

      final first = ApiBudgetTracker(clock: clock, store: store);
      await first.restore();
      for (var i = 0; i < 40; i++) {
        first.recordCall(ApiVendor.finMind);
      }
      await first.flush();

      // 模擬 app 重啟：全新 tracker，同一份儲存
      clock.advance(const Duration(minutes: 5));
      final second = ApiBudgetTracker(clock: clock, store: store);
      await second.restore();

      expect(
        second.callsInLastHourFor(ApiVendor.finMind),
        40,
        reason: '歸零會讓下一輪以為還有滿額，然後撞 FinMind 伺服器端的 402',
      );
    });

    test('🚨 超過 1 小時的舊紀錄不得被 restore 回來', () async {
      final clock = _FakeClock(t0);
      final store = _FakeBudgetStore();

      final first = ApiBudgetTracker(clock: clock, store: store);
      await first.restore();
      for (var i = 0; i < 30; i++) {
        first.recordCall(ApiVendor.finMind);
      }
      await first.flush();

      clock.advance(const Duration(hours: 1, minutes: 1));
      final second = ApiBudgetTracker(clock: clock, store: store);
      await second.restore();

      expect(
        second.callsInLastHourFor(ApiVendor.finMind),
        0,
        reason: '過期紀錄若復活，會永久壓低可用額度——那是另一個方向的錯',
      );
    });

    test('🚨 cooldown 要跨重啟存活（撞過 402 就別再打）', () async {
      final clock = _FakeClock(t0);
      final store = _FakeBudgetStore();

      final first = ApiBudgetTracker(clock: clock, store: store);
      await first.restore();
      first.markRateLimited(ApiVendor.finMind);
      await first.flush();

      clock.advance(const Duration(minutes: 10));
      final second = ApiBudgetTracker(clock: clock, store: store);
      await second.restore();

      expect(second.isRateLimited(ApiVendor.finMind), isTrue);
      expect(
        () => second.checkBudget(ApiVendor.finMind),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('對照組：cooldown 滿 1 小時後不得復活', () async {
      final clock = _FakeClock(t0);
      final store = _FakeBudgetStore();

      final first = ApiBudgetTracker(clock: clock, store: store);
      await first.restore();
      first.markRateLimited(ApiVendor.finMind);
      await first.flush();

      clock.advance(const Duration(hours: 1, minutes: 1));
      final second = ApiBudgetTracker(clock: clock, store: store);
      await second.restore();

      expect(second.isRateLimited(ApiVendor.finMind), isFalse);
    });

    test('🚨 儲存讀取失敗必須 fail-open，不得讓整個 app 打不了 API', () async {
      final tracker = ApiBudgetTracker(
        clock: _FakeClock(t0),
        store: _ThrowingBudgetStore(),
      );

      await expectLater(tracker.restore(), completes);
      expect(tracker.callsInLastHourFor(ApiVendor.finMind), 0);
      expect(() => tracker.checkBudget(ApiVendor.finMind), returnsNormally);
    });

    test('🚨 熱路徑不得每次呼叫都寫入儲存', () async {
      final store = _FakeBudgetStore();
      final tracker = ApiBudgetTracker(clock: _FakeClock(t0), store: store);
      await tracker.restore();

      for (var i = 0; i < 100; i++) {
        tracker.recordCall(ApiVendor.finMind);
      }
      // 讓可能的非同步寫入有機會跑完
      await Future<void>.delayed(Duration.zero);

      expect(
        store.writeCount,
        lessThan(100),
        reason: 'recordCall 每小時最多 600 次；每次都寫 SharedPreferences 是浪費',
      );
    });

    test('🚨 restore 必須回報載入了什麼——否則無法從日誌驗證它有生效', () async {
      // 2026-07-27 實測教訓：持久化寫進 plist 了（290 筆實證），但日誌上
      // 看不出 restore 有沒有讀回來——「同一 session 累積」與「重啟後成功
      // 還原」在磁碟狀態上完全相同，無法區分。沒有量測點就沒有驗證。
      final clock = _FakeClock(t0);
      final store = _FakeBudgetStore();

      final first = ApiBudgetTracker(clock: clock, store: store);
      await first.restore();
      for (var i = 0; i < 25; i++) {
        first.recordCall(ApiVendor.finMind);
      }
      first.markRateLimited(ApiVendor.finMind);
      await first.flush();

      clock.advance(const Duration(minutes: 3));
      final second = ApiBudgetTracker(clock: clock, store: store);
      final summary = await second.restore();

      expect(summary.restoredCalls, 25);
      expect(summary.cooldownVendors, contains(ApiVendor.finMind));
    });

    test('對照組：沒有 store 時 restore 回報零，不得謊報', () async {
      final tracker = ApiBudgetTracker(clock: _FakeClock(t0));
      final summary = await tracker.restore();

      expect(summary.restoredCalls, 0);
      expect(summary.cooldownVendors, isEmpty);
    });

    test('對照組：沒有 store 時行為與現況完全相同', () async {
      final tracker = ApiBudgetTracker(clock: _FakeClock(t0));

      await expectLater(tracker.restore(), completes);
      tracker.recordCall(ApiVendor.finMind);
      expect(tracker.callsInLastHourFor(ApiVendor.finMind), 1);
      await expectLater(tracker.flush(), completes);
    });
  });
}

/// 記憶體版 store，模擬跨 process 的持久層
class _FakeBudgetStore implements ApiBudgetStore {
  String? _data;
  int writeCount = 0;

  @override
  Future<String?> load() async => _data;

  @override
  Future<void> save(String json) async {
    writeCount++;
    _data = json;
  }
}

class _ThrowingBudgetStore implements ApiBudgetStore {
  @override
  Future<String?> load() async => throw Exception('storage unavailable');

  @override
  Future<void> save(String json) async =>
      throw Exception('storage unavailable');
}
