import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';

void main() {
  group('PriceCalculator', () {
    group('calculatePriceChange', () {
      test('should calculate positive price change', () {
        final history = _generatePriceHistory(
          days: 5,
          prices: [100.0, 100.0, 100.0, 100.0, 105.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, 105.0);

        expect(result, isNotNull);
        expect(result, closeTo(5.0, 0.01)); // 5% increase
      });

      test('should calculate negative price change', () {
        final history = _generatePriceHistory(
          days: 5,
          prices: [100.0, 100.0, 100.0, 100.0, 95.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, 95.0);

        expect(result, isNotNull);
        expect(result, closeTo(-5.0, 0.01)); // 5% decrease
      });

      test('should return null when latestClose is null', () {
        final history = _generatePriceHistory(
          days: 5,
          prices: [100.0, 100.0, 100.0, 100.0, 100.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, null);

        expect(result, isNull);
      });

      test('should return null when history has less than 2 entries', () {
        final history = _generatePriceHistory(days: 1, prices: [100.0]);

        final result = PriceCalculator.calculatePriceChange(history, 100.0);

        expect(result, isNull);
      });

      test('should return null when previous close is zero', () {
        final history = _generatePriceHistory(
          days: 3,
          prices: [100.0, 0.0, 100.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, 100.0);

        expect(result, isNull);
      });
    });

    group('calculatePriceChangeFromPrices', () {
      test('should calculate price change from two prices', () {
        final result = PriceCalculator.calculatePriceChangeFromPrices(
          105.0,
          100.0,
        );

        expect(result, isNotNull);
        expect(result, closeTo(5.0, 0.01));
      });

      test('should return null when current price is null', () {
        final result = PriceCalculator.calculatePriceChangeFromPrices(
          null,
          100.0,
        );

        expect(result, isNull);
      });

      test('should return null when previous price is null', () {
        final result = PriceCalculator.calculatePriceChangeFromPrices(
          105.0,
          null,
        );

        expect(result, isNull);
      });

      test('should return null when previous price is zero', () {
        final result = PriceCalculator.calculatePriceChangeFromPrices(
          105.0,
          0.0,
        );

        expect(result, isNull);
      });
    });

    group('calculatePriceChangesBatch', () {
      test('should calculate price changes for multiple symbols', () {
        final priceHistories = <String, List<DailyPriceEntry>>{
          'AAAA': _generatePriceHistory(
            days: 5,
            prices: [100.0, 100.0, 100.0, 100.0, 105.0],
            symbol: 'AAAA',
          ),
          'BBBB': _generatePriceHistory(
            days: 5,
            prices: [200.0, 200.0, 200.0, 200.0, 190.0],
            symbol: 'BBBB',
          ),
        };

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': _createPrice(symbol: 'AAAA', close: 105.0),
          'BBBB': _createPrice(symbol: 'BBBB', close: 190.0),
        };

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], closeTo(5.0, 0.01));
        expect(result['BBBB'], closeTo(-5.0, 0.01));
      });

      test('should return null for symbols with no history', () {
        final priceHistories = <String, List<DailyPriceEntry>>{};

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': _createPrice(symbol: 'AAAA', close: 105.0),
        };

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], isNull);
      });

      test('should return null for symbols with empty history', () {
        final priceHistories = <String, List<DailyPriceEntry>>{'AAAA': []};

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': _createPrice(symbol: 'AAAA', close: 105.0),
        };

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], isNull);
      });

      test('should handle mixed valid and invalid data', () {
        final priceHistories = <String, List<DailyPriceEntry>>{
          'AAAA': _generatePriceHistory(
            days: 5,
            prices: [100.0, 100.0, 100.0, 100.0, 110.0],
            symbol: 'AAAA',
          ),
          'BBBB': [], // Empty history
        };

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': _createPrice(symbol: 'AAAA', close: 110.0),
          'BBBB': _createPrice(symbol: 'BBBB', close: 100.0),
        };

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], closeTo(10.0, 0.01));
        expect(result['BBBB'], isNull);
      });
    });
  });
}

// ==========================================
// Test Helpers
// ==========================================

List<DailyPriceEntry> _generatePriceHistory({
  required int days,
  required List<double> prices,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    return _createPrice(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      close: prices[i],
    );
  });
}

DailyPriceEntry _createPrice({
  String symbol = 'TEST',
  DateTime? date,
  double? close,
}) {
  return DailyPriceEntry(
    symbol: symbol,
    date: date ?? DateTime.now(),
    open: close,
    high: close != null ? close * 1.01 : null,
    low: close != null ? close * 0.99 : null,
    close: close,
    volume: 1000,
  );
}
