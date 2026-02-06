import 'dart:math';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late TechnicalIndicatorService service;

  setUp(() {
    service = TechnicalIndicatorService();
  });

  // ==========================================
  // calculateSMA
  // ==========================================

  group('calculateSMA', () {
    test('calculates correct SMA values', () {
      final prices = [10.0, 20.0, 30.0, 40.0, 50.0];
      final result = service.calculateSMA(prices, 3);

      expect(result.length, equals(5));
      expect(result[0], isNull);
      expect(result[1], isNull);
      expect(result[2], closeTo(20.0, 0.001)); // (10+20+30)/3
      expect(result[3], closeTo(30.0, 0.001)); // (20+30+40)/3
      expect(result[4], closeTo(40.0, 0.001)); // (30+40+50)/3
    });

    test('returns empty list for empty input', () {
      expect(service.calculateSMA([], 3), isEmpty);
    });

    test('returns empty list for period <= 0', () {
      expect(service.calculateSMA([1.0, 2.0], 0), isEmpty);
      expect(service.calculateSMA([1.0, 2.0], -1), isEmpty);
    });

    test('returns all null when period > data length', () {
      final result = service.calculateSMA([1.0, 2.0], 5);
      expect(result.length, equals(2));
      expect(result[0], isNull);
      expect(result[1], isNull);
    });

    test('period = 1 returns each price', () {
      final prices = [5.0, 10.0, 15.0];
      final result = service.calculateSMA(prices, 1);
      expect(result, equals([5.0, 10.0, 15.0]));
    });

    test('period equals data length returns single value', () {
      final prices = [10.0, 20.0, 30.0];
      final result = service.calculateSMA(prices, 3);
      expect(result[0], isNull);
      expect(result[1], isNull);
      expect(result[2], closeTo(20.0, 0.001));
    });

    test('handles constant prices correctly', () {
      final prices = List.filled(10, 50.0);
      final result = service.calculateSMA(prices, 5);
      for (int i = 4; i < 10; i++) {
        expect(result[i], closeTo(50.0, 0.001));
      }
    });
  });

  // ==========================================
  // calculateEMA
  // ==========================================

  group('calculateEMA', () {
    test('first EMA equals SMA', () {
      final prices = [10.0, 20.0, 30.0, 40.0, 50.0];
      final ema = service.calculateEMA(prices, 3);
      final sma = service.calculateSMA(prices, 3);

      // First non-null value should equal SMA
      expect(ema[2], closeTo(sma[2]!, 0.001));
    });

    test('returns empty list for empty input', () {
      expect(service.calculateEMA([], 3), isEmpty);
    });

    test('returns empty list for period <= 0', () {
      expect(service.calculateEMA([1.0], 0), isEmpty);
    });

    test('EMA reacts faster to recent prices', () {
      // After a jump, EMA should be closer to the new price than SMA
      final prices = [10.0, 10.0, 10.0, 10.0, 10.0, 50.0];
      final sma = service.calculateSMA(prices, 5);
      final ema = service.calculateEMA(prices, 5);

      // At index 5 (after the jump), EMA should be closer to 50 than SMA
      expect(ema[5]!, greaterThan(sma[5]!));
    });

    test('period = 1 tracks price exactly', () {
      final prices = [5.0, 10.0, 15.0];
      final result = service.calculateEMA(prices, 1);
      expect(result[0], closeTo(5.0, 0.001));
      expect(result[1], closeTo(10.0, 0.001));
      expect(result[2], closeTo(15.0, 0.001));
    });

    test('all null when period > data length', () {
      final result = service.calculateEMA([1.0, 2.0], 5);
      expect(result.length, equals(2));
      expect(result.every((v) => v == null), isTrue);
    });

    test('applies correct multiplier', () {
      final prices = [10.0, 20.0, 30.0, 40.0];
      final result = service.calculateEMA(prices, 3);
      // multiplier = 2 / (3+1) = 0.5
      // EMA[2] = SMA = (10+20+30)/3 = 20
      // EMA[3] = (40 - 20) * 0.5 + 20 = 30
      expect(result[2], closeTo(20.0, 0.001));
      expect(result[3], closeTo(30.0, 0.001));
    });
  });

  // ==========================================
  // calculateRSI
  // ==========================================

  group('calculateRSI', () {
    test('monotonically increasing prices → RSI near 100', () {
      final prices = List.generate(20, (i) => 100.0 + i * 1.0);
      final result = service.calculateRSI(prices, period: 14);

      final lastRsi = result.whereType<double>().last;
      expect(lastRsi, closeTo(100.0, 0.01));
    });

    test('monotonically decreasing prices → RSI near 0', () {
      final prices = List.generate(20, (i) => 100.0 - i * 1.0);
      final result = service.calculateRSI(prices, period: 14);

      final lastRsi = result.whereType<double>().last;
      expect(lastRsi, closeTo(0.0, 0.01));
    });

    test('flat prices → RSI = 50', () {
      final prices = List.filled(20, 100.0);
      final result = service.calculateRSI(prices, period: 14);

      final lastRsi = result.whereType<double>().last;
      expect(lastRsi, closeTo(50.0, 0.001));
    });

    test('insufficient data returns all null', () {
      // Need period + 1 = 15 data points
      final prices = List.filled(14, 100.0);
      final result = service.calculateRSI(prices, period: 14);
      expect(result.every((v) => v == null), isTrue);
    });

    test('first period values are null', () {
      final prices = List.generate(20, (i) => 100.0 + i * 0.5);
      final result = service.calculateRSI(prices, period: 14);

      for (int i = 0; i < 14; i++) {
        expect(result[i], isNull);
      }
      expect(result[14], isNotNull);
    });

    test('custom period works correctly', () {
      final prices = List.generate(10, (i) => 100.0 + i * 1.0);
      final result = service.calculateRSI(prices, period: 5);

      // First 5 should be null
      for (int i = 0; i < 5; i++) {
        expect(result[i], isNull);
      }
      expect(result[5], isNotNull);
    });

    test('RSI stays between 0 and 100', () {
      // Random-ish prices with big swings
      final prices = [
        100.0,
        110.0,
        95.0,
        120.0,
        80.0,
        115.0,
        90.0,
        130.0,
        75.0,
        100.0,
        105.0,
        88.0,
        112.0,
        97.0,
        108.0,
        92.0,
      ];
      final result = service.calculateRSI(prices, period: 6);

      for (final rsi in result) {
        if (rsi != null) {
          expect(rsi, greaterThanOrEqualTo(0.0));
          expect(rsi, lessThanOrEqualTo(100.0));
        }
      }
    });

    test('result length matches input length', () {
      final prices = List.generate(30, (i) => 100.0 + i * 0.1);
      final result = service.calculateRSI(prices, period: 14);
      expect(result.length, equals(30));
    });
  });

  // ==========================================
  // calculateKD
  // ==========================================

  group('calculateKD', () {
    test('close at high → K = 100', () {
      final highs = List.filled(12, 110.0);
      final lows = List.filled(12, 90.0);
      final closes = List.filled(12, 110.0); // close = high
      final result = service.calculateKD(highs, lows, closes, kPeriod: 9);

      final lastK = result.k.whereType<double>().last;
      expect(lastK, closeTo(100.0, 0.001));
    });

    test('close at low → K = 0', () {
      final highs = List.filled(12, 110.0);
      final lows = List.filled(12, 90.0);
      final closes = List.filled(12, 90.0); // close = low
      final result = service.calculateKD(highs, lows, closes, kPeriod: 9);

      final lastK = result.k.whereType<double>().last;
      expect(lastK, closeTo(0.0, 0.001));
    });

    test('range = 0 → K = 50', () {
      final prices = List.filled(12, 100.0);
      final result = service.calculateKD(prices, prices, prices, kPeriod: 9);

      final lastK = result.k.whereType<double>().last;
      expect(lastK, closeTo(50.0, 0.001));
    });

    test('D is SMA of K', () {
      final highs = List.generate(15, (i) => 100.0 + i * 2.0);
      final lows = List.generate(15, (i) => 90.0 + i * 2.0);
      final closes = List.generate(15, (i) => 95.0 + i * 2.0);
      final result = service.calculateKD(
        highs,
        lows,
        closes,
        kPeriod: 9,
        dPeriod: 3,
      );

      // D should start later than K (needs dPeriod-1 extra K values)
      final firstKIdx = result.k.indexWhere((v) => v != null);
      final firstDIdx = result.d.indexWhere((v) => v != null);
      expect(firstDIdx, greaterThan(firstKIdx));
    });

    test('returns empty on length mismatch', () {
      final result = service.calculateKD([100.0, 110.0], [90.0], [95.0, 100.0]);
      expect(result.k, isEmpty);
      expect(result.d, isEmpty);
    });

    test('first kPeriod-1 values are null', () {
      final prices = List.filled(15, 100.0);
      final result = service.calculateKD(prices, prices, prices, kPeriod: 9);

      for (int i = 0; i < 8; i++) {
        expect(result.k[i], isNull);
      }
      expect(result.k[8], isNotNull);
    });
  });

  // ==========================================
  // calculateMACD
  // ==========================================

  group('calculateMACD', () {
    test('MACD = fastEMA - slowEMA', () {
      final prices = List.generate(40, (i) => 100.0 + i * 0.5);
      final result = service.calculateMACD(prices);
      final fastEMA = service.calculateEMA(prices, 12);
      final slowEMA = service.calculateEMA(prices, 26);

      // Check a point where both EMAs exist
      for (int i = 25; i < 40; i++) {
        if (fastEMA[i] != null &&
            slowEMA[i] != null &&
            result.macd[i] != null) {
          expect(result.macd[i], closeTo(fastEMA[i]! - slowEMA[i]!, 0.001));
        }
      }
    });

    test('insufficient data produces nulls', () {
      final prices = [10.0, 20.0, 30.0];
      final result = service.calculateMACD(prices);
      expect(result.macd.every((v) => v == null), isTrue);
    });

    test('histogram = MACD - signal', () {
      final prices = List.generate(50, (i) => 100.0 + sin(i * 0.3) * 10);
      final result = service.calculateMACD(prices);

      for (int i = 0; i < prices.length; i++) {
        if (result.macd[i] != null &&
            result.signal[i] != null &&
            result.histogram[i] != null) {
          expect(
            result.histogram[i],
            closeTo(result.macd[i]! - result.signal[i]!, 0.001),
          );
        }
      }
    });

    test('result lists have same length as input', () {
      final prices = List.generate(50, (i) => 100.0 + i * 0.1);
      final result = service.calculateMACD(prices);
      expect(result.macd.length, equals(50));
      expect(result.signal.length, equals(50));
      expect(result.histogram.length, equals(50));
    });

    test('custom periods work', () {
      final prices = List.generate(30, (i) => 100.0 + i * 0.5);
      final result = service.calculateMACD(
        prices,
        fastPeriod: 5,
        slowPeriod: 10,
        signalPeriod: 3,
      );

      // Should have non-null values earlier with shorter periods
      final firstNonNull = result.macd.indexWhere((v) => v != null);
      expect(firstNonNull, lessThan(15));
    });
  });

  // ==========================================
  // calculateBollingerBands
  // ==========================================

  group('calculateBollingerBands', () {
    test('middle band equals SMA', () {
      final prices = List.generate(25, (i) => 100.0 + i * 0.5);
      final bb = service.calculateBollingerBands(prices, period: 20);
      final sma = service.calculateSMA(prices, 20);

      for (int i = 0; i < prices.length; i++) {
        if (bb.middle[i] != null && sma[i] != null) {
          expect(bb.middle[i], closeTo(sma[i]!, 0.001));
        }
      }
    });

    test('bands are symmetric around middle', () {
      final prices = List.generate(25, (i) => 100.0 + i * 0.5);
      final bb = service.calculateBollingerBands(prices, period: 20);

      for (int i = 0; i < prices.length; i++) {
        if (bb.upper[i] != null &&
            bb.lower[i] != null &&
            bb.middle[i] != null) {
          final upperDist = bb.upper[i]! - bb.middle[i]!;
          final lowerDist = bb.middle[i]! - bb.lower[i]!;
          expect(upperDist, closeTo(lowerDist, 0.001));
        }
      }
    });

    test('flat prices → upper = lower = middle', () {
      final prices = List.filled(25, 100.0);
      final bb = service.calculateBollingerBands(prices, period: 20);

      for (int i = 19; i < 25; i++) {
        expect(bb.upper[i], closeTo(100.0, 0.001));
        expect(bb.middle[i], closeTo(100.0, 0.001));
        expect(bb.lower[i], closeTo(100.0, 0.001));
      }
    });

    test('higher volatility → wider bands', () {
      final lowVol = List.generate(
        25,
        (i) => 100.0 + (i % 2 == 0 ? 0.1 : -0.1),
      );
      final highVol = List.generate(
        25,
        (i) => 100.0 + (i % 2 == 0 ? 5.0 : -5.0),
      );

      final bbLow = service.calculateBollingerBands(lowVol, period: 20);
      final bbHigh = service.calculateBollingerBands(highVol, period: 20);

      final lowWidth = bbLow.upper[24]! - bbLow.lower[24]!;
      final highWidth = bbHigh.upper[24]! - bbHigh.lower[24]!;
      expect(highWidth, greaterThan(lowWidth));
    });

    test('insufficient data returns nulls', () {
      final prices = [10.0, 20.0, 30.0];
      final bb = service.calculateBollingerBands(prices, period: 20);
      expect(bb.upper.every((v) => v == null), isTrue);
      expect(bb.lower.every((v) => v == null), isTrue);
    });
  });

  // ==========================================
  // calculateOBV
  // ==========================================

  group('calculateOBV', () {
    test('price up → OBV increases', () {
      final closes = [100.0, 105.0];
      final volumes = [1000.0, 2000.0];
      final result = service.calculateOBV(closes, volumes);
      expect(result[1], equals(2000.0));
    });

    test('price down → OBV decreases', () {
      final closes = [100.0, 95.0];
      final volumes = [1000.0, 2000.0];
      final result = service.calculateOBV(closes, volumes);
      expect(result[1], equals(-2000.0));
    });

    test('flat price → OBV unchanged', () {
      final closes = [100.0, 100.0];
      final volumes = [1000.0, 2000.0];
      final result = service.calculateOBV(closes, volumes);
      expect(result[1], equals(0.0));
    });

    test('returns empty for empty input', () {
      expect(service.calculateOBV([], []), isEmpty);
    });

    test('returns empty on length mismatch', () {
      expect(service.calculateOBV([100.0], [1000.0, 2000.0]), isEmpty);
    });
  });

  // ==========================================
  // calculateATR
  // ==========================================

  group('calculateATR', () {
    test('first ATR is simple average of True Range', () {
      // Simple case: constant spreads
      final highs = List.filled(15, 105.0);
      final lows = List.filled(15, 95.0);
      final closes = List.filled(15, 100.0);
      final result = service.calculateATR(highs, lows, closes, period: 14);

      // TR = high - low = 10 for all days
      // First ATR = simple avg of 14 TRs = 10
      expect(result[13], closeTo(10.0, 0.001));
    });

    test('uses Wilder smoothing after first value', () {
      final highs = List.filled(20, 105.0);
      final lows = List.filled(20, 95.0);
      final closes = List.filled(20, 100.0);

      // Change the last day to have wider range
      highs[19] = 120.0;
      lows[19] = 80.0;

      final result = service.calculateATR(
        highs.toList(),
        lows.toList(),
        closes.toList(),
        period: 14,
      );

      // Last ATR should be influenced by the wider range
      // but smoothed (not equal to the raw TR of 40)
      expect(result.last!, greaterThan(10.0));
      expect(result.last!, lessThan(40.0));
    });

    test('returns empty on length mismatch', () {
      expect(service.calculateATR([100.0], [90.0, 85.0], [95.0]), isEmpty);
    });

    test('returns all null for insufficient data', () {
      final result = service.calculateATR([105.0], [95.0], [100.0], period: 14);
      expect(result.every((v) => v == null), isTrue);
    });

    test('True Range considers gap from previous close', () {
      // Day 0: close=100, Day 1: gap up, high=120, low=110, close=115
      final highs = [105.0, 120.0];
      final lows = [95.0, 110.0];
      final closes = [100.0, 115.0];

      // Can't test ATR directly with just 2 points (need period=14)
      // But we can test with period=1
      final result = service.calculateATR(highs, lows, closes, period: 1);

      // Day 0: TR = 105 - 95 = 10
      // Day 1: TR = max(120-110, |120-100|, |110-100|) = max(10, 20, 10) = 20
      expect(result[0], closeTo(10.0, 0.001));
      // Day 1 ATR = Wilder((10 * 0 + 20) / 1) but simplified with period=1:
      // first ATR = 10 (period=1, just day 0 TR)
      // Actually with period=1, index 0 is the first ATR
      // index 1 uses Wilder: (10 * 0 + 20) / 1 = 20
      expect(result[1], closeTo(20.0, 0.001));
    });
  });

  // ==========================================
  // Static methods
  // ==========================================

  group('latestSMA', () {
    test('returns correct value from DailyPriceEntry list', () {
      final prices = generateConstantPrices(days: 25, basePrice: 100.0);
      final result = TechnicalIndicatorService.latestSMA(prices, 20);
      expect(result, closeTo(100.0, 0.001));
    });

    test('returns null when insufficient data', () {
      final prices = generateFlatPrices(days: 5, basePrice: 100.0);
      expect(TechnicalIndicatorService.latestSMA(prices, 20), isNull);
    });
  });

  group('latestRSI', () {
    test('returns value for sufficient data', () {
      final prices = generateUptrendPrices(days: 30, startPrice: 100.0);
      final result = TechnicalIndicatorService.latestRSI(prices);
      expect(result, isNotNull);
      expect(result!, greaterThan(50.0)); // uptrend → RSI > 50
    });

    test('returns null when insufficient data', () {
      final prices = generateFlatPrices(days: 10, basePrice: 100.0);
      expect(TechnicalIndicatorService.latestRSI(prices), isNull);
    });
  });

  group('latestVolumeMA', () {
    test('returns correct volumeMA and todayVolume', () {
      final prices = generateConstantPrices(
        days: 25,
        basePrice: 100.0,
        volume: 500.0,
      );
      final result = TechnicalIndicatorService.latestVolumeMA(prices, 20);
      expect(result.volumeMA, closeTo(500.0, 0.001));
      expect(result.todayVolume, closeTo(500.0, 0.001));
    });

    test('returns null volumeMA when insufficient data', () {
      final prices = generateFlatPrices(days: 5, basePrice: 100.0);
      final result = TechnicalIndicatorService.latestVolumeMA(prices, 20);
      expect(result.volumeMA, isNull);
    });

    test('returns null for empty list', () {
      final result = TechnicalIndicatorService.latestVolumeMA([], 20);
      expect(result.volumeMA, isNull);
      expect(result.todayVolume, isNull);
    });
  });

  group('latestOBV', () {
    test('returns accumulated OBV value', () {
      final prices = generateUptrendPrices(
        days: 10,
        startPrice: 100.0,
        dailyGain: 1.0,
      );
      final result = TechnicalIndicatorService.latestOBV(prices);
      expect(result, isNotNull);
    });

    test('returns null for single price', () {
      final prices = generateFlatPrices(days: 1, basePrice: 100.0);
      expect(TechnicalIndicatorService.latestOBV(prices), isNull);
    });
  });

  group('latestATR', () {
    test('returns value for sufficient data', () {
      final prices = generateSwingPrices(days: 20, basePrice: 100.0);
      final result = TechnicalIndicatorService.latestATR(prices);
      expect(result, isNotNull);
      expect(result!, greaterThan(0.0));
    });

    test('returns null when insufficient data', () {
      final prices = generateFlatPrices(days: 5, basePrice: 100.0);
      expect(TechnicalIndicatorService.latestATR(prices), isNull);
    });
  });
}
