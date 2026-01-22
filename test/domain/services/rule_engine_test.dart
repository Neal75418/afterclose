import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = const RuleEngine();
  });

  group('RuleEngine', () {
    group('checkVolumeSpike', () {
      test('should trigger when volume is 4x+ of 20-day average', () {
        final prices = generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 5000, // 5x (above 4x threshold)
        );

        final result = ruleEngine.checkVolumeSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.volumeSpike);
        expect(result.score, RuleScores.volumeSpike);
      });

      test('should not trigger when volume is below threshold', () {
        final prices = generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 3500, // 3.5x (below 4x threshold)
        );

        final result = ruleEngine.checkVolumeSpike(prices);

        expect(result, isNull);
      });
    });

    group('checkPriceSpike', () {
      test('should trigger when price change >= 3%', () {
        final prices = generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: 6.0, // 6% gain (above 3% threshold)
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
        expect(result.score, RuleScores.priceSpike);
      });

      test('should trigger on negative spike', () {
        final prices = generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: -7.0, // 7% loss
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
      });

      test('should not trigger when change is below threshold', () {
        final prices = generatePricesWithPriceSpike(
          days: 5,
          basePrice: 100.0,
          changePercent: 2.5, // 2.5%, below 3% threshold
        );

        final result = ruleEngine.checkPriceSpike(prices);

        expect(result, isNull);
      });
    });

    group('checkWeakToStrong', () {
      test('should trigger on range top breakout during downtrend', () {
        // Need 60+ days for range lookback
        final prices = generateDowntrendPrices(days: 65);
        const context = AnalysisContext(
          trendState: TrendState.down,
          rangeTop: 100.0,
        );

        // Last price breaks out above range top (with buffer)
        // breakoutBuffer is 1%, so need close > 100.0 * 1.01 = 101.0
        final pricesWithBreakout = [
          ...prices.take(prices.length - 1),
          createTestPrice(
            date: DateTime.now(),
            close: 102.0, // Above range top + 1% buffer (101.0)
          ),
        ];

        final result = ruleEngine.checkWeakToStrong(
          pricesWithBreakout,
          context,
        );

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalW2S);
        expect(result.score, RuleScores.reversalW2S);
      });

      test('should trigger on higher low formation during downtrend', () {
        // Need 60+ days and 2 swing windows (40 days) for higher low detection
        final prices = generateHigherLowPattern(days: 65);
        const context = AnalysisContext(trendState: TrendState.down);

        final result = ruleEngine.checkWeakToStrong(prices, context);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalW2S);
        expect(result.evidence['trigger'], 'higher_low');
      });

      test('should not trigger during uptrend', () {
        final prices = generateConstantPrices(days: 65, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.up,
          rangeTop: 100.0,
        );

        final result = ruleEngine.checkWeakToStrong(prices, context);

        expect(result, isNull);
      });
    });

    group('checkStrongToWeak', () {
      test('should trigger on support breakdown during uptrend', () {
        // Need 60+ days for range lookback
        final prices = generateConstantPrices(days: 65, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.up,
          supportLevel: 100.0,
        );

        // Last price breaks down (below support - 0.5% buffer)
        final pricesWithBreakdown = [
          ...prices.take(prices.length - 1),
          createTestPrice(
            date: DateTime.now(),
            close: 99.0, // Below support * (1 - 0.005) = 99.5
          ),
        ];

        final result = ruleEngine.checkStrongToWeak(
          pricesWithBreakdown,
          context,
        );

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalS2W);
        expect(result.score, RuleScores.reversalS2W);
      });

      test('should trigger on range bottom breakdown', () {
        // Need 60+ days for range lookback
        final prices = generateConstantPrices(days: 65, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          rangeBottom: 100.0,
        );

        // Last price breaks below range bottom (with buffer)
        final pricesWithBreakdown = [
          ...prices.take(prices.length - 1),
          createTestPrice(
            date: DateTime.now(),
            close: 99.0, // Below range bottom * (1 - 0.005) = 99.5
          ),
        ];

        final result = ruleEngine.checkStrongToWeak(
          pricesWithBreakdown,
          context,
        );

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalS2W);
      });

      test('should not trigger during downtrend', () {
        final prices = generateConstantPrices(days: 65, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.down,
          supportLevel: 100.0,
        );

        final result = ruleEngine.checkStrongToWeak(prices, context);

        expect(result, isNull);
      });
    });

    group('checkNewsRelated', () {
      test('should trigger when news contains positive keyword', () {
        final news = <NewsItemEntry>[
          createTestNewsItem(id: 'news1', title: '台積電營收創新高'),
        ];

        final result = ruleEngine.checkNewsRelated(news);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.newsRelated);
        expect(result.score, RuleScores.newsRelated);
        expect(result.evidence['sentiment'], '利多');
      });

      test('should trigger when news contains negative keyword', () {
        final news = <NewsItemEntry>[
          createTestNewsItem(id: 'news1', title: '股價跌停'),
        ];

        final result = ruleEngine.checkNewsRelated(news);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.newsRelated);
        expect(result.evidence['sentiment'], '利空');
      });

      test('should not trigger when news has no relevant keywords', () {
        final news = <NewsItemEntry>[
          createTestNewsItem(
            id: 'news1',
            title: 'Generic News Without Keywords',
          ),
        ];

        final result = ruleEngine.checkNewsRelated(news);

        expect(result, isNull);
      });

      test('should not trigger when no news', () {
        final result = ruleEngine.checkNewsRelated([]);

        expect(result, isNull);
      });
    });

    group('evaluateStock', () {
      test('should return multiple triggered reasons', () {
        // Need at least swingWindow (20) days
        // Volume spike requires 4x+ volume AND 1.5%+ price change
        final prices = generatePricesWithVolumeSpike(
          days: 25,
          normalVolume: 1000,
          spikeVolume: 5000, // 5x (above 4x threshold)
        );
        // Set resistance below current close (103.0, because spike day has +3% price change)
        // breakoutBuffer is 1%, so breakoutLevel = 100.0 * 1.01 = 101.0
        // close 103.0 > 101.0 should trigger breakout
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        final reasons = ruleEngine.evaluateStock(
          priceHistory: prices,
          context: context,
        );

        expect(reasons, isNotEmpty);
        expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
        expect(reasons.any((r) => r.type == ReasonType.techBreakout), isTrue);
      });

      test('should return empty list when not enough data', () {
        // Need swingWindow (20) days, so 15 is not enough
        final prices = generateConstantPrices(days: 15, basePrice: 100.0);
        const context = AnalysisContext(trendState: TrendState.range);

        final reasons = ruleEngine.evaluateStock(
          priceHistory: prices,
          context: context,
        );

        expect(reasons, isEmpty);
      });
    });

    group('checkBreakout', () {
      test('should trigger when close breaks resistance', () {
        final prices = generateConstantPrices(days: 30, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        // Last price breaks out
        // breakoutBuffer is 1%, so need close > 100.0 * 1.01 = 101.0
        final pricesWithBreakout = [
          ...prices.take(prices.length - 1),
          createTestPrice(
            date: DateTime.now(),
            close: 102.0, // Above resistance + 1% buffer (101.0)
          ),
        ];

        final result = ruleEngine.checkBreakout(pricesWithBreakout, context);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakout);
        expect(result.score, RuleScores.techBreakout);
      });

      test('should not trigger when close is below resistance', () {
        final prices = generateConstantPrices(days: 30, basePrice: 100.0);
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
        final prices = generateConstantPrices(days: 30, basePrice: 100.0);
        const context = AnalysisContext(
          trendState: TrendState.range,
          supportLevel: 100.0,
        );

        // Last price breaks down
        final pricesWithBreakdown = [
          ...prices.take(prices.length - 1),
          createTestPrice(
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
        final history = generateInstitutionalHistory(
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
        final history = generateInstitutionalHistory(
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

      test('should add bonus for reversal + volume spike', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.reversalW2S,
            score: 35,
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

        expect(score, 59); // 35 + 18 + 6 reversal volume bonus
      });

      test('should add both bonuses when applicable', () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.techBreakout,
            score: 25,
            evidence: {},
            template: 'test',
          ),
          const TriggeredReason(
            type: ReasonType.reversalW2S,
            score: 35,
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

        // 25 + 35 + 18 = 78, + 6 (breakout bonus) + 6 (reversal bonus) = 90
        // But capped at maxScore = 80
        expect(score, 80);
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
