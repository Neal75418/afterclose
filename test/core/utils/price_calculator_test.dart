import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';

void main() {
  group('PriceCalculator', () {
    group('calculatePriceChange', () {
      test(
        'should calculate positive price change when history includes latest date',
        () {
          final now = DateTime.now();
          final history = _generatePriceHistory(
            days: 5,
            prices: [100.0, 100.0, 100.0, 100.0, 105.0],
            startDate: now.subtract(const Duration(days: 4)),
          );
          final latestPrice = _createPrice(close: 105.0, date: now);

          final result = PriceCalculator.calculatePriceChange(
            history,
            latestPrice,
          );

          expect(result, isNotNull);
          expect(result, closeTo(5.0, 0.01)); // 5% increase from 100 to 105
        },
      );

      test(
        'should calculate negative price change when history includes latest date',
        () {
          final now = DateTime.now();
          final history = _generatePriceHistory(
            days: 5,
            prices: [100.0, 100.0, 100.0, 100.0, 95.0],
            startDate: now.subtract(const Duration(days: 4)),
          );
          final latestPrice = _createPrice(close: 95.0, date: now);

          final result = PriceCalculator.calculatePriceChange(
            history,
            latestPrice,
          );

          expect(result, isNotNull);
          expect(result, closeTo(-5.0, 0.01)); // 5% decrease from 100 to 95
        },
      );

      test(
        'should calculate price change when history does NOT include latest date',
        () {
          final now = DateTime.now();
          final yesterday = now.subtract(const Duration(days: 1));
          // History only goes up to yesterday
          final history = _generatePriceHistory(
            days: 4,
            prices: [100.0, 100.0, 100.0, 100.0],
            startDate: yesterday.subtract(const Duration(days: 3)),
          );
          // Latest price is today
          final latestPrice = _createPrice(close: 105.0, date: now);

          final result = PriceCalculator.calculatePriceChange(
            history,
            latestPrice,
          );

          expect(result, isNotNull);
          // Should use history.last (100.0) as previous close, not history[length-2]
          expect(result, closeTo(5.0, 0.01)); // 5% increase from 100 to 105
        },
      );

      test('should return null when latestPrice is null', () {
        final history = _generatePriceHistory(
          days: 5,
          prices: [100.0, 100.0, 100.0, 100.0, 100.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, null);

        expect(result, isNull);
      });

      test(
        'should return null when history has less than 2 entries and includes latest',
        () {
          final now = DateTime.now();
          final history = _generatePriceHistory(
            days: 1,
            prices: [100.0],
            startDate: now,
          );
          final latestPrice = _createPrice(close: 100.0, date: now);

          final result = PriceCalculator.calculatePriceChange(
            history,
            latestPrice,
          );

          expect(result, isNull);
        },
      );

      test(
        'should work with single entry history when latest date is different',
        () {
          final now = DateTime.now();
          final yesterday = now.subtract(const Duration(days: 1));
          final history = _generatePriceHistory(
            days: 1,
            prices: [100.0],
            startDate: yesterday,
          );
          final latestPrice = _createPrice(close: 110.0, date: now);

          final result = PriceCalculator.calculatePriceChange(
            history,
            latestPrice,
          );

          expect(result, isNotNull);
          expect(result, closeTo(10.0, 0.01)); // 10% increase
        },
      );

      test('should return null when previous close is zero', () {
        final now = DateTime.now();
        final history = _generatePriceHistory(
          days: 3,
          prices: [100.0, 0.0, 100.0],
          startDate: now.subtract(const Duration(days: 2)),
        );
        final latestPrice = _createPrice(close: 100.0, date: now);

        final result = PriceCalculator.calculatePriceChange(
          history,
          latestPrice,
        );

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
  DateTime? startDate,
}) {
  final start = startDate ?? DateTime.now().subtract(Duration(days: days - 1));
  return List.generate(days, (i) {
    return _createPrice(
      symbol: symbol,
      date: start.add(Duration(days: i)),
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
