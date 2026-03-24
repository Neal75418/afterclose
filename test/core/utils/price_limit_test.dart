import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_limit.dart';

void main() {
  group('PriceLimit', () {
    group('isLimitUp', () {
      test('return true for +10%', () {
        expect(PriceLimit.isLimitUp(10.0), isTrue);
      });

      test('return true for value within tolerance (+9.86%)', () {
        expect(PriceLimit.isLimitUp(9.86), isTrue);
      });

      test('return true at exact tolerance boundary (9.85%)', () {
        // threshold = limitPercent - _tolerance = 10.0 - 0.15 = 9.85
        expect(PriceLimit.isLimitUp(9.85), isTrue);
      });

      test('return false just below tolerance boundary (9.84%)', () {
        expect(PriceLimit.isLimitUp(9.84), isFalse);
      });

      test('return false for +9.5%', () {
        expect(PriceLimit.isLimitUp(9.5), isFalse);
      });

      test('return false for negative change', () {
        expect(PriceLimit.isLimitUp(-10.0), isFalse);
      });

      test('return false for null', () {
        expect(PriceLimit.isLimitUp(null), isFalse);
      });

      test('return true for value exceeding 10%', () {
        // 理論上不會超過 10%，但防禦性檢查
        expect(PriceLimit.isLimitUp(10.5), isTrue);
      });
    });

    group('isLimitDown', () {
      test('return true for -10%', () {
        expect(PriceLimit.isLimitDown(-10.0), isTrue);
      });

      test('return true for value within tolerance (-9.86%)', () {
        expect(PriceLimit.isLimitDown(-9.86), isTrue);
      });

      test('return true at exact tolerance boundary (-9.85%)', () {
        expect(PriceLimit.isLimitDown(-9.85), isTrue);
      });

      test('return false just below tolerance boundary (-9.84%)', () {
        expect(PriceLimit.isLimitDown(-9.84), isFalse);
      });

      test('return false for -9.5%', () {
        expect(PriceLimit.isLimitDown(-9.5), isFalse);
      });

      test('return false for positive change', () {
        expect(PriceLimit.isLimitDown(10.0), isFalse);
      });

      test('return false for null', () {
        expect(PriceLimit.isLimitDown(null), isFalse);
      });
    });
  });
}
