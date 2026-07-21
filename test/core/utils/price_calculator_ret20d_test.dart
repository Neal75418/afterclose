import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_calculator.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  group('PriceCalculator.ret20d', () {
    test('21 筆 → (尾-首)/首', () {
      final history = List.generate(
        21,
        (i) => createTestPrice(
          date: DateTime(2026, 6, 1).add(Duration(days: i)),
          close: i == 20 ? 110.0 : 100.0,
        ),
      );
      expect(PriceCalculator.ret20d(history), closeTo(10.0, 1e-9));
    });

    test('不足 21 筆 / null / 起點 0 → null', () {
      final short = List.generate(
        20,
        (i) => createTestPrice(
          date: DateTime(2026, 6, 1).add(Duration(days: i)),
          close: 100.0,
        ),
      );
      expect(PriceCalculator.ret20d(short), isNull);
      expect(PriceCalculator.ret20d(null), isNull);

      final zeroStart = List.generate(
        21,
        (i) => createTestPrice(
          date: DateTime(2026, 6, 1).add(Duration(days: i)),
          close: i == 0 ? 0.0 : 100.0,
        ),
      );
      expect(PriceCalculator.ret20d(zeroStart), isNull);
    });
  });

  group('PriceCalculator.ret5d', () {
    test('6 筆 → (尾-首)/首', () {
      final history = List.generate(
        6,
        (i) => createTestPrice(
          date: DateTime(2026, 6, 1).add(Duration(days: i)),
          close: i == 5 ? 105.0 : 100.0,
        ),
      );
      expect(PriceCalculator.ret5d(history), closeTo(5.0, 1e-9));
    });

    test('不足 6 筆 / null → null', () {
      final short = List.generate(
        5,
        (i) => createTestPrice(
          date: DateTime(2026, 6, 1).add(Duration(days: i)),
          close: 100.0,
        ),
      );
      expect(PriceCalculator.ret5d(short), isNull);
      expect(PriceCalculator.ret5d(null), isNull);
    });
  });
}
