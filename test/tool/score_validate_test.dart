// tool/score_validate.dart 純邏輯測試（分桶 + 單調性）。
import 'package:flutter_test/flutter_test.dart';

import '../../tool/score_validate.dart';

void main() {
  group('bucketIndex', () {
    test('邊界歸右桶、clamp [0,3]', () {
      expect(bucketIndex(0), 0);
      expect(bucketIndex(19.9), 0);
      expect(bucketIndex(20), 1);
      expect(bucketIndex(40), 2);
      expect(bucketIndex(60), 3);
      expect(bucketIndex(80), 3); // clamp（score 已 clamp 80）
      expect(bucketIndex(-5), 0); // 防呆
    });
  });

  group('summarize', () {
    test('切桶 + 勝率/平均報酬', () {
      final samples = <({double score, double ret})>[
        (score: 10, ret: 2), // 桶0
        (score: 15, ret: -4), // 桶0
        (score: 70, ret: 8), // 桶3
        (score: 65, ret: 6), // 桶3
      ];
      final b = summarize(samples);
      expect(b[0].count, 2);
      expect(b[0].winRate, closeTo(0.5, 1e-9));
      expect(b[0].avgReturn, closeTo(-1.0, 1e-9)); // (2-4)/2
      expect(b[3].count, 2);
      expect(b[3].winRate, 1.0);
      expect(b[3].avgReturn, closeTo(7.0, 1e-9)); // (8+6)/2
      expect(b[1].count, 0);
    });
  });

  group('monotonicity', () {
    test('遞增 → monotonic、spread 為正', () {
      final b = summarize([
        (score: 10, ret: 1),
        (score: 30, ret: 3),
        (score: 70, ret: 9),
      ]);
      final m = monotonicity(b);
      expect(m.monotonic, true);
      expect(m.spread, closeTo(8.0, 1e-9)); // 9 - 1
    });

    test('高分桶反而低 → 非單調', () {
      final b = summarize([(score: 10, ret: 5), (score: 70, ret: 1)]);
      final m = monotonicity(b);
      expect(m.monotonic, false);
      expect(m.spread, closeTo(-4.0, 1e-9)); // 1 - 5
    });

    test('只有一個非空桶 → 不算單調', () {
      final b = summarize([(score: 10, ret: 5)]);
      expect(monotonicity(b).monotonic, false);
    });
  });

  group('summarizeByBands', () {
    test('依上界分組（<100 / 100-120 / 120-150 / ≥150）', () {
      final samples = <({double value, double ret})>[
        (value: 85, ret: 1), // band0 <100
        (value: 99, ret: 3), // band0
        (value: 110, ret: 5), // band1
        (value: 140, ret: 7), // band2
        (value: 200, ret: 9), // band3 ≥150
      ];
      final b = summarizeByBands(samples, [100, 120, 150]);
      expect(b.length, 4);
      expect(b[0].count, 2);
      expect(b[0].avgReturn, closeTo(2.0, 1e-9)); // (1+3)/2
      expect(b[1].count, 1);
      expect(b[1].avgReturn, closeTo(5.0, 1e-9));
      expect(b[2].count, 1);
      expect(b[3].count, 1);
      expect(b[3].avgReturn, closeTo(9.0, 1e-9));
    });

    test('邊界值歸右組（value==上界 → 下一組）', () {
      final b = summarizeByBands([(value: 100, ret: 1)], [100, 120]);
      expect(b[0].count, 0, reason: '100 不 < 100');
      expect(b[1].count, 1, reason: '100 < 120 → band1');
    });
  });
}
