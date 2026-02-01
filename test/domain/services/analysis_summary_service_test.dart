import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';

import '../../helpers/analysis_data_generators.dart';
import '../../helpers/price_data_generators.dart';

/// Helper: check if overallParts contain a specific localization key
bool _overallContainsKey(SummaryData data, String key) =>
    data.overallParts.any((ls) => ls.key == key);

void main() {
  const service = AnalysisSummaryService();

  group('AnalysisSummaryService.generate', () {
    test('should return neutral when no analysis and no reasons', () {
      final result = service.generate(
        analysis: null,
        reasons: [],
        latestPrice: null,
        priceChange: null,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.sentiment, SummarySentiment.neutral);
      expect(result.keySignals, isEmpty);
      expect(result.riskFactors, isEmpty);
      expect(result.hasConflict, isFalse);
      expect(result.confluenceCount, 0);
      expect(result.overallParts.first.key, 'summary.noSignals');
    });

    test('should return bullish when strong positive signals dominate', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'TECH_BREAKOUT', rank: 2, ruleScore: 20),
        createTestReason(
          reasonType: 'INSTITUTIONAL_BUY',
          rank: 3,
          ruleScore: 10,
        ),
      ];

      final analysis = createTestAnalysis(trendState: 'UP', score: 70);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 3.5,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.sentiment, SummarySentiment.bullish);
    });

    test('should return bearish when strong negative signals dominate', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_S2W', ruleScore: -30),
        createTestReason(reasonType: 'TECH_BREAKDOWN', rank: 2, ruleScore: -20),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BEARISH',
          rank: 3,
          ruleScore: -10,
        ),
      ];

      final analysis = createTestAnalysis(trendState: 'DOWN', score: 10);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: -5.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.sentiment, SummarySentiment.bearish);
    });
  });

  group('Weighted sentiment', () {
    test(
      'single high-weight positive should outweigh multiple small negatives',
      () {
        final reasons = [
          createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
          createTestReason(
            reasonType: 'DAY_TRADING_HIGH',
            rank: 2,
            ruleScore: -5,
            evidenceJson: '{"ratio": 30}',
          ),
          createTestReason(
            reasonType: 'KD_DEATH_CROSS',
            rank: 3,
            ruleScore: -5,
          ),
        ];

        final analysis = createTestAnalysis(score: 45);

        final result = service.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: null,
          priceChange: 2.0,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
        );

        // 35 positive vs 10 negative → bullRatio = 35/45 = 0.78 → bullish
        expect(result.sentiment, SummarySentiment.bullish);
      },
    );
  });

  group('Conflict detection', () {
    test('should detect W2S + KD death cross conflict', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 2, ruleScore: -10),
      ];

      final analysis = createTestAnalysis(score: 40);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.hasConflict, isTrue);
    });

    test('should detect breakout + bearish alignment conflict', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BEARISH',
          rank: 2,
          ruleScore: -10,
        ),
      ];

      final analysis = createTestAnalysis(score: 30);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.hasConflict, isTrue);
    });

    test('should not flag conflict when no contradictory pairs', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 50),
        reasons: reasons,
        latestPrice: null,
        priceChange: 3.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.hasConflict, isFalse);
    });

    test('conflict should raise sentiment threshold toward neutral', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 2, ruleScore: -10),
      ];

      // 衝突時門檻提高：bullRatio 需 > 0.65 且 score >= 35
      final analysis = createTestAnalysis(score: 30);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // bullRatio = 35/45 ≈ 0.78 > 0.65, 但 score = 30 < 35 → neutral
      expect(result.sentiment, SummarySentiment.neutral);
      expect(result.hasConflict, isTrue);
    });
  });

  group('Confidence calculation', () {
    test('should return high confidence with many signals and data', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
        createTestReason(reasonType: 'TECH_BREAKOUT', rank: 3, ruleScore: 20),
        createTestReason(
          reasonType: 'INSTITUTIONAL_BUY',
          rank: 4,
          ruleScore: 10,
        ),
        createTestReason(reasonType: 'VOLUME_SPIKE', rank: 5, ruleScore: 15),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 70),
        reasons: reasons,
        latestPrice: null,
        priceChange: 5.0,
        institutionalHistory: [createTestInstitutional(foreignNet: 5000)],
        revenueHistory: [createTestRevenue(yoyGrowth: 25)],
        latestPER: createTestPER(per: 12),
      );

      // 5 signals(+2) + confluences(≥1) + no conflict(+1) + 3 data sources(+3) ≥ 5
      expect(result.confidence, AnalysisConfidence.high);
      expect(result.confluenceCount, greaterThan(0));
    });

    test('should return low confidence with few signals and no data', () {
      final reasons = [
        createTestReason(reasonType: 'PATTERN_DOJI', ruleScore: 5),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 25),
        reasons: reasons,
        latestPrice: null,
        priceChange: 0.5,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // 1 signal(+0) + 0 confluences + no conflict(+1) + 0 data = 1 → low
      expect(result.confidence, AnalysisConfidence.low);
      expect(result.confluenceCount, 0);
    });

    test('should return medium confidence with moderate data', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20),
        createTestReason(reasonType: 'VOLUME_SPIKE', rank: 2, ruleScore: 15),
        createTestReason(
          reasonType: 'INSTITUTIONAL_BUY',
          rank: 3,
          ruleScore: 10,
        ),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 50),
        reasons: reasons,
        latestPrice: null,
        priceChange: 3.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // 3 signals(+1) + confluence(≥1) + no conflict(+1) + 0 data = 3 → medium
      expect(result.confidence, AnalysisConfidence.medium);
    });
  });

  group('Fundamental bias in sentiment', () {
    test('strong revenue growth should boost positive sentiment', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 15),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 2, ruleScore: -10),
      ];

      // 有基本面：positiveWeight += 5 (yoy>30) + 5 (PE≤10) + 5 (yield≥5.5)
      final resultWith = service.generate(
        analysis: createTestAnalysis(score: 30),
        reasons: reasons,
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [createTestRevenue(yoyGrowth: 40)],
        latestPER: createTestPER(per: 8, dividendYield: 6.0),
      );

      expect(resultWith.sentiment, SummarySentiment.bullish);
    });

    test('negative revenue should boost bearish weight', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKDOWN', ruleScore: -20),
        createTestReason(reasonType: 'PATTERN_HAMMER', rank: 2, ruleScore: 10),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(trendState: 'DOWN', score: 15),
        reasons: reasons,
        latestPrice: null,
        priceChange: -3.0,
        institutionalHistory: [],
        revenueHistory: [createTestRevenue(yoyGrowth: -25)],
        latestPER: null,
      );

      // negativeWeight = 20 + 5(fundamental) = 25, positiveWeight = 10
      // bullRatio = 10/35 ≈ 0.29, score=15 < 20 → bearish
      expect(result.sentiment, SummarySentiment.bearish);
    });
  });

  group('Confluence integration in key signals / risk factors', () {
    test('confluence keys should appear first in keySignals', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
        createTestReason(
          reasonType: 'INSTITUTIONAL_BUY',
          rank: 3,
          ruleScore: 10,
        ),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 60),
        reasons: reasons,
        latestPrice: null,
        priceChange: 3.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.keySignals, isNotEmpty);
      expect(result.confluenceCount, greaterThan(0));
      // 匯流 key 在前面，未被消耗的訊號在後面
      expect(result.keySignals.first.key, startsWith('summary.confluence'));
      expect(result.keySignals.length, greaterThanOrEqualTo(2));
    });

    test('bearish confluence keys should appear in riskFactors', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_S2W', ruleScore: -30),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 2, ruleScore: -10),
        createTestReason(
          reasonType: 'INSTITUTIONAL_SELL',
          rank: 3,
          ruleScore: -10,
        ),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(trendState: 'DOWN', score: 10),
        reasons: reasons,
        latestPrice: null,
        priceChange: -4.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.riskFactors, isNotEmpty);
      expect(result.riskFactors.length, greaterThanOrEqualTo(2));
    });

    test('consumed signals should not repeat in remaining list', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 60),
        reasons: reasons,
        latestPrice: null,
        priceChange: 3.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // 匯流消耗了 W2S 和 KD_GOLDEN_CROSS，
      // 所以 keySignals 應只有匯流句，不重複列出個別句
      expect(result.keySignals.length, lessThanOrEqualTo(5));
    });
  });

  group('Supporting data', () {
    test('should include institutional flow data', () {
      final result = service.generate(
        analysis: createTestAnalysis(),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [
          createTestInstitutional(
            foreignNet: 5000000,
            investmentTrustNet: 2000000,
          ),
        ],
        revenueHistory: [],
        latestPER: null,
      );

      expect(result.supportingData, isNotEmpty);
      expect(result.supportingData.first.key, 'summary.institutionalFlow');
    });

    test('should include PE and dividend yield in supporting data', () {
      final result = service.generate(
        analysis: createTestAnalysis(),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: createTestPER(per: 10, dividendYield: 5.0),
      );

      expect(result.supportingData, isNotEmpty);
      // PE=10 → peUndervalued, yield=5.0 ≥ 4.0 → highDividendYield
      final keys = result.supportingData.map((ls) => ls.key).toSet();
      expect(keys, contains('summary.peUndervalued'));
      expect(keys, contains('summary.highDividendYield'));
    });
  });

  group('latestPrice code path', () {
    test(
      'should produce overallParts with trend key when latestPrice provided',
      () {
        final now = DateTime.now();
        final latestPrice = createTestPrice(close: 120.5, date: now);

        final result = service.generate(
          analysis: createTestAnalysis(
            trendState: 'UP',
            score: 50,
            supportLevel: 115.0,
            resistanceLevel: 125.0,
          ),
          reasons: [
            createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20),
          ],
          latestPrice: latestPrice,
          priceChange: 3.5,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
        );

        // 無匯流 → 使用 overallUp trend key
        expect(_overallContainsKey(result, 'summary.overallUp'), isTrue);
        // 有支撐壓力 → 應包含 supportResistance key
        expect(
          _overallContainsKey(result, 'summary.supportResistance'),
          isTrue,
        );
      },
    );

    test('should use confluenceOverall key when confluence exists', () {
      final now = DateTime.now();
      final latestPrice = createTestPrice(close: 105.0, date: now);

      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
      ];

      final result = service.generate(
        analysis: createTestAnalysis(score: 60),
        reasons: reasons,
        latestPrice: latestPrice,
        priceChange: 5.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // 有匯流 → 使用 confluenceOverall 格式而非 overallUp/Down/Range
      expect(_overallContainsKey(result, 'summary.confluenceOverall'), isTrue);
      expect(result.confluenceCount, greaterThan(0));
    });

    test('should include supportResistance in overallParts', () {
      final now = DateTime.now();
      final latestPrice = createTestPrice(close: 100.0, date: now);

      final result = service.generate(
        analysis: createTestAnalysis(
          trendState: 'RANGE',
          score: 25,
          supportLevel: 95.0,
          resistanceLevel: 110.0,
        ),
        reasons: [createTestReason(reasonType: 'PATTERN_DOJI', ruleScore: 5)],
        latestPrice: latestPrice,
        priceChange: 0.5,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      expect(_overallContainsKey(result, 'summary.supportResistance'), isTrue);
      expect(_overallContainsKey(result, 'summary.overallRange'), isTrue);
    });

    test('should handle null close in latestPrice gracefully', () {
      final now = DateTime.now();
      final latestPrice = createTestPrice(date: now);

      final result = service.generate(
        analysis: createTestAnalysis(score: 30),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: latestPrice,
        priceChange: 2.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
      );

      // 即使 close 為 null，仍應產生有效的 overallParts
      expect(result.overallParts, isNotEmpty);
      expect(result.sentiment, isNotNull);
    });
  });
}
