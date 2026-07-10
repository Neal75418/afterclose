import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/scoring_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/price_data_generators.dart';

class MockRuleEngine extends Mock implements RuleEngine {}

void main() {
  group('classifyCandidate 資格檢查', () {
    DailyPriceEntry entry({double? close = 100, double? volume = 3000000}) =>
        DailyPriceEntry(
          symbol: 'T',
          date: DateTime(2026, 7, 8),
          close: close,
          volume: volume,
        );

    test('無價格資料 → noData', () {
      expect(classifyCandidate(null), CandidateSkipReason.noData);
      expect(classifyCandidate([]), CandidateSkipReason.noData);
    });

    test('歷史長度不足 swingWindow → insufficientData', () {
      final prices = List.generate(RuleParams.swingWindow - 1, (_) => entry());
      expect(classifyCandidate(prices), CandidateSkipReason.insufficientData);
    });

    test('close/volume 缺漏 → noData（MISSING_DATA 歸類）', () {
      final prices = [
        ...List.generate(RuleParams.swingWindow, (_) => entry()),
        entry(close: null),
      ];
      expect(classifyCandidate(prices), CandidateSkipReason.noData);
    });

    test('低流動性 → lowLiquidity', () {
      final prices = [
        ...List.generate(RuleParams.swingWindow, (_) => entry()),
        entry(volume: 1000),
      ];
      expect(classifyCandidate(prices), CandidateSkipReason.lowLiquidity);
    });

    test('資料充足且流動性合格 → null（通過）', () {
      final prices = generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 1000,
        spikeVolume: 5000,
      );
      final good = [...prices, entry()];
      expect(classifyCandidate(good), isNull);
    });
  });

  group('computeFundamentalDecayMultipliers 基本面遞減', () {
    final engine = RuleEngine();

    test('同組多條正分訊號按設計分數排序遞減 100/50/25', () {
      const reasons = [
        // 獲利組 4 條（2408 案例）：22 > 18 > 15，第 4 條也是 0.25
        TriggeredReason(
          type: ReasonType.epsConsecutiveGrowth,
          score: 22,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.roeExcellent,
          score: 18,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.roeImproving,
          score: 15,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.epsYoYSurge,
          score: 22,
          description: '',
        ),
        // 營收組 1 條：獨占全分
        TriggeredReason(
          type: ReasonType.revenueYoySurge,
          score: 20,
          description: '',
        ),
        // 非基本面：不受影響
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: '',
        ),
      ];

      final m = engine.computeFundamentalDecayMultipliers(reasons);

      // 獲利組排序 22(epsConsecutive)=22(epsYoy) 同分 → 穩定序，
      // 名次係數 1.0/0.5/0.25/0.25
      final earningsFactors = [
        m['EPS_CONSECUTIVE_GROWTH'],
        m['EPS_YOY_SURGE'],
        m['ROE_EXCELLENT'],
        m['ROE_IMPROVING'],
      ];
      expect(earningsFactors..sort(), [0.25, 0.25, 0.5, 1.0]);
      expect(m['REVENUE_YOY_SURGE'], 1.0);
      expect(m.containsKey('TECH_BREAKOUT'), isFalse);
    });

    test('負分警訊不分組不遞減', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.roeDeclining,
          score: -10,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.roeExcellent,
          score: 18,
          description: '',
        ),
      ];
      final m = engine.computeFundamentalDecayMultipliers(reasons);
      expect(m['ROE_EXCELLENT'], 1.0);
      expect(m.containsKey('ROE_DECLINING'), isFalse);
    });

    test('calculateScore 套用 multipliers 後總分遞減', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.epsConsecutiveGrowth,
          score: 22,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.roeExcellent,
          score: 18,
          description: '',
        ),
        TriggeredReason(
          type: ReasonType.roeImproving,
          score: 15,
          description: '',
        ),
      ];
      final m = engine.computeFundamentalDecayMultipliers(reasons);
      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        decayMultipliers: m,
      );
      // 22*1.0 + 18*0.5 + 15*0.25 = 34.75 → round 35（原 55）
      expect(score, 35);
    });
  });

  group('scoreReasonsDualHorizon 評分核心', () {
    late MockRuleEngine engine;
    const reasons = [
      TriggeredReason(
        type: ReasonType.techBreakout,
        score: 25,
        description: '',
      ),
    ];

    setUp(() {
      engine = MockRuleEngine();
      registerFallbackValue(<TriggeredReason>[]);
      registerFallbackValue(Horizon.short);
      registerFallbackValue(CalibratedScoreContext.empty);
      when(() => engine.applyMutexGroups(any(), any())).thenAnswer(
        (inv) => inv.positionalArguments[0] as List<TriggeredReason>,
      );
      when(
        () => engine.computeFundamentalDecayMultipliers(any()),
      ).thenReturn(const {});
      when(() => engine.getTopReasons(any())).thenAnswer(
        (inv) => inv.positionalArguments[0] as List<TriggeredReason>,
      );
    });

    test('雙 horizon 各自 calculateScore、任一達門檻即保留', () {
      when(
        () => engine.calculateScore(
          any(),
          horizon: Horizon.short,
          calibratedScores: any(named: 'calibratedScores'),
          decayMultipliers: any(named: 'decayMultipliers'),
        ),
      ).thenReturn(25);
      when(
        () => engine.calculateScore(
          any(),
          horizon: Horizon.long,
          calibratedScores: any(named: 'calibratedScores'),
          decayMultipliers: any(named: 'decayMultipliers'),
        ),
      ).thenReturn(0);

      final result = scoreReasonsDualHorizon(
        ruleEngine: engine,
        reasons: reasons,
        calibratedScores: CalibratedScoreContext.empty,
      );

      expect(result, isNotNull);
      expect(result!.scoreShort, 25);
      expect(result.scoreLong, 0);
      expect(result.topReasons, reasons);
      // mutex 應套三次：short scoring、long scoring、UI 顯示
      verify(() => engine.applyMutexGroups(any(), any())).called(3);
    });

    test('兩 horizon 都低於 observationScoreThreshold → null（過濾）', () {
      when(
        () => engine.calculateScore(
          any(),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
          decayMultipliers: any(named: 'decayMultipliers'),
        ),
      ).thenReturn(RuleParams.observationScoreThreshold - 1);

      final result = scoreReasonsDualHorizon(
        ruleEngine: engine,
        reasons: reasons,
        calibratedScores: CalibratedScoreContext.empty,
      );

      expect(result, isNull);
    });

    test('恰好等於門檻 → 保留（邊界含）', () {
      when(
        () => engine.calculateScore(
          any(),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
          decayMultipliers: any(named: 'decayMultipliers'),
        ),
      ).thenReturn(RuleParams.observationScoreThreshold);

      expect(
        scoreReasonsDualHorizon(
          ruleEngine: engine,
          reasons: reasons,
          calibratedScores: CalibratedScoreContext.empty,
        ),
        isNotNull,
      );
    });
  });
}
