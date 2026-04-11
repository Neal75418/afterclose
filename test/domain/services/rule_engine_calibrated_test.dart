// Stage 5b Commit 3 — horizon-aware calculateScore tests
//
// 驗證 [RuleEngine.calculateScore] 接受 `horizon` + `calibratedScores`
// 參數後，能正確依 horizon 查詢對應的 calibrated 值，且在查無時
// fallback 到 `TriggeredReason.score`（hardcoded embedded）。
//
// 這些測試是 Stage 5b Commit 3 的 TDD 起點：驗證邏輯正確性，
// 並鎖定 Stage 5a 的 fallback 語意（empty context = 舊行為）。
import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuleEngine engine;

  setUp(() {
    engine = RuleEngine();
  });

  group('calculateScore horizon-aware', () {
    test('empty context + short horizon falls back to reason.score', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
        TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'volume',
        ),
      ];

      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: CalibratedScoreContext.empty,
      );

      // 25 + 22 = 47（無 calibrated 時等於 Stage 5a 行為）
      expect(score, 47);
    });

    test('short calibrated overrides reason.score for short horizon', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 40},
        longScores: {},
      );

      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
      );

      expect(score, 40); // calibrated 40 取代 reason.score 25
    });

    test('long horizon queries longScores, ignoring shortScores', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 40},
        longScores: {'TECH_BREAKOUT': 10},
      );

      final shortScore = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
      );
      final longScore = engine.calculateScore(
        reasons,
        horizon: Horizon.long,
        calibratedScores: ctx,
      );

      expect(shortScore, 40);
      expect(longScore, 10);
    });

    test('unknown rule id falls back to reason.score', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'SOMETHING_ELSE': 99}, // 不是 TECH_BREAKOUT
        longScores: {},
      );

      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
      );

      expect(score, 25); // fallback 到 reason.score
    });

    test('mixed calibrated + fallback sums correctly in one list', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
        TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'volume',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 30}, // 覆蓋 techBreakout
        longScores: {},
        // volumeSpike 未 calibrated，使用 reason.score
      );

      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
      );

      // calibrated 30 + fallback 22 = 52
      expect(score, 52);
    });

    test('cooldown penalty applies after horizon-aware sum', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
        TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'volume',
        ),
      ];

      final normal = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: CalibratedScoreContext.empty,
      );
      final withCooldown = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: CalibratedScoreContext.empty,
        wasRecentlyRecommended: true,
      );

      expect(normal - withCooldown, RuleParams.cooldownPenalty);
    });

    test('clamps at RuleScores.maxScore across horizons', () {
      final reasons = List.generate(
        5,
        (_) => const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'x',
        ),
      );

      // 5 * 25 = 125，遠超 maxScore 80
      final shortScore = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: CalibratedScoreContext.empty,
      );
      final longScore = engine.calculateScore(
        reasons,
        horizon: Horizon.long,
        calibratedScores: CalibratedScoreContext.empty,
      );

      expect(shortScore, RuleScores.maxScore);
      expect(longScore, RuleScores.maxScore);
    });

    test('clamps at 0 when calibrated sum + cooldown goes negative', () {
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 5}, // 很低的 calibrated
        longScores: {},
      );

      // calibrated 5 - cooldownPenalty (15) = -10 → clamp 0
      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
        wasRecentlyRecommended: true,
      );

      expect(score, 0);
    });

    test('calibrated value of 0 overrides reason.score (not fallback)', () {
      // 邊界案例：明確校正為 0 的 rule 應被當成 0 採納，不是 null/missing
      const reasons = [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'breakout',
        ),
      ];

      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 0},
        longScores: {},
      );

      final score = engine.calculateScore(
        reasons,
        horizon: Horizon.short,
        calibratedScores: ctx,
      );

      expect(score, 0); // 不 fallback 到 25
    });

    test('empty reasons list returns 0 regardless of horizon', () {
      final shortScore = engine.calculateScore(
        const [],
        horizon: Horizon.short,
        calibratedScores: CalibratedScoreContext.empty,
      );
      final longScore = engine.calculateScore(
        const [],
        horizon: Horizon.long,
        calibratedScores: CalibratedScoreContext.empty,
      );

      expect(shortScore, 0);
      expect(longScore, 0);
    });
  });
}
