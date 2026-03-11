import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/analysis/analysis_coordinator_service.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late AnalysisService analysisService;
  late AnalysisCoordinatorService coordinator;

  setUp(() {
    analysisService = AnalysisService();
    coordinator = AnalysisCoordinatorService();
  });

  group('TrendDetectionService', () {
    test('should detect uptrend when prices are rising', () {
      final prices = generateUptrendPrices(days: 25);

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.up);
    });

    test('should detect downtrend when prices are falling', () {
      final prices = generateDowntrendPrices(days: 25);

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.down);
    });

    test('should detect range when prices are flat', () {
      final prices = generateFlatPrices(days: 25, basePrice: 100.0);

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.range);
    });

    test('should return range when not enough data', () {
      final prices = generateFlatPrices(days: 3, basePrice: 100.0);

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.range);
    });

    test('should detect uptrend with explicit price increase', () {
      final now = DateTime.now();
      final prices = List.generate(25, (i) {
        final price = 100.0 + (i * 0.5); // 100 → 112
        return createTestPrice(
          date: now.subtract(Duration(days: 25 - i - 1)),
          close: price,
        );
      });

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.up);
    });

    test('should detect downtrend with explicit price decrease', () {
      final now = DateTime.now();
      final prices = List.generate(25, (i) {
        final price = 112.0 - (i * 0.5); // 112 → 100
        return createTestPrice(
          date: now.subtract(Duration(days: 25 - i - 1)),
          close: price,
        );
      });

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.down);
    });

    test('should return range when price change is minimal', () {
      final now = DateTime.now();
      final prices = List.generate(25, (i) {
        final price = 100.0 + (i * 0.02);
        return createTestPrice(
          date: now.subtract(Duration(days: 25 - i - 1)),
          close: price,
        );
      });

      final trend = coordinator.trendService.detectTrendState(prices);

      expect(trend, TrendState.range);
    });
  });

  group('SupportResistanceService', () {
    test('should find support and resistance levels', () {
      final now = DateTime.now();
      final prices = <DailyPriceEntry>[];

      for (var i = 0; i < 60; i++) {
        final date = now.subtract(Duration(days: 60 - i - 1));
        double close;
        double high;
        double low;

        if (i < 20) {
          close = 100.0;
          high = 100.5;
          low = 99.5;
        } else if (i < 30) {
          final progress = (i - 20) / 10.0;
          close = 100.0 - 5.0 * (1 - (progress - 0.5).abs() * 2);
          high = close + 0.5;
          low = close - 0.5;
        } else if (i < 45) {
          final progress = (i - 30) / 15.0;
          close = 100.0 + 5.0 * (1 - (progress - 0.5).abs() * 2);
          high = close + 0.5;
          low = close - 0.5;
        } else {
          close = 100.0;
          high = 100.5;
          low = 99.5;
        }

        prices.add(
          DailyPriceEntry(
            symbol: 'TEST',
            date: date,
            open: close - 0.2,
            high: high,
            low: low,
            close: close,
            volume: 1000.0,
          ),
        );
      }

      final (support, resistance) = coordinator.srService.findSupportResistance(
        prices,
      );

      expect(support, isNotNull);
      expect(resistance, isNotNull);
      expect(resistance! > support!, isTrue);
    });

    test('should return nulls when not enough data', () {
      final prices = generateFlatPrices(days: 30, basePrice: 100.0);

      final (support, resistance) = coordinator.srService.findSupportResistance(
        prices,
      );

      expect(support, isNull);
      expect(resistance, isNull);
    });

    test('should find 60-day high and low', () {
      final prices = generateSwingPrices(days: 70);

      final (rangeLow, rangeHigh) = coordinator.srService.findRange(prices);

      expect(rangeLow, isNotNull);
      expect(rangeHigh, isNotNull);
      expect(rangeHigh! > rangeLow!, isTrue);
    });

    test('should return nulls when empty', () {
      final (rangeLow, rangeHigh) = coordinator.srService.findRange([]);

      expect(rangeLow, isNull);
      expect(rangeHigh, isNull);
    });
  });

  group('ReversalDetectionService', () {
    test('should detect weak-to-strong on breakout above range top', () {
      final prices = generateFlatPrices(days: 25, basePrice: 100.0);

      final pricesWithBreakout = [
        ...prices.take(prices.length - 1),
        createTestPrice(date: DateTime.now(), close: 106.0),
      ];

      final reversal = coordinator.reversalService.detectReversalState(
        pricesWithBreakout,
        trendState: TrendState.down,
        rangeTop: 102.0,
      );

      expect(reversal, ReversalState.weakToStrong);
    });

    test('should detect strong-to-weak on breakdown below support', () {
      final prices = generateFlatPrices(days: 25, basePrice: 100.0);

      final pricesWithBreakdown = [
        ...prices.take(prices.length - 1),
        createTestPrice(date: DateTime.now(), close: 94.0),
      ];

      final reversal = coordinator.reversalService.detectReversalState(
        pricesWithBreakdown,
        trendState: TrendState.up,
        support: 98.0,
      );

      expect(reversal, ReversalState.strongToWeak);
    });

    test('should return none when no reversal detected', () {
      final prices = generateFlatPrices(days: 25, basePrice: 100.0);

      final reversal = coordinator.reversalService.detectReversalState(
        prices,
        trendState: TrendState.range,
      );

      expect(reversal, ReversalState.none);
    });
  });

  group('AnalysisService', () {
    group('isCandidate', () {
      test('should return true for price spike', () {
        final prices = generatePricesWithPriceSpike(
          days: 25,
          basePrice: 100.0,
          changePercent: 6.0,
        );

        final result = analysisService.isCandidate(prices);

        expect(result, isTrue);
      });

      test('should return true for volume spike', () {
        final prices = generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 2500,
        );

        final result = analysisService.isCandidate(prices);

        expect(result, isTrue);
      });

      test('should return false for normal conditions', () {
        final prices = generateFlatPrices(days: 25, basePrice: 100.0);

        final result = analysisService.isCandidate(prices);

        expect(result, isFalse);
      });

      test('should return false when not enough data', () {
        final prices = generateFlatPrices(days: 5, basePrice: 100.0);

        final result = analysisService.isCandidate(prices);

        expect(result, isFalse);
      });
    });

    group('analyzeStock', () {
      test('should return complete analysis result', () {
        final prices = generateSwingPrices(days: 30);

        final result = analysisService.analyzeStock(prices);

        expect(result, isNotNull);
        expect(result!.trendState, isNotNull);
        expect(result.reversalState, isNotNull);
      });

      test('should return null when not enough data', () {
        final prices = generateFlatPrices(days: 3, basePrice: 100.0);

        final result = analysisService.analyzeStock(prices);

        expect(result, isNull);
      });
    });

    group('buildContext', () {
      test('should build context from analysis result', () {
        const result = AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 95.0,
          resistanceLevel: 105.0,
          rangeTop: 110.0,
          rangeBottom: 90.0,
        );

        final context = analysisService.buildContext(result);

        expect(context.trendState, TrendState.up);
        expect(context.supportLevel, 95.0);
        expect(context.resistanceLevel, 105.0);
        expect(context.rangeTop, 110.0);
        expect(context.rangeBottom, 90.0);
      });
    });
  });
}
