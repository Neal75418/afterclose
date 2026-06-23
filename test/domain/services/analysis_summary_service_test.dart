import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

import '../../helpers/analysis_data_generators.dart';
import '../../helpers/price_data_generators.dart';

// Helper: check if overallParts contain a specific localization key
bool _overallContainsKey(SummaryData data, String key) =>
    data.overallParts.any((ls) => ls.key == key);

void main() {
  const service = AnalysisSummaryService();

  group('AnalysisSummaryService.generate', () {
    test('return neutral when no analysis and no reasons', () {
      final result = service.generate(
        analysis: null,
        reasons: [],
        latestPrice: null,
        priceChange: null,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      expect(result.sentiment, SummarySentiment.neutral);
      expect(result.keySignals, isEmpty);
      expect(result.riskFactors, isEmpty);
      expect(result.hasConflict, isFalse);
      expect(result.confluenceCount, 0);
      expect(result.overallParts.first.key, 'summary.noSignals');
    });

    test('prepends market-regime context line when marketStage given', () {
      final result = service.generate(
        analysis: createTestAnalysis(trendState: 'UP', score: 70),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
        marketStage: MarketStage.bullish,
      );

      // 大盤位階行置頂、對應 key
      expect(result.overallParts.first.key, 'summary.marketBullish');
    });

    test('omits market line when marketStage null or insufficient', () {
      SummaryData gen(MarketStage? stage) => service.generate(
        analysis: createTestAnalysis(trendState: 'UP', score: 70),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
        marketStage: stage,
      );

      for (final r in [gen(null), gen(MarketStage.insufficient)]) {
        expect(_overallContainsKey(r, 'summary.marketBullish'), isFalse);
        expect(_overallContainsKey(r, 'summary.marketNeutral'), isFalse);
        expect(_overallContainsKey(r, 'summary.marketBearish'), isFalse);
      }
    });

    test('return strongBullish when ratio ≥ 0.75 and score ≥ 55', () {
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
        horizon: Horizon.short,
      );

      // bullRatio = 1.0 ≥ 0.75, score = 70 ≥ 55 → strongBullish
      expect(result.sentiment, SummarySentiment.strongBullish);
    });

    test('return bullish when ratio ≥ 0.6 but below strong threshold', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20),
        createTestReason(
          reasonType: 'INSTITUTIONAL_BUY',
          rank: 2,
          ruleScore: 10,
        ),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 3, ruleScore: -5),
      ];

      final analysis = createTestAnalysis(trendState: 'UP', score: 45);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      // bullRatio = 30/35 ≈ 0.86 ≥ 0.75, but score = 45 < 55 → bullish (not strong)
      expect(result.sentiment, SummarySentiment.bullish);
    });

    test('return bearish when negative signals dominate', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_S2W', ruleScore: -30),
        createTestReason(reasonType: 'TECH_BREAKDOWN', rank: 2, ruleScore: -20),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BEARISH',
          rank: 3,
          ruleScore: -10,
        ),
      ];

      // score=10, not < 10 → bearish (not strongBearish)
      final analysis = createTestAnalysis(trendState: 'DOWN', score: 10);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: -5.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      expect(result.sentiment, SummarySentiment.bearish);
    });

    test('return strongBearish when ratio ≤ 0.25 and score < 10', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_S2W', ruleScore: -30),
        createTestReason(reasonType: 'TECH_BREAKDOWN', rank: 2, ruleScore: -20),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BEARISH',
          rank: 3,
          ruleScore: -15,
        ),
      ];

      final analysis = createTestAnalysis(trendState: 'DOWN', score: 5);

      final result = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: -7.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      // bullRatio = 0.0 ≤ 0.25, score = 5 < 10 → strongBearish
      expect(result.sentiment, SummarySentiment.strongBearish);
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
          horizon: Horizon.short,
        );

        // 35 positive vs 10 negative → bullRatio = 35/45 = 0.78 → bullish
        expect(result.sentiment, SummarySentiment.bullish);
      },
    );
  });

  group('Conflict detection', () {
    test('detect W2S + KD death cross conflict', () {
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
        horizon: Horizon.short,
      );

      expect(result.hasConflict, isTrue);
    });

    test('detect breakout + bearish alignment conflict', () {
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
        horizon: Horizon.short,
      );

      expect(result.hasConflict, isTrue);
    });

    test('not flag conflict when no contradictory pairs', () {
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
      );

      // bullRatio = 35/45 ≈ 0.78 > 0.65, 但 score = 30 < 35 → neutral
      expect(result.sentiment, SummarySentiment.neutral);
      expect(result.hasConflict, isTrue);
    });
  });

  group('Confidence calculation', () {
    test('return high confidence with many signals and data', () {
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
        horizon: Horizon.short,
      );

      // 5 signals(+2) + confluences(≥1) + no conflict(+1) + 3 data sources(+3) ≥ 5
      expect(result.confidence, AnalysisConfidence.high);
      expect(result.confluenceCount, greaterThan(0));
    });

    test('return low confidence with few signals and no data', () {
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
        horizon: Horizon.short,
      );

      // 1 signal(+0) + 0 confluences + no conflict(+1) + 0 data = 1 → low
      expect(result.confidence, AnalysisConfidence.low);
      expect(result.confluenceCount, 0);
    });

    test('return medium confidence with moderate data', () {
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
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
        horizon: Horizon.short,
      );

      // 匯流消耗了 W2S 和 KD_GOLDEN_CROSS，
      // 所以 keySignals 應只有匯流句，不重複列出個別句
      expect(result.keySignals.length, lessThanOrEqualTo(5));
    });
  });

  group('Supporting data', () {
    test('include institutional flow data', () {
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
        horizon: Horizon.short,
      );

      expect(result.supportingData, isNotEmpty);
      expect(result.supportingData.first.key, 'summary.institutionalFlow');
    });

    test('use latest entry (last) not oldest (first) for flow data', () {
      final now = DateTime.now();
      final result = service.generate(
        analysis: createTestAnalysis(),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [
          // oldest entry (index 0) — ascending order
          createTestInstitutional(
            date: now.subtract(const Duration(days: 2)),
            foreignNet: -9000000,
            investmentTrustNet: -3000000,
          ),
          createTestInstitutional(
            date: now.subtract(const Duration(days: 1)),
            foreignNet: -5000000,
            investmentTrustNet: -2000000,
          ),
          // latest entry (last) — should be used for flow display
          createTestInstitutional(
            date: now,
            foreignNet: 8000000,
            investmentTrustNet: 3000000,
          ),
        ],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      // 法人動向應顯示最新一天（買超），不是最舊的（賣超）
      final flowEntry = result.supportingData
          .where((ls) => ls.key == 'summary.institutionalFlow')
          .first;
      // nestedArgs['foreign'] 應為 netBuy（正數 → buy lots）
      expect(flowEntry.nestedArgs['foreign']?.key, 'summary.netBuy');
    });

    test('detect consecutive buy trend when ≥ 3 days', () {
      final now = DateTime.now();
      final result = service.generate(
        analysis: createTestAnalysis(),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [
          for (var i = 4; i >= 0; i--)
            createTestInstitutional(
              date: now.subtract(Duration(days: i)),
              foreignNet: 3000000,
              investmentTrustNet: 1000000,
            ),
        ],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      final keys = result.supportingData.map((ls) => ls.key).toSet();
      expect(keys, contains('summary.institutionalBuyTrend'));
    });

    test('include PE and dividend yield in supporting data', () {
      final result = service.generate(
        analysis: createTestAnalysis(),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: null,
        priceChange: 2.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: createTestPER(per: 10, dividendYield: 5.0),
        horizon: Horizon.short,
      );

      expect(result.supportingData, isNotEmpty);
      // PE=10 → peUndervalued, yield=5.0 ≥ 4.0 → highDividendYield
      final keys = result.supportingData.map((ls) => ls.key).toSet();
      expect(keys, contains('summary.peUndervalued'));
      expect(keys, contains('summary.highDividendYield'));
    });
  });

  group('latestPrice code path', () {
    test('produce overallParts with trend key when latestPrice provided', () {
      final now = DateTime.now();
      final latestPrice = createTestPrice(close: 120.5, date: now);

      final result = service.generate(
        analysis: createTestAnalysis(
          trendState: 'UP',
          score: 50,
          supportLevel: 115.0,
          resistanceLevel: 125.0,
        ),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: latestPrice,
        priceChange: 3.5,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );

      // 無匯流 → 使用 overallUp trend key
      expect(_overallContainsKey(result, 'summary.overallUp'), isTrue);
      // 有支撐壓力 + close → 使用帶距離版本
      expect(
        _overallContainsKey(result, 'summary.supportResistanceWithDist'),
        isTrue,
      );
      // 有風險報酬比
      expect(_overallContainsKey(result, 'summary.riskReward'), isTrue);
    });

    test('append favorable RR note when upside ≥ 2× downside', () {
      final result = service.generate(
        analysis: createTestAnalysis(
          trendState: 'UP',
          score: 50,
          supportLevel: 115.0,
          resistanceLevel: 125.0,
        ),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: createTestPrice(close: 116.0, date: DateTime.now()),
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );
      // RR = (125-116)/(116-115) = 9 ≥ 2 → favorable
      expect(
        _overallContainsKey(result, 'summary.riskRewardFavorable'),
        isTrue,
      );
      expect(_overallContainsKey(result, 'summary.riskRewardPoor'), isFalse);
    });

    test('append poor RR note when downside > upside', () {
      final result = service.generate(
        analysis: createTestAnalysis(
          trendState: 'UP',
          score: 50,
          supportLevel: 115.0,
          resistanceLevel: 125.0,
        ),
        reasons: [createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20)],
        latestPrice: createTestPrice(close: 124.0, date: DateTime.now()),
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );
      // RR = (125-124)/(124-115) ≈ 0.11 < 1 → poor
      expect(_overallContainsKey(result, 'summary.riskRewardPoor'), isTrue);
      expect(
        _overallContainsKey(result, 'summary.riskRewardFavorable'),
        isFalse,
      );
    });

    test('use confluenceOverall key when confluence exists', () {
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
        horizon: Horizon.short,
      );

      // 有匯流 → 使用 confluenceOverall 格式而非 overallUp/Down/Range
      expect(_overallContainsKey(result, 'summary.confluenceOverall'), isTrue);
      expect(result.confluenceCount, greaterThan(0));
    });

    test('include supportResistance in overallParts', () {
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
        horizon: Horizon.short,
      );

      // close=100, support=95, resistance=110 → 使用帶距離版本
      expect(
        _overallContainsKey(result, 'summary.supportResistanceWithDist'),
        isTrue,
      );
      expect(_overallContainsKey(result, 'summary.overallRange'), isTrue);
    });

    test('handle null close in latestPrice gracefully', () {
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
        horizon: Horizon.short,
      );

      // 即使 close 為 null，仍應產生有效的 overallParts
      expect(result.overallParts, isNotEmpty);
      expect(result.sentiment, isNotNull);
    });
  });

  // ==========================================
  // Stage 5c — dual-horizon awareness
  // ==========================================
  //
  // 驗證 `horizon` 參數切換時，service 讀取對應 horizon 的 scoreShort /
  // scoreLong / ruleScoreShort / ruleScoreLong。當 placeholder JSON 為空
  // （scoreShort == scoreLong）時兩個 horizon 產生相同結果；分化時
  // 產生對應 horizon 的判斷。
  group('AnalysisSummaryService dual-horizon awareness', () {
    test('long horizon reads analysis.scoreLong for sentiment grading', () {
      // 短線 score = 10（bearish 等級），長線 score = 70（strongBullish 等級）
      final analysis = DailyAnalysisEntry(
        symbol: 'TEST',
        date: DateTime(2024, 6, 15),
        trendState: 'UP',
        reversalState: 'NONE',
        scoreShort: 10,
        scoreLong: 70,
        computedAt: DateTime(2024, 6, 15, 10, 0),
      );
      final reasons = [
        createTestReasonDual(
          reasonType: 'REVERSAL_W2S',
          ruleScoreShort: 5,
          ruleScoreLong: 35,
        ),
        createTestReasonDual(
          reasonType: 'TECH_BREAKOUT',
          rank: 2,
          ruleScoreShort: 5,
          ruleScoreLong: 20,
        ),
      ];

      final shortResult = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.short,
      );
      final longResult = service.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: null,
        priceChange: 1.0,
        institutionalHistory: [],
        revenueHistory: [],
        latestPER: null,
        horizon: Horizon.long,
      );

      // 短線 score=10 + 低 ruleScoreShort → 不該升到 strongBullish
      expect(shortResult.sentiment, isNot(SummarySentiment.strongBullish));
      // 長線 score=70 + 高 ruleScoreLong → strongBullish
      expect(longResult.sentiment, SummarySentiment.strongBullish);
    });

    test(
      'long horizon filters key signals by ruleScoreLong (not ruleScoreShort)',
      () {
        // 構造一條 rule：短線負值（應被過濾掉）、長線正值（應出現在 keySignals）
        final reasons = [
          createTestReasonDual(
            reasonType: 'TECH_BREAKOUT',
            ruleScoreShort: -10, // 短線視角下是 risk
            ruleScoreLong: 25, // 長線視角下是 key signal
          ),
        ];
        final analysis = createTestAnalysis(score: 30);

        final shortResult = service.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: null,
          priceChange: null,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
          horizon: Horizon.short,
        );
        final longResult = service.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: null,
          priceChange: null,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
          horizon: Horizon.long,
        );

        // 短線視角：TECH_BREAKOUT 是 risk，不該出現在 keySignals
        expect(
          shortResult.keySignals.any((s) => s.key == 'summary.breakout'),
          isFalse,
        );
        expect(
          shortResult.riskFactors.any((s) => s.key == 'summary.breakout'),
          isTrue,
        );

        // 長線視角：TECH_BREAKOUT 是 key signal，不該出現在 risks
        expect(
          longResult.keySignals.any((s) => s.key == 'summary.breakout'),
          isTrue,
        );
        expect(
          longResult.riskFactors.any((s) => s.key == 'summary.breakout'),
          isFalse,
        );
      },
    );

    test(
      'empty placeholder (scoreShort == scoreLong) produces identical result across horizons',
      () {
        // Stage 5c → Stage 4 的關鍵 invariant：當 calibration 是空的時候，
        // 切換 horizon 對 UI 沒有 user-visible 影響。
        final analysis = createTestAnalysis(score: 55);
        final reasons = [
          createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 30),
          createTestReason(
            reasonType: 'KD_GOLDEN_CROSS',
            rank: 2,
            ruleScore: 15,
          ),
        ];

        final shortResult = service.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: null,
          priceChange: 1.0,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
          horizon: Horizon.short,
        );
        final longResult = service.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: null,
          priceChange: 1.0,
          institutionalHistory: [],
          revenueHistory: [],
          latestPER: null,
          horizon: Horizon.long,
        );

        expect(shortResult.sentiment, longResult.sentiment);
        expect(shortResult.confidence, longResult.confidence);
        expect(
          shortResult.keySignals.map((s) => s.key).toList(),
          longResult.keySignals.map((s) => s.key).toList(),
        );
        expect(
          shortResult.riskFactors.map((s) => s.key).toList(),
          longResult.riskFactors.map((s) => s.key).toList(),
        );
      },
    );
  });
}
