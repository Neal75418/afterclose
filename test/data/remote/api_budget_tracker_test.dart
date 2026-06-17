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
}
