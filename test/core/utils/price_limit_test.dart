import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_limit.dart';

void main() {
  group('PriceLimit', () {
    group('isLimitUp', () {
      test('should return true for +10%', () {
        expect(PriceLimit.isLimitUp(10.0), isTrue);
      });

      test('should return true for value within tolerance (+9.85%)', () {
        expect(PriceLimit.isLimitUp(9.86), isTrue);
      });

      test('should return false for +9.5%', () {
        expect(PriceLimit.isLimitUp(9.5), isFalse);
      });

      test('should return false for negative change', () {
        expect(PriceLimit.isLimitUp(-10.0), isFalse);
      });

      test('should return false for null', () {
        expect(PriceLimit.isLimitUp(null), isFalse);
      });

      test('should return true for value exceeding 10%', () {
        // 理論上不會超過 10%，但防禦性檢查
        expect(PriceLimit.isLimitUp(10.5), isTrue);
      });
    });

    group('isLimitDown', () {
      test('should return true for -10%', () {
        expect(PriceLimit.isLimitDown(-10.0), isTrue);
      });

      test('should return true for value within tolerance (-9.85%)', () {
        expect(PriceLimit.isLimitDown(-9.86), isTrue);
      });

      test('should return false for -9.5%', () {
        expect(PriceLimit.isLimitDown(-9.5), isFalse);
      });

      test('should return false for positive change', () {
        expect(PriceLimit.isLimitDown(10.0), isFalse);
      });

      test('should return false for null', () {
        expect(PriceLimit.isLimitDown(null), isFalse);
      });
    });

    group('isAtLimit', () {
      test('should return true for limit up', () {
        expect(PriceLimit.isAtLimit(10.0), isTrue);
      });

      test('should return true for limit down', () {
        expect(PriceLimit.isAtLimit(-10.0), isTrue);
      });

      test('should return false for normal change', () {
        expect(PriceLimit.isAtLimit(5.0), isFalse);
      });

      test('should return false for null', () {
        expect(PriceLimit.isAtLimit(null), isFalse);
      });

      test('should return false for zero', () {
        expect(PriceLimit.isAtLimit(0.0), isFalse);
      });
    });
  });
}
