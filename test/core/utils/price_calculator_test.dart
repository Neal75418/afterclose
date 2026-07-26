import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  group('PriceCalculator', () {
    group('calculatePriceChange', () {
      test(
        'calculate positive price change when history includes latest date',
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
        'calculate negative price change when history includes latest date',
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
        'calculate price change when history does NOT include latest date',
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

      test('return null when latestPrice is null', () {
        final history = generatePriceHistoryFromList(
          prices: [100.0, 100.0, 100.0, 100.0, 100.0],
        );

        final result = PriceCalculator.calculatePriceChange(history, null);

        expect(result, isNull);
      });

      test(
        'return null when history has less than 2 entries and includes latest',
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

      test('work with single entry history when latest date is different', () {
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
      });

      test('return null when previous close is zero', () {
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

      test('use priceChange field when available', () {
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

      test('use priceChange even when history has gaps', () {
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

      test('fall back to history when priceChange is null', () {
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

      test('return null when priceChange causes negative prevClose', () {
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

    group('calculatePriceChangesBatch', () {
      test('calculate price changes for multiple symbols', () {
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

      test('return null for symbols with no history', () {
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

      test('return null for symbols with empty history', () {
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

      test('use latestPrice.priceChange even when history is null', () {
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

      test('use latestPrice.priceChange even when history is empty', () {
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

      test('handle mixed valid and invalid data', () {
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

    group('marketUptrendOrNull（規則 gate 用、資料不足回 null）', () {
      // count 檔，每檔 len 根；最後一根對 [len-1-120] 漲 retPct%
      Map<String, List<DailyPriceEntry>> universe(
        int count,
        double retPct,
        int len,
      ) {
        return {
          for (var i = 0; i < count; i++)
            's$i': [
              ...List.generate(
                len - 1,
                (d) => createTestPrice(
                  symbol: 's$i',
                  close: 100,
                  date: DateTime(2025).add(Duration(days: d)),
                ),
              ),
              createTestPrice(
                symbol: 's$i',
                close: 100 * (1 + retPct / 100),
                date: DateTime(2025).add(Duration(days: len)),
              ),
            ],
        };
      }

      // ================================================================
      // 半市場日的橫斷面污染（P1-8 (A)）
      //
      // 本函式以 `history.last` 當「今日」平均全市場 N 日報酬。單一市場
      // 資料缺漏時（實測 TWSE 1225 / TPEx 904），有資料那半邊的 last 是
      // 今日、缺漏那半邊的 last 是昨日 —— regime 會變成「今日的一半」
      // 混「昨日的另一半」的平均，是評分裡唯一真正被半市場污染的計算。
      //
      // 修法與 classifyCandidate 的 staleBar 同一套新鮮度概念：只計入
      // 最後一根 bar 就是評分日的股票。半市場仍有 1225 檔遠高於門檻 50，
      // regime 照常算得出來，而且變成正確的。
      // ================================================================

      /// count 檔，最後一根 bar 停在 [endDate]，對 120 根前漲 retPct%
      Map<String, List<DailyPriceEntry>> universeEndingAt(
        int count,
        double retPct,
        DateTime endDate, {
        String prefix = 's',
      }) {
        const len = 121;
        return {
          for (var i = 0; i < count; i++)
            '$prefix$i': [
              ...List.generate(
                len - 1,
                (d) => createTestPrice(
                  symbol: '$prefix$i',
                  close: 100,
                  date: endDate.subtract(Duration(days: len - 1 - d)),
                ),
              ),
              createTestPrice(
                symbol: '$prefix$i',
                close: 100 * (1 + retPct / 100),
                date: endDate,
              ),
            ],
        };
      }

      test('🚨 asOf 給定時只計入當日 bar，陳舊的一半不得混入平均', () {
        final today = DateTime(2026, 7, 24);
        // 今日這半邊大跌 -10%，昨日那半邊「看起來」大漲 +30%
        final fresh = universeEndingAt(60, -10, today, prefix: 'fresh');
        final stale = universeEndingAt(
          60,
          30,
          today.subtract(const Duration(days: 1)),
          prefix: 'stale',
        );

        expect(
          PriceCalculator.marketUptrendOrNull(
            {...fresh, ...stale},
            120,
            asOf: today,
          ),
          isFalse,
          reason: '只有今日 bar 該進平均；混入昨日會把下跌 regime 讀成上漲',
        );
      });

      test('過濾後有效股不足 50 → null（維持 permissive，不誤殺訊號）', () {
        final today = DateTime(2026, 7, 24);
        final fresh = universeEndingAt(40, 10, today, prefix: 'fresh');
        final stale = universeEndingAt(
          60,
          10,
          today.subtract(const Duration(days: 1)),
          prefix: 'stale',
        );

        expect(
          PriceCalculator.marketUptrendOrNull(
            {...fresh, ...stale},
            120,
            asOf: today,
          ),
          isNull,
        );
      });

      test('asOf 帶時分秒仍視為同一天（逐欄比 y/m/d）', () {
        final today = DateTime(2026, 7, 24);
        expect(
          PriceCalculator.marketUptrendOrNull(
            universeEndingAt(60, 10, today),
            120,
            asOf: DateTime(2026, 7, 24, 15, 30),
          ),
          isTrue,
        );
      });

      test('省略 asOf 時不過濾（向後相容）', () {
        final today = DateTime(2026, 7, 24);
        final stale = universeEndingAt(
          60,
          10,
          today.subtract(const Duration(days: 1)),
        );

        expect(PriceCalculator.marketUptrendOrNull(stale, 120), isTrue);
      });

      test('有效股 < 50 → null（未知、caller 不擋）', () {
        expect(
          PriceCalculator.marketUptrendOrNull(universe(40, 10, 121), 120),
          isNull,
        );
      });

      test('≥ 50 檔且平均報酬 > 0 → true', () {
        expect(
          PriceCalculator.marketUptrendOrNull(universe(60, 10, 121), 120),
          isTrue,
        );
      });

      test('≥ 50 檔且平均報酬 < 0 → false', () {
        expect(
          PriceCalculator.marketUptrendOrNull(universe(60, -10, 121), 120),
          isFalse,
        );
      });

      test('歷史不足 lookback+1 被略過 → 有效股歸零 → null', () {
        expect(
          PriceCalculator.marketUptrendOrNull(universe(60, 10, 100), 120),
          isNull,
        );
      });
    });
  });
}
