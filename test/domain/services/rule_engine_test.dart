import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = const RuleEngine();
  });

  group('RuleEngine', () {
    group('checkVolumeSpike', () {
      test('should trigger when volume is 2x+ of 20-day average', () {
        final prices = _generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 2500, // 2.5x
        );

        final result = ruleEngine.checkVolumeSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.volumeSpike);
        expect(result.score, RuleScores.volumeSpike);
      });

      test('should not trigger when volume is below threshold', () {
        final prices = _generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 1500, // 1.5x, below 2x threshold
        );

        final result = ruleEngine.checkVolumeSpike(prices);

        expect(result, isNull);
      });
    });

    group('checkPriceSpike', () {
      test('should trigger when price change >= 5%', () {
        final prices = _generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: 6.0, // 6% gain
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
        expect(result.score, RuleScores.priceSpike);
      });

      test('should trigger on negative spike', () {
        final prices = _generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: -7.0, // 7% loss
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
      });

      test('should not trigger when change is below threshold', () {
        final prices = _generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: 3.0, // 3%, below 5% threshold
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNull);
      });
    });

    group('checkBreakout', () {
      test('should trigger when close breaks resistance', () {
        final prices = _generatePrices(days: 30, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        // Last price breaks out
        final pricesWithBreakout = [
          ...prices.take(prices.length - 1),
          _createPrice(
            date: DateTime.now(),
            close: 101.0, // Above resistance + buffer
          ),
        ];

        final result = ruleEngine.checkBreakout(pricesWithBreakout, context);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakout);
        expect(result.score, RuleScores.techBreakout);
      });

      test('should not trigger when close is below resistance', () {
        final prices = _generatePrices(days: 30, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 105.0, // Above current price
        );

        final result = ruleEngine.checkBreakout(prices, context);

        expect(result, isNull);
      });
    });

    group('checkBreakdown', () {
      test('should trigger when close breaks support', () {
        final prices = _generatePrices(days: 30, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          supportLevel: 100.0,
        );

        // Last price breaks down
        final pricesWithBreakdown = [
          ...prices.take(prices.length - 1),
          _createPrice(
            date: DateTime.now(),
            close: 99.0, // Below support - buffer
          ),
        ];

        final result = ruleEngine.checkBreakdown(pricesWithBreakdown, context);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakdown);
        expect(result.score, RuleScores.techBreakdown);
      });
    });

    group('checkInstitutionalShift', () {
      test('should trigger on direction reversal', () {
        final history = _generateInstitutionalHistory(
          days: 5,
          prevDirection: -1000, // Selling
          todayDirection: 500, // Buying
        );

        final result = ruleEngine.checkInstitutionalShift(history);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalShift);
        expect(result.score, RuleScores.institutionalShift);
      });

      test('should not trigger when direction is same', () {
        final history = _generateInstitutionalHistory(
          days: 5,
          prevDirection: 1000, // Buying
          todayDirection: 500, // Still buying
        );

        final result = ruleEngine.checkInstitutionalShift(history);

        expect(result, isNull);
      });
    });

    group('calculateScore', () {
      test('should sum all rule scores', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 18,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.priceSpike,
            score: 15,
            evidence: {},
            template: 'test',
          ),
        ];

        final score = ruleEngine.calculateScore(reasons);

        expect(score, 33); // 18 + 15
      });

      test('should add bonus for breakout + volume spike', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.techBreakout,
            score: 25,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 18,
            evidence: {},
            template: 'test',
          ),
        ];

        final score = ruleEngine.calculateScore(reasons);

        expect(score, 49); // 25 + 18 + 6 bonus
      });

      test('should apply cooldown multiplier', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 18,
            evidence: {},
            template: 'test',
          ),
        ];

        final score = ruleEngine.calculateScore(
          reasons,
          wasRecentlyRecommended: true,
        );

        expect(score, 13); // 18 * 0.7 = 12.6, rounded to 13
      });
    });

    group('getTopReasons', () {
      test('should return max 2 reasons', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.reversalW2S,
            score: 35,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.techBreakout,
            score: 25,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 18,
            evidence: {},
            template: 'test',
          ),
        ];

        final top = ruleEngine.getTopReasons(reasons);

        expect(top.length, 2);
        expect(top[0].type, ReasonType.reversalW2S);
        expect(top[1].type, ReasonType.techBreakout);
      });

      test('should deduplicate by category', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.reversalW2S,
            score: 35,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.reversalS2W,
            score: 35, // Same category as W2S
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 18,
            evidence: {},
            template: 'test',
          ),
        ];

        final top = ruleEngine.getTopReasons(reasons);

        expect(top.length, 2);
        expect(top[0].type, ReasonType.reversalW2S);
        expect(top[1].type, ReasonType.volumeSpike); // Skip S2W, same category
      });
    });
  });
}

// ==========================================
// Test Helpers
// ==========================================

List<DailyPriceEntry> _generatePrices({
  required int days,
  required double basePrice,
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    return _createPrice(
      date: now.subtract(Duration(days: days - i - 1)),
      open: basePrice,
      high: basePrice * 1.01,
      low: basePrice * 0.99,
      close: basePrice,
      volume: 1000,
    );
  });
}

List<DailyPriceEntry> _generatePricesWithVolumeSpike({
  required int days,
  required double normalVolume,
  required double spikeVolume,
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    return _createPrice(
      date: now.subtract(Duration(days: days - i - 1)),
      close: 100.0,
      volume: isToday ? spikeVolume : normalVolume,
    );
  });
}

List<DailyPriceEntry> _generatePricesWithPriceSpike({
  required int days,
  required double basePrice,
  required double changePercent,
}) {
  final now = DateTime.now();
  final todayPrice = basePrice * (1 + changePercent / 100);

  return List.generate(days, (i) {
    final isToday = i == days - 1;
    return _createPrice(
      date: now.subtract(Duration(days: days - i - 1)),
      close: isToday ? todayPrice : basePrice,
    );
  });
}

List<DailyInstitutionalEntry> _generateInstitutionalHistory({
  required int days,
  required double prevDirection,
  required double todayDirection,
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final isToday = i == days - 1;
    return DailyInstitutionalEntry(
      symbol: 'TEST',
      date: now.subtract(Duration(days: days - i - 1)),
      foreignNet: isToday ? todayDirection : prevDirection / 3,
      investmentTrustNet: 0,
      dealerNet: 0,
    );
  });
}

DailyPriceEntry _createPrice({
  required DateTime date,
  double? open,
  double? high,
  double? low,
  double? close,
  double? volume,
}) {
  return DailyPriceEntry(
    symbol: 'TEST',
    date: date,
    open: open,
    high: high ?? (close != null ? close * 1.01 : null),
    low: low ?? (close != null ? close * 0.99 : null),
    close: close,
    volume: volume,
  );
}
