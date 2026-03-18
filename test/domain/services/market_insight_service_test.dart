import 'package:afterclose/domain/services/chip_anomaly_service.dart';
import 'package:afterclose/domain/services/market_insight_service.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketInsightService.detect', () {
    test('returns empty list when no rules triggered', () {
      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 50,
          level: SentimentLevel.neutral,
          subScores: {},
        ),
        streak: const InstitutionalStreak(foreignStreak: 2, trustStreak: -1),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 1000,
          avg5dTurnover: 900,
        ),
        chipAnomalies: const [],
        limitUpDown: const LimitUpDown(limitUp: 5, limitDown: 3),
        margin: const MarginTradingTotals(
          marginBalance: 10000,
          marginChange: 100,
          shortBalance: 5000,
          shortChange: 50,
        ),
        industries: [
          const IndustrySummary(
            industry: 'A',
            stockCount: 10,
            avgChangePct: 1.0,
            advance: 7,
            decline: 3,
          ),
          const IndustrySummary(
            industry: 'B',
            stockCount: 10,
            avgChangePct: -0.5,
            advance: 4,
            decline: 6,
          ),
          const IndustrySummary(
            industry: 'C',
            stockCount: 10,
            avgChangePct: 0.2,
            advance: 5,
            decline: 5,
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test('detects sentiment extreme fear', () {
      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 15,
          level: SentimentLevel.extremeFear,
          subScores: {},
        ),
        // Need at least 2 triggers — add volume anomaly
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 500,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      expect(result.first.type, InsightType.sentimentExtreme);
      expect(result.first.severity, InsightSeverity.warning);
      expect(result.first.descArgs['score'], '15');
    });

    test('detects sentiment extreme greed', () {
      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 90,
          level: SentimentLevel.extremeGreed,
          subScores: {},
        ),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      expect(result.first.type, InsightType.sentimentExtreme);
      expect(result.first.descArgs['score'], '90');
    });

    test('detects institutional streak (foreign buy >= 5 days)', () {
      final result = MarketInsightService.detect(
        streak: const InstitutionalStreak(foreignStreak: 6),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final streakInsight = result.firstWhere(
        (i) => i.type == InsightType.institutionalStreak,
      );
      expect(streakInsight.descArgs['days'], '6');
    });

    test('detects institutional streak (trust sell >= 5 days)', () {
      final result = MarketInsightService.detect(
        streak: const InstitutionalStreak(trustStreak: -7),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 500,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final streakInsight = result.firstWhere(
        (i) => i.type == InsightType.institutionalStreak,
      );
      expect(streakInsight.descArgs['days'], '7');
    });

    test('detects volume anomaly (high)', () {
      final result = MarketInsightService.detect(
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 1600,
          avg5dTurnover: 1000,
        ),
        limitUpDown: const LimitUpDown(limitUp: 35, limitDown: 5),
      );

      expect(result, hasLength(2));
      final volumeInsight = result.firstWhere(
        (i) => i.type == InsightType.volumeAnomaly,
      );
      expect(volumeInsight.severity, InsightSeverity.warning);
    });

    test('detects volume anomaly (low)', () {
      final result = MarketInsightService.detect(
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 600,
          avg5dTurnover: 1000,
        ),
        limitUpDown: const LimitUpDown(limitUp: 40, limitDown: 3),
      );

      expect(result, hasLength(2));
      final volumeInsight = result.firstWhere(
        (i) => i.type == InsightType.volumeAnomaly,
      );
      expect(volumeInsight.severity, InsightSeverity.info);
    });

    test('detects chip alert with high severity anomalies', () {
      final result = MarketInsightService.detect(
        chipAnomalies: const [
          ChipAnomaly(
            type: ChipAnomalyType.highPledge,
            severity: ChipSeverity.high,
            symbol: '2330',
            stockName: '台積電',
            market: 'TWSE',
            i18nKey: 'test',
          ),
          ChipAnomaly(
            type: ChipAnomalyType.shortSurge,
            severity: ChipSeverity.high,
            symbol: '2317',
            stockName: '鴻海',
            market: 'TWSE',
            i18nKey: 'test',
          ),
        ],
        limitUpDown: const LimitUpDown(limitUp: 30, limitDown: 5),
      );

      expect(result, hasLength(2));
      final chipInsight = result.firstWhere(
        (i) => i.type == InsightType.chipAlert,
      );
      expect(chipInsight.descArgs['count'], '2');
    });

    test('detects limit imbalance (limitUp >= 30)', () {
      final result = MarketInsightService.detect(
        limitUpDown: const LimitUpDown(limitUp: 35, limitDown: 2),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final limitInsight = result.firstWhere(
        (i) => i.type == InsightType.limitImbalance,
      );
      expect(limitInsight.descArgs['up'], '35');
      expect(limitInsight.descArgs['down'], '2');
    });

    test('detects limit imbalance (limitDown >= 30)', () {
      final result = MarketInsightService.detect(
        limitUpDown: const LimitUpDown(limitUp: 3, limitDown: 40),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 500,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final limitInsight = result.firstWhere(
        (i) => i.type == InsightType.limitImbalance,
      );
      expect(limitInsight.descArgs['down'], '40');
    });

    test('detects margin surge (> 3%)', () {
      final result = MarketInsightService.detect(
        margin: const MarginTradingTotals(
          marginBalance: 10000,
          marginChange: 400, // 4%
          shortBalance: 5000,
          shortChange: 0,
        ),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final marginInsight = result.firstWhere(
        (i) => i.type == InsightType.marginSurge,
      );
      expect(marginInsight.descArgs['pct'], '4.0');
    });

    test('detects short surge (> 5%)', () {
      final result = MarketInsightService.detect(
        margin: const MarginTradingTotals(
          marginBalance: 10000,
          marginChange: 100, // 1% — below threshold
          shortBalance: 5000,
          shortChange: 300, // 6%
        ),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final marginInsight = result.firstWhere(
        (i) => i.type == InsightType.marginSurge,
      );
      expect(marginInsight.descArgs['pct'], '6.0');
    });

    test('detects industry concentration (> 70% up)', () {
      final industries = List.generate(
        10,
        (i) => IndustrySummary(
          industry: 'Industry $i',
          stockCount: 10,
          avgChangePct: i < 8 ? 1.5 : -0.5, // 80% up
          advance: i < 8 ? 7 : 3,
          decline: i < 8 ? 3 : 7,
        ),
      );

      final result = MarketInsightService.detect(
        industries: industries,
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final industryInsight = result.firstWhere(
        (i) => i.type == InsightType.industryConcentration,
      );
      expect(industryInsight.descArgs['pct'], '80');
    });

    test('detects industry concentration (> 70% down)', () {
      final industries = List.generate(
        10,
        (i) => IndustrySummary(
          industry: 'Industry $i',
          stockCount: 10,
          avgChangePct: i < 8 ? -1.5 : 0.5, // 80% down
          advance: i < 8 ? 3 : 7,
          decline: i < 8 ? 7 : 3,
        ),
      );

      final result = MarketInsightService.detect(
        industries: industries,
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 500,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final industryInsight = result.firstWhere(
        (i) => i.type == InsightType.industryConcentration,
      );
      expect(industryInsight.severity, InsightSeverity.warning);
    });

    test('returns max 4 insights sorted by priority', () {
      final industries = List.generate(
        10,
        (i) => IndustrySummary(
          industry: 'Industry $i',
          stockCount: 10,
          avgChangePct: 2.0, // 100% up
          advance: 8,
          decline: 2,
        ),
      );

      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 90,
          level: SentimentLevel.extremeGreed,
          subScores: {},
        ),
        streak: const InstitutionalStreak(foreignStreak: 10),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
        chipAnomalies: const [
          ChipAnomaly(
            type: ChipAnomalyType.highPledge,
            severity: ChipSeverity.high,
            symbol: '2330',
            stockName: '台積電',
            market: 'TWSE',
            i18nKey: 'test',
          ),
        ],
        limitUpDown: const LimitUpDown(limitUp: 50, limitDown: 2),
        margin: const MarginTradingTotals(
          marginBalance: 10000,
          marginChange: 500, // 5%
          shortBalance: 5000,
          shortChange: 0,
        ),
        industries: industries,
      );

      expect(result, hasLength(4));
      // Verify priority ordering: 10, 8, 7, 6
      expect(result[0].type, InsightType.sentimentExtreme);
      expect(result[1].type, InsightType.institutionalStreak);
      expect(result[2].type, InsightType.volumeAnomaly);
      expect(result[3].type, InsightType.chipAlert);
    });

    test('returns empty list when only 1 rule triggered (below minimum 2)', () {
      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 15,
          level: SentimentLevel.extremeFear,
          subScores: {},
        ),
      );

      expect(result, isEmpty);
    });

    test('returns empty list with all null inputs', () {
      final result = MarketInsightService.detect();
      expect(result, isEmpty);
    });

    test('returns 2 insights at minimum threshold', () {
      final result = MarketInsightService.detect(
        sentiment: const MarketSentiment(
          score: 90,
          level: SentimentLevel.extremeGreed,
          subScores: {},
        ),
        streak: const InstitutionalStreak(foreignStreak: 5),
      );

      expect(result, hasLength(2));
    });

    test('prefers foreign streak over trust when both qualify', () {
      final result = MarketInsightService.detect(
        streak: const InstitutionalStreak(foreignStreak: 8, trustStreak: -6),
        turnoverComparison: const TurnoverComparison(
          todayTurnover: 2000,
          avg5dTurnover: 1000,
        ),
      );

      expect(result, hasLength(2));
      final streakInsight = result.firstWhere(
        (i) => i.type == InsightType.institutionalStreak,
      );
      // Should pick foreign (checked first, breaks after first match)
      expect(streakInsight.descArgs['days'], '8');
    });
  });
}
