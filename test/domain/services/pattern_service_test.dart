import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/pattern_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/candlestick_data_generators.dart';
import '../../helpers/price_data_generators.dart';

void main() {
  final service = PatternService();

  // ==========================================
  // detectPatterns — 基本行為
  // ==========================================
  group('detectPatterns', () {
    test('returns empty list for empty input', () {
      expect(service.detectPatterns([]), isEmpty);
    });

    test('detects single-candle patterns', () {
      final doji = createDojiCandle(date: DateTime(2025, 1, 15), price: 100.0);
      final results = service.detectPatterns([doji]);

      expect(results, isNotEmpty);
      expect(results.any((r) => r.type == CandlePatternType.doji), isTrue);
    });

    test('detects multi-candle patterns with enough data', () {
      final candles = createMorningStarPattern(
        startDate: DateTime(2025, 1, 13),
      );
      final results = service.detectPatterns(candles);

      expect(
        results.any((r) => r.type == CandlePatternType.morningStar),
        isTrue,
      );
    });
  });

  // ==========================================
  // Doji 偵測
  // ==========================================
  group('doji detection', () {
    test('detects standard doji', () {
      // bodyRatio < 0.1, shadows not qualifying for gravestone/dragonfly/long-legged
      // Need: upper < range*0.3 to avoid long-legged
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 100.0,
        high: 100.8, // upper shadow = 0.8
        low: 98.0, // lower shadow = 2.0
        close: 100.2, // body = 0.2, range = 2.8, bodyRatio ≈ 0.07
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);

      expect(results.length, equals(1));
      expect(results.first.type, equals(CandlePatternType.doji));
      expect(results.first.confidence, equals(0.7));
      expect(results.first.description, contains('標準十字'));
    });

    test('detects gravestone doji (墓碑十字)', () {
      // 長上影線，極短下影線
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 100.0,
        high: 110.0, // upper shadow = 10
        low: 99.5, // lower shadow = 0.5
        close: 100.0, // body = 0, range = 10.5
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);

      expect(results.length, equals(1));
      expect(results.first.confidence, equals(0.85));
      expect(results.first.description, contains('墓碑'));
    });

    test('detects dragonfly doji (蜻蜓十字)', () {
      // 長下影線，極短上影線
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 100.0,
        high: 100.5, // upper shadow = 0.5
        low: 90.0, // lower shadow = 10
        close: 100.0, // body = 0, range = 10.5
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);

      expect(results.length, equals(1));
      expect(results.first.confidence, equals(0.85));
      expect(results.first.description, contains('蜻蜓'));
    });

    test('detects long-legged doji (長腳十字)', () {
      // 上下影線都長
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 100.0,
        high: 104.0, // upper shadow = 4
        low: 96.0, // lower shadow = 4
        close: 100.0, // body = 0, range = 8
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);

      expect(results.length, equals(1));
      expect(results.first.confidence, equals(0.75));
      expect(results.first.description, contains('長腳'));
    });

    test('returns null when range is zero', () {
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 100.0,
        high: 100.0,
        low: 100.0,
        close: 100.0,
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);

      expect(results.where((r) => r.type == CandlePatternType.doji), isEmpty);
    });
  });

  // ==========================================
  // Engulfing 偵測
  // ==========================================
  group('engulfing detection', () {
    test('detects bullish engulfing in downtrend', () {
      // 建立下降趨勢 + 多頭吞噬
      final downtrend = generateDowntrendPrices(
        days: 5,
        startPrice: 110.0,
        dailyLoss: 1.5,
      );
      final engulfing = createBullishEngulfingPair(
        prevDate: DateTime.now().subtract(const Duration(days: 1)),
        todayDate: DateTime.now(),
        basePrice: 100.0,
      );
      final prices = [...downtrend, engulfing.prev, engulfing.today];
      final results = service.detectPatterns(prices);

      final engulfingResult = results.firstWhere(
        (r) => r.type == CandlePatternType.bullishEngulfing,
      );
      expect(engulfingResult.confidence, equals(0.9));
      expect(engulfingResult.description, contains('底部反轉'));
    });

    test('detects bullish engulfing without trend (lower confidence)', () {
      final engulfing = createBullishEngulfingPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
      );
      final results = service.detectPatterns([engulfing.prev, engulfing.today]);

      final engulfingResult = results.firstWhere(
        (r) => r.type == CandlePatternType.bullishEngulfing,
      );
      expect(engulfingResult.confidence, equals(0.75));
    });

    test('detects bearish engulfing in uptrend', () {
      final uptrend = generateUptrendPrices(
        days: 5,
        startPrice: 90.0,
        dailyGain: 1.5,
      );
      final engulfing = createBearishEngulfingPair(
        prevDate: DateTime.now().subtract(const Duration(days: 1)),
        todayDate: DateTime.now(),
        basePrice: 100.0,
      );
      final prices = [...uptrend, engulfing.prev, engulfing.today];
      final results = service.detectPatterns(prices);

      final bearishResult = results.firstWhere(
        (r) => r.type == CandlePatternType.bearishEngulfing,
      );
      expect(bearishResult.confidence, equals(0.9));
    });

    test('detects bearish engulfing without trend', () {
      final engulfing = createBearishEngulfingPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
      );
      final results = service.detectPatterns([engulfing.prev, engulfing.today]);

      final bearishResult = results.firstWhere(
        (r) => r.type == CandlePatternType.bearishEngulfing,
      );
      expect(bearishResult.confidence, equals(0.75));
    });
  });

  // ==========================================
  // Hammer / HangingMan 偵測
  // ==========================================
  group('hammer and hanging man', () {
    test('detects hammer in downtrend', () {
      final downtrend = generateDowntrendPrices(
        days: 6,
        startPrice: 110.0,
        dailyLoss: 1.0,
      );
      final hammer = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...downtrend, hammer];
      final results = service.detectPatterns(prices);

      final hammerResult = results.firstWhere(
        (r) => r.type == CandlePatternType.hammer,
      );
      expect(hammerResult.confidence, equals(0.75));
      expect(hammerResult.description, contains('錘子線'));
    });

    test('detects hanging man in uptrend', () {
      final uptrend = generateUptrendPrices(
        days: 6,
        startPrice: 90.0,
        dailyGain: 1.0,
      );
      // Hanging man has same shape as hammer
      final hangingMan = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...uptrend, hangingMan];
      final results = service.detectPatterns(prices);

      final result = results.firstWhere(
        (r) => r.type == CandlePatternType.hangingMan,
      );
      expect(result.confidence, equals(0.7));
      expect(result.description, contains('吊人線'));
    });

    test('no hammer/hanging man without trend', () {
      // Flat prices — no trend
      final flat = generateFlatPrices(days: 5, basePrice: 100.0);
      final hammer = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...flat, hammer];
      final results = service.detectPatterns(prices);

      expect(
        results.any(
          (r) =>
              r.type == CandlePatternType.hammer ||
              r.type == CandlePatternType.hangingMan,
        ),
        isFalse,
      );
    });

    test('returns null for null OHLC', () {
      final candle = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: null,
        high: null,
        low: null,
        close: null,
        volume: 1000,
      );
      final results = service.detectPatterns([candle]);
      expect(results, isEmpty);
    });
  });

  // ==========================================
  // Gap 偵測
  // ==========================================
  group('gap detection', () {
    test('detects gap up', () {
      final gap = createGapUpPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
        gapSize: 2.0, // ~2% gap
      );
      final results = service.detectPatterns([gap.prev, gap.today]);

      final gapResult = results.firstWhere(
        (r) => r.type == CandlePatternType.gapUp,
      );
      expect(gapResult.confidence, equals(0.7));
      expect(gapResult.description, contains('跳空上漲'));
    });

    test('detects large gap up with high confidence', () {
      final gap = createGapUpPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
        gapSize: 5.0, // ~5% gap > 3% threshold
      );
      final results = service.detectPatterns([gap.prev, gap.today]);

      final gapResult = results.firstWhere(
        (r) => r.type == CandlePatternType.gapUp,
      );
      expect(gapResult.confidence, equals(0.9));
    });

    test('detects gap down', () {
      final gap = createGapDownPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
        gapSize: 2.0,
      );
      final results = service.detectPatterns([gap.prev, gap.today]);

      final gapResult = results.firstWhere(
        (r) => r.type == CandlePatternType.gapDown,
      );
      expect(gapResult.confidence, equals(0.7));
      expect(gapResult.description, contains('跳空下跌'));
    });

    test('detects large gap down with high confidence', () {
      final gap = createGapDownPair(
        prevDate: DateTime(2025, 1, 14),
        todayDate: DateTime(2025, 1, 15),
        gapSize: 5.0,
      );
      final results = service.detectPatterns([gap.prev, gap.today]);

      final gapResult = results.firstWhere(
        (r) => r.type == CandlePatternType.gapDown,
      );
      expect(gapResult.confidence, equals(0.9));
    });
  });

  // ==========================================
  // Star 偵測
  // ==========================================
  group('star detection', () {
    test('detects morning star', () {
      final candles = createMorningStarPattern(
        startDate: DateTime(2025, 1, 13),
      );
      final results = service.detectPatterns(candles);

      final starResult = results.firstWhere(
        (r) => r.type == CandlePatternType.morningStar,
      );
      expect(starResult.confidence, equals(0.85));
      expect(starResult.description, contains('晨星'));
    });

    test('detects evening star', () {
      final candles = createEveningStarPattern(
        startDate: DateTime(2025, 1, 13),
      );
      final results = service.detectPatterns(candles);

      final starResult = results.firstWhere(
        (r) => r.type == CandlePatternType.eveningStar,
      );
      expect(starResult.confidence, equals(0.85));
      expect(starResult.description, contains('暮星'));
    });

    test('no star when day2 body is too large', () {
      // Day2 has large body (not a star)
      final candles = [
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13),
          open: 105.0,
          high: 106.0,
          low: 99.0,
          close: 100.0, // bearish
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 14),
          open: 98.0,
          high: 99.0,
          low: 95.0,
          close: 95.5, // large body: 2.5/4 = 0.625 > 0.3
          volume: 500,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 15),
          open: 97.0,
          high: 104.0,
          low: 96.0,
          close: 103.0, // bullish
          volume: 1500,
        ),
      ];
      final results = service.detectPatterns(candles);

      expect(
        results.any(
          (r) =>
              r.type == CandlePatternType.morningStar ||
              r.type == CandlePatternType.eveningStar,
        ),
        isFalse,
      );
    });

    test('no morning star when day3 does not close above midpoint', () {
      final candles = [
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13),
          open: 105.0,
          high: 106.0,
          low: 99.0,
          close: 100.0, // bearish, midpoint = 102.5
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 14),
          open: 98.0,
          high: 99.0,
          low: 97.0,
          close: 98.2, // small body star
          volume: 500,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 15),
          open: 99.0,
          high: 102.0,
          low: 98.5,
          close: 101.0, // bullish but < midpoint 102.5
          volume: 1500,
        ),
      ];
      final results = service.detectPatterns(candles);

      expect(
        results.any((r) => r.type == CandlePatternType.morningStar),
        isFalse,
      );
    });
  });

  // ==========================================
  // Three Soldiers / Crows 偵測
  // ==========================================
  group('three soldiers and crows', () {
    test('detects three white soldiers (strict)', () {
      final candles = createThreeWhiteSoldiersPattern(
        startDate: DateTime(2025, 1, 13),
      );
      final results = service.detectPatterns(candles);

      final result = results.firstWhere(
        (r) => r.type == CandlePatternType.threeWhiteSoldiers,
      );
      expect(result.confidence, equals(0.85));
      expect(result.description, contains('強勢上漲'));
    });

    test('detects three white soldiers (loose) when opens outside body', () {
      // Three bullish candles with ascending closes but opens clearly outside prev body
      final candles = [
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13),
          open: 100.0,
          high: 103.5,
          low: 99.5,
          close: 103.0, // bullish, body=3
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 14),
          open: 98.0, // opens below day1 open (100), outside body
          high: 107.5,
          low: 97.5,
          close: 107.0, // bullish, body=9
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 15),
          open: 110.0, // opens above day2 close * 1.01 = 108.07, outside body
          high: 114.5,
          low: 109.5,
          close: 114.0, // bullish, body=4
          volume: 1000,
        ),
      ];
      final results = service.detectPatterns(candles);

      final result = results.firstWhere(
        (r) => r.type == CandlePatternType.threeWhiteSoldiers,
      );
      // Opens clearly outside prev body → loose version
      expect(result.confidence, equals(0.7));
    });

    test('detects three black crows (strict)', () {
      final candles = createThreeBlackCrowsPattern(
        startDate: DateTime(2025, 1, 13),
      );
      final results = service.detectPatterns(candles);

      final result = results.firstWhere(
        (r) => r.type == CandlePatternType.threeBlackCrows,
      );
      expect(result.confidence, equals(0.85));
      expect(result.description, contains('強勢下跌'));
    });

    test('no pattern when direction is mixed', () {
      final candles = [
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13),
          open: 100.0,
          high: 103.5,
          low: 99.5,
          close: 103.0, // bullish
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 14),
          open: 104.0,
          high: 105.0,
          low: 101.0,
          close: 101.5, // bearish
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 15),
          open: 102.0,
          high: 105.5,
          low: 101.5,
          close: 105.0, // bullish
          volume: 1000,
        ),
      ];
      final results = service.detectPatterns(candles);

      expect(
        results.any(
          (r) =>
              r.type == CandlePatternType.threeWhiteSoldiers ||
              r.type == CandlePatternType.threeBlackCrows,
        ),
        isFalse,
      );
    });

    test('no pattern when body ratio too small', () {
      // Three bullish but body/range < 0.3
      final candles = List.generate(3, (i) {
        final base = 100.0 + (i * 2);
        return DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13 + i),
          open: base,
          high: base + 10.0, // range = 10
          low: base - 0.5,
          close: base + 0.5, // body = 0.5, ratio = 0.5/10.5 < 0.3
          volume: 1000,
        );
      });
      final results = service.detectPatterns(candles);

      expect(
        results.any((r) => r.type == CandlePatternType.threeWhiteSoldiers),
        isFalse,
      );
    });
  });

  // ==========================================
  // Trend helpers
  // ==========================================
  group('trend detection helpers', () {
    test('isRecentDowntrend requires 5+ candles and >= 3% decline', () {
      // 5 candles declining from 110 to 105 (4.5% decline)
      final downtrend = generateDowntrendPrices(
        days: 5,
        startPrice: 110.0,
        dailyLoss: 1.5,
      );
      final hammer = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...downtrend, hammer];
      final results = service.detectPatterns(prices);

      // Should detect hammer (downtrend present)
      expect(results.any((r) => r.type == CandlePatternType.hammer), isTrue);
    });

    test('isRecentDowntrend returns false with < 5 candles', () {
      // Only 3 candles — not enough for trend detection
      final downtrend = generateDowntrendPrices(days: 3, startPrice: 110.0);
      final hammer = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...downtrend, hammer];
      final results = service.detectPatterns(prices);

      // No hammer since not enough candles for trend
      expect(results.any((r) => r.type == CandlePatternType.hammer), isFalse);
    });

    test('isRecentUptrend requires 5+ candles and >= 3% rise', () {
      // 5 candles rising from 90 to 97.5 (8.3% rise)
      final uptrend = generateUptrendPrices(
        days: 5,
        startPrice: 90.0,
        dailyGain: 1.5,
      );
      final hangingMan = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...uptrend, hangingMan];
      final results = service.detectPatterns(prices);

      expect(
        results.any((r) => r.type == CandlePatternType.hangingMan),
        isTrue,
      );
    });

    test('no trend detected with flat prices', () {
      final flat = generateFlatPrices(days: 6, basePrice: 100.0);
      final hammer = createHammerCandle(date: DateTime.now(), close: 100.0);
      final prices = [...flat, hammer];
      final results = service.detectPatterns(prices);

      expect(
        results.any(
          (r) =>
              r.type == CandlePatternType.hammer ||
              r.type == CandlePatternType.hangingMan,
        ),
        isFalse,
      );
    });
  });

  // ==========================================
  // Null safety
  // ==========================================
  group('null safety', () {
    test('gap returns null for null OHLC', () {
      final yesterday = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 14),
        open: 100.0,
        high: null,
        low: null,
        close: null,
        volume: 1000,
      );
      final today = DailyPriceEntry(
        symbol: 'TEST',
        date: DateTime(2025, 1, 15),
        open: 110.0,
        high: 115.0,
        low: 108.0,
        close: 112.0,
        volume: 1000,
      );
      final results = service.detectPatterns([yesterday, today]);

      expect(results.any((r) => r.type == CandlePatternType.gapUp), isFalse);
    });

    test('star returns null when any day has null values', () {
      final candles = [
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 13),
          open: 105.0,
          high: 106.0,
          low: 99.0,
          close: 100.0,
          volume: 1000,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 14),
          open: null, // null
          high: 99.0,
          low: 97.0,
          close: 98.0,
          volume: 500,
        ),
        DailyPriceEntry(
          symbol: 'TEST',
          date: DateTime(2025, 1, 15),
          open: 99.0,
          high: 104.0,
          low: 98.5,
          close: 103.0,
          volume: 1500,
        ),
      ];
      final results = service.detectPatterns(candles);

      expect(
        results.any(
          (r) =>
              r.type == CandlePatternType.morningStar ||
              r.type == CandlePatternType.eveningStar,
        ),
        isFalse,
      );
    });
  });
}
