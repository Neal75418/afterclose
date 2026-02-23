import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  group('PriceCalculator', () {
    group('calculatePriceChange', () {
      test(
        'should calculate positive price change when history includes latest date',
        () {
          final now = DateTime.now();
          final history = generatePriceHistoryFromList(
            prices: [100.0, 100.0, 100.0, 100.0, 105.0],
            startDate: now.subtract(const Duration(days: 4)),
          );
          final latestPrice = createTestPrice(close: 105.0, date: now);

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
          final history = generatePriceHistoryFromList(
            prices: [100.0, 100.0, 100.0, 100.0, 95.0],
            startDate: now.subtract(const Duration(days: 4)),
          );
          final latestPrice = createTestPrice(close: 95.0, date: now);

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
          final history = generatePriceHistoryFromList(
            prices: [100.0, 100.0, 100.0, 100.0],
            startDate: yesterday.subtract(const Duration(days: 3)),
          );
          // Latest price is today
          final latestPrice = createTestPrice(close: 105.0, date: now);

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
        final history = generatePriceHistoryFromList(
          prices: [100.0, 100.0, 100.0, 100.0, 100.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, null);

        expect(result, isNull);
      });

      test(
        'should return null when history has less than 2 entries and includes latest',
        () {
          final now = DateTime.now();
          final history = generatePriceHistoryFromList(
            prices: [100.0],
            startDate: now,
          );
          final latestPrice = createTestPrice(close: 100.0, date: now);

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
          final history = generatePriceHistoryFromList(
            prices: [100.0],
            startDate: yesterday,
          );
          final latestPrice = createTestPrice(close: 110.0, date: now);

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
        final history = generatePriceHistoryFromList(
          prices: [100.0, 0.0, 100.0],
          startDate: now.subtract(const Duration(days: 2)),
        );
        final latestPrice = createTestPrice(close: 100.0, date: now);

        final result = PriceCalculator.calculatePriceChange(
          history,
          latestPrice,
        );

        expect(result, isNull);
      });

      test('should use priceChange field when available', () {
        final now = DateTime.now();
        // priceChange = 5.0 表示漲 5 元，前一日收盤 = 105 - 5 = 100
        final latestPrice = createTestPrice(
          close: 105.0,
          date: now,
          priceChange: 5.0,
        );

        final result = PriceCalculator.calculatePriceChange([], latestPrice);

        expect(result, isNotNull);
        expect(result, closeTo(5.0, 0.01)); // (5 / 100) * 100 = 5%
      });

      test('should use priceChange even when history has gaps', () {
        final now = DateTime.now();
        // 歷史資料有缺口：只有 3 天前和今天，缺少昨天
        final history = [
          createTestPrice(
            close: 98.0,
            date: now.subtract(const Duration(days: 3)),
          ),
          createTestPrice(
            close: 105.0,
            date: now,
            priceChange: 5.0, // API 告訴我們漲 5 元（相對昨天的 100）
          ),
        ];

        final latestPrice = history.last;

        final result = PriceCalculator.calculatePriceChange(
          history,
          latestPrice,
        );

        // 應使用 priceChange 計算：(5 / 100) * 100 = 5%
        // 而非使用錯誤的歷史比較：(105 - 98) / 98 * 100 = 7.14%
        expect(result, closeTo(5.0, 0.01));
      });

      test('should fall back to history when priceChange is null', () {
        final now = DateTime.now();
        final history = generatePriceHistoryFromList(
          prices: [100.0, 100.0, 100.0, 100.0, 105.0],
          startDate: now.subtract(const Duration(days: 4)),
        );
        // 無 priceChange（如 FinMind 歷史資料）
        final latestPrice = createTestPrice(close: 105.0, date: now);

        final result = PriceCalculator.calculatePriceChange(
          history,
          latestPrice,
        );

        expect(result, isNotNull);
        expect(result, closeTo(5.0, 0.01));
      });

      test('should return null when priceChange causes negative prevClose', () {
        final now = DateTime.now();
        // close = 5, priceChange = 10 → prevClose = 5 - 10 = -5（不合理）
        final latestPrice = createTestPrice(
          close: 5.0,
          date: now,
          priceChange: 10.0,
        );

        final result = PriceCalculator.calculatePriceChange([], latestPrice);

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
          'AAAA': generatePriceHistoryFromList(
            prices: [100.0, 100.0, 100.0, 100.0, 105.0],
            symbol: 'AAAA',
          ),
          'BBBB': generatePriceHistoryFromList(
            prices: [200.0, 200.0, 200.0, 200.0, 190.0],
            symbol: 'BBBB',
          ),
        };

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 105.0,
            date: DateTime.now(),
          ),
          'BBBB': createTestPrice(
            symbol: 'BBBB',
            close: 190.0,
            date: DateTime.now(),
          ),
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
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 105.0,
            date: DateTime.now(),
          ),
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
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 105.0,
            date: DateTime.now(),
          ),
        };

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], isNull);
      });

      test('should use latestPrice.priceChange even when history is null', () {
        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 105.0,
            date: DateTime.now(),
            priceChange: 5.0,
          ),
        };

        // history map 完全沒有 AAAA（history == null 的情境）
        final priceHistories = <String, List<DailyPriceEntry>>{};

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        // 應使用 API 提供的 priceChange 計算：(5 / 100) * 100 = 5%
        expect(result['AAAA'], closeTo(5.0, 0.01));
      });

      test('should use latestPrice.priceChange even when history is empty', () {
        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 105.0,
            date: DateTime.now(),
            priceChange: 5.0,
          ),
        };

        final priceHistories = <String, List<DailyPriceEntry>>{'AAAA': []};

        final result = PriceCalculator.calculatePriceChangesBatch(
          priceHistories,
          latestPrices,
        );

        expect(result['AAAA'], closeTo(5.0, 0.01));
      });

      test('should handle mixed valid and invalid data', () {
        final priceHistories = <String, List<DailyPriceEntry>>{
          'AAAA': generatePriceHistoryFromList(
            prices: [100.0, 100.0, 100.0, 100.0, 110.0],
            symbol: 'AAAA',
          ),
          'BBBB': [], // Empty history
        };

        final latestPrices = <String, DailyPriceEntry>{
          'AAAA': createTestPrice(
            symbol: 'AAAA',
            close: 110.0,
            date: DateTime.now(),
          ),
          'BBBB': createTestPrice(
            symbol: 'BBBB',
            close: 100.0,
            date: DateTime.now(),
          ),
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
