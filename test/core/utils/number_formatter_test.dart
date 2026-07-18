import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/number_formatter.dart';

void main() {
  group('AppNumberFormat.roundForDisplay', () {
    test('捨入至指定精度', () {
      expect(AppNumberFormat.roundForDisplay(1.234, 2), 1.23);
      expect(AppNumberFormat.roundForDisplay(1.235, 1), closeTo(1.2, 1e-9));
    });

    test('微負值捨入後歸零（-0.004 → 0，供配色判方向）', () {
      final rounded = AppNumberFormat.roundForDisplay(-0.004, 2);
      expect(rounded == 0, isTrue, reason: '捨入後應為 0，不得判為負');
      expect(rounded > 0, isFalse);
      expect(rounded < 0, isFalse);
    });
  });

  group('AppNumberFormat.signedFixed', () {
    test('正值帶 +', () {
      expect(AppNumberFormat.signedFixed(2.5, decimals: 2), '+2.50');
    });

    test('負值沿用 -', () {
      expect(AppNumberFormat.signedFixed(-1.234, decimals: 2), '-1.23');
    });

    test('平盤（0）不帶符號', () {
      expect(AppNumberFormat.signedFixed(0, decimals: 2), '0.00');
    });

    test('微負值捨入後顯示正零而非「-0.00」', () {
      expect(AppNumberFormat.signedFixed(-0.004, decimals: 2), '0.00');
    });
  });

  group('AppNumberFormat.signedPercent', () {
    test('正值帶 +（如 +1.67%）', () {
      expect(AppNumberFormat.signedPercent(1.67, decimals: 2), '+1.67%');
    });

    test('負值沿用 -（如 -2.30%）', () {
      expect(AppNumberFormat.signedPercent(-2.3, decimals: 2), '-2.30%');
    });

    test('平盤（0）→ 0.00%（不帶 +）', () {
      expect(AppNumberFormat.signedPercent(0, decimals: 2), '0.00%');
    });

    test('微負值 -0.004 → 0.00%（非 -0.00%）', () {
      expect(AppNumberFormat.signedPercent(-0.004, decimals: 2), '0.00%');
    });

    test('支援不同精度', () {
      expect(AppNumberFormat.signedPercent(3.2, decimals: 1), '+3.2%');
      expect(AppNumberFormat.signedPercent(-0.04, decimals: 1), '0.0%');
    });
  });
}
