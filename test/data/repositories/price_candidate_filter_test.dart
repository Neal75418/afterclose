import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/repositories/price_candidate_filter.dart';

/// Simple test data class to exercise the generic filter
class _MockPrice {
  const _MockPrice({required this.code, this.close, this.change, this.volume});

  final String code;
  final double? close;
  final double? change;
  final double? volume;
}

void main() {
  group('quickFilterPrices', () {
    List<String> filter(List<_MockPrice> prices) {
      return quickFilterPrices(
        prices,
        getCode: (p) => p.code,
        getClose: (p) => p.close,
        getChange: (p) => p.change,
        getVolume: (p) => p.volume,
      );
    }

    test('should return valid stocks sorted by volatility', () {
      final prices = [
        const _MockPrice(code: '2330', close: 600, change: 6, volume: 500000),
        const _MockPrice(code: '2317', close: 100, change: 5, volume: 200000),
        const _MockPrice(code: '2454', close: 800, change: 40, volume: 300000),
      ];

      final result = filter(prices);

      // 2317: 5/(100-5)=5.26%, 2454: 40/(800-40)=5.26%, 2330: 6/(600-6)=1.01%
      // 2317 and 2454 have higher volatility than 2330
      expect(result.length, 3);
      expect(result.last, '2330'); // lowest volatility
    });

    test('should skip stocks with null close', () {
      final prices = [
        const _MockPrice(code: '2330', close: null, change: 5, volume: 200000),
        const _MockPrice(code: '2317', close: 100, change: 5, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, ['2317']);
    });

    test('should skip stocks with close <= 0', () {
      final prices = [
        const _MockPrice(code: '2330', close: 0, change: 5, volume: 200000),
        const _MockPrice(code: '2317', close: -10, change: 5, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, isEmpty);
    });

    test('should skip stocks with null change', () {
      final prices = [
        const _MockPrice(
          code: '2330',
          close: 100,
          change: null,
          volume: 200000,
        ),
      ];

      final result = filter(prices);

      expect(result, isEmpty);
    });

    test('should skip invalid stock codes (warrants, TDR, etc)', () {
      final prices = [
        // Valid: 4-digit or 00xxx
        const _MockPrice(code: '2330', close: 100, change: 5, volume: 200000),
        // Invalid: warrant-like codes
        const _MockPrice(code: '23300', close: 100, change: 5, volume: 200000),
        const _MockPrice(code: 'ABC', close: 100, change: 5, volume: 200000),
        const _MockPrice(code: '23301P', close: 100, change: 5, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, ['2330']);
    });

    test('should skip stocks with prevClose <= 0', () {
      // prevClose = close - change = 100 - 150 = -50
      final prices = [
        const _MockPrice(code: '2330', close: 100, change: 150, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, isEmpty);
    });

    test('should skip stocks with low volume', () {
      // minQuickFilterVolumeShares = 100000
      final prices = [
        const _MockPrice(code: '2330', close: 100, change: 5, volume: 50000),
        const _MockPrice(code: '2317', close: 100, change: 5, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, ['2317']);
    });

    test('should skip stocks with null volume (treated as 0)', () {
      final prices = [
        const _MockPrice(code: '2330', close: 100, change: 5, volume: null),
      ];

      final result = filter(prices);

      expect(result, isEmpty);
    });

    test('should return empty list for empty input', () {
      final result = filter([]);

      expect(result, isEmpty);
    });

    test('should handle negative change (declining stocks)', () {
      final prices = [
        const _MockPrice(code: '2330', close: 95, change: -5, volume: 200000),
      ];

      final result = filter(prices);

      // prevClose = 95 - (-5) = 100, changePercent = 5/100 * 100 = 5%
      expect(result, ['2330']);
    });

    test('should sort by absolute change percent descending', () {
      final prices = [
        // 1/(100-1) = 1.01%
        const _MockPrice(code: '1001', close: 100, change: 1, volume: 200000),
        // 10/(100-10) = 11.11%
        const _MockPrice(code: '1002', close: 100, change: 10, volume: 200000),
        // 5/(100-(-5)) = 4.76%
        const _MockPrice(code: '1003', close: 100, change: -5, volume: 200000),
      ];

      final result = filter(prices);

      expect(result, ['1002', '1003', '1001']);
    });

    test('should accept ETF codes (00xxx)', () {
      final prices = [
        const _MockPrice(code: '0050', close: 150, change: 3, volume: 500000),
        const _MockPrice(
          code: '00878',
          close: 20,
          change: 0.2,
          volume: 1000000,
        ),
      ];

      final result = filter(prices);

      expect(result.length, 2);
      expect(result, contains('0050'));
      expect(result, contains('00878'));
    });
  });
}
