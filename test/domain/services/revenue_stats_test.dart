import 'package:afterclose/domain/services/revenue_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('yoy3mAvg — 近3月均年增率', () {
    test('三個月皆有 YoY → 取最新三個月平均', () {
      final r = yoy3mAvg([
        (year: 2026, month: 4, yoy: 30.0),
        (year: 2026, month: 5, yoy: 40.0),
        (year: 2026, month: 6, yoy: 50.0),
        (year: 2026, month: 3, yoy: 999.0), // 第 4 新，不參與
      ]);
      expect(r, closeTo(40.0, 1e-9));
    });

    test('輸入順序無關（未排序也取到最新三月）', () {
      final r = yoy3mAvg([
        (year: 2026, month: 6, yoy: 50.0),
        (year: 2026, month: 4, yoy: 30.0),
        (year: 2026, month: 5, yoy: 40.0),
      ]);
      expect(r, closeTo(40.0, 1e-9));
    });

    test('跨年邊界正確排序（2025-12 比 2026-01 舊）', () {
      final r = yoy3mAvg([
        (year: 2025, month: 12, yoy: 10.0),
        (year: 2026, month: 1, yoy: 20.0),
        (year: 2026, month: 2, yoy: 30.0),
        (year: 2025, month: 11, yoy: 999.0),
      ]);
      expect(r, closeTo(20.0, 1e-9));
    });

    test('不足三個月 → null（防單月雜訊的規則本意，不硬湊）', () {
      expect(
        yoy3mAvg([
          (year: 2026, month: 5, yoy: 40.0),
          (year: 2026, month: 6, yoy: 50.0),
        ]),
        isNull,
      );
    });

    test('最新三月中有 YoY 為 null → null（缺值不得平均）', () {
      expect(
        yoy3mAvg([
          (year: 2026, month: 4, yoy: 30.0),
          (year: 2026, month: 5, yoy: null),
          (year: 2026, month: 6, yoy: 50.0),
        ]),
        isNull,
      );
    });

    test('同月重複資料只算一次（取後出現者視為覆寫）', () {
      final r = yoy3mAvg([
        (year: 2026, month: 4, yoy: 30.0),
        (year: 2026, month: 5, yoy: 40.0),
        (year: 2026, month: 6, yoy: 10.0),
        (year: 2026, month: 6, yoy: 50.0),
      ]);
      expect(r, closeTo(40.0, 1e-9));
    });

    test('空清單 → null', () {
      expect(yoy3mAvg(const []), isNull);
    });
  });
}
