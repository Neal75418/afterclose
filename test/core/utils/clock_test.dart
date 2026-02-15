import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/taiwan_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemClock', () {
    test('now() returns current Taiwan time', () {
      const clock = SystemClock();
      final result = clock.now();
      final reference = TaiwanTime.now();

      // 允許最多 2 秒誤差（TaiwanTime.now() 截斷毫秒）
      final diff = result.difference(reference).abs();
      expect(diff.inSeconds, lessThanOrEqualTo(2));
    });

    test('is const constructible', () {
      // 確保 const 建構不會破壞現有 const 呼叫點
      const clock1 = SystemClock();
      const clock2 = SystemClock();
      expect(identical(clock1, clock2), isTrue);
    });
  });

  group('AppClock', () {
    test('can be implemented for testing', () {
      final fakeClock = _FakeClock(DateTime(2025, 6, 15, 14, 30));
      expect(fakeClock.now(), equals(DateTime(2025, 6, 15, 14, 30)));
    });

    test('fake clock returns consistent time', () {
      final fixedTime = DateTime(2025, 1, 1);
      final fakeClock = _FakeClock(fixedTime);

      // 多次呼叫回傳相同時間
      expect(fakeClock.now(), equals(fixedTime));
      expect(fakeClock.now(), equals(fixedTime));
    });
  });
}

/// 測試用假時鐘
class _FakeClock implements AppClock {
  _FakeClock(this._fixedTime);

  final DateTime _fixedTime;

  @override
  DateTime now() => _fixedTime;
}
