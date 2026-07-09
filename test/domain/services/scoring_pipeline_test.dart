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
        ),
      ).thenReturn(25);
      when(
        () => engine.calculateScore(
          any(),
          horizon: Horizon.long,
          calibratedScores: any(named: 'calibratedScores'),
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
