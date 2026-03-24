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
  });
}
