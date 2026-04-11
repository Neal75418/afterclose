// Synthetic-data unit tests for tool/recalibrate.dart
//
// Tests the pure-math [Calibrator] class and data models using fabricated
// inputs. No DB or filesystem access. Verifies:
//   1. Proportion z-test (computeTStat) — happy path + degenerate cases
//   2. Linear map normalization (linearMapScore) — boundary behavior
//   3. Single-rule calibrate() — all 3 cut reasons + active branch
//   4. Batch calibrateAll() — normalization uses survivors only
//   5. CalibratedRule.toJson serialization shape

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/recalibrate.dart';

void main() {
  // ==========================================================================
  // computeTStat — proportion z-test
  // ==========================================================================

  group('Calibrator.computeTStat', () {
    test('happy path: hit_rate 0.65, n=100 → positive significant t-stat', () {
      final tStat = Calibrator.computeTStat(0.65, 100);
      // Expected: (0.65 - 0.5) / sqrt(0.65 × 0.35 / 100)
      //         = 0.15 / sqrt(0.002275)
      //         = 0.15 / 0.0477
      //         ≈ 3.1449
      expect(tStat, closeTo(3.1449, 0.01));
    });

    test('hit_rate 0.55, n=30 → t-stat around 0.548 (below 1.5 cut)', () {
      final tStat = Calibrator.computeTStat(0.55, 30);
      // (0.55 - 0.5) / sqrt(0.55 × 0.45 / 30) = 0.05 / 0.0908 ≈ 0.5505
      expect(tStat, closeTo(0.5505, 0.01));
      expect(tStat, lessThan(Calibrator.tStatCutThreshold));
    });

    test('hit_rate exactly 0.5 → t-stat = 0 (null hypothesis)', () {
      expect(Calibrator.computeTStat(0.5, 100), 0.0);
    });

    test('degenerate: hit_rate 0 → 0 (no variance)', () {
      expect(Calibrator.computeTStat(0.0, 100), 0.0);
    });

    test('degenerate: hit_rate 1.0 → 0 (no variance)', () {
      expect(Calibrator.computeTStat(1.0, 100), 0.0);
    });

    test('degenerate: n = 0 → 0', () {
      expect(Calibrator.computeTStat(0.6, 0), 0.0);
    });

    test('degenerate: n negative → 0', () {
      expect(Calibrator.computeTStat(0.6, -5), 0.0);
    });
  });

  // ==========================================================================
  // linearMapScore — min-max normalization to [10, 35]
  // ==========================================================================

  group('Calibrator.linearMapScore', () {
    test('raw == minRaw → score = minScore (10)', () {
      expect(Calibrator.linearMapScore(5.0, 5.0, 20.0), Calibrator.minScore);
    });

    test('raw == maxRaw → score = maxScore (35)', () {
      expect(Calibrator.linearMapScore(20.0, 5.0, 20.0), Calibrator.maxScore);
    });

    test('raw midpoint → score midpoint', () {
      // minRaw=0, maxRaw=10, raw=5 → 50% → score = 10 + 0.5 × 25 = 22.5 → round(22) or (23)
      final score = Calibrator.linearMapScore(5.0, 0.0, 10.0);
      expect(score, anyOf(22, 23));
    });

    test('edge: minRaw == maxRaw → returns midpoint of score range', () {
      // All rules have identical raw weight — can't normalize, fall back to midpoint
      expect(Calibrator.linearMapScore(7.0, 7.0, 7.0), 22); // (10+35)~/2
    });

    test('edge: maxRaw < minRaw → returns midpoint (defensive)', () {
      expect(Calibrator.linearMapScore(5.0, 10.0, 5.0), 22);
    });

    test('out of range: raw > maxRaw → clamped to maxScore', () {
      // raw > maxRaw should not produce score > 35
      expect(Calibrator.linearMapScore(100.0, 0.0, 10.0), Calibrator.maxScore);
    });

    test('out of range: raw < minRaw → clamped to minScore', () {
      expect(Calibrator.linearMapScore(-5.0, 0.0, 10.0), Calibrator.minScore);
    });
  });

  // ==========================================================================
  // calibrate — single-rule full pipeline
  // ==========================================================================

  group('Calibrator.calibrate', () {
    // Test isolation: use normalization range [0, 10] so mid-weights land in middle
    const minRaw = 0.0;
    const maxRaw = 10.0;

    RuleStats stats({
      String ruleId = 'test_rule',
      required double hitRate,
      required double avgReturn,
      required int triggerCount,
    }) {
      return RuleStats(
        ruleId: ruleId,
        hitRate: hitRate,
        avgReturn: avgReturn,
        triggerCount: triggerCount,
      );
    }

    test('active: happy path with passing thresholds', () {
      final result = Calibrator.calibrate(
        stats(hitRate: 0.60, avgReturn: 2.0, triggerCount: 100),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );

      expect(result.active, isTrue);
      expect(result.cutReason, isNull);
      expect(result.samples, 100);
      expect(result.hitRate, 0.60);
      expect(result.avgReturn, 2.0);
      expect(result.score, inInclusiveRange(10, 35));
    });

    test('cut: sample_too_small (n=29, just below threshold)', () {
      final result = Calibrator.calibrate(
        stats(hitRate: 0.80, avgReturn: 5.0, triggerCount: 29),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );

      expect(result.active, isFalse);
      expect(result.cutReason, 'sample_too_small');
      expect(result.score, 0);
    });

    test('cut: sample_too_small (n=0, defensive)', () {
      final result = Calibrator.calibrate(
        stats(hitRate: 0.80, avgReturn: 5.0, triggerCount: 0),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );

      expect(result.active, isFalse);
      expect(result.cutReason, 'sample_too_small');
    });

    test('cut: t_stat_below_threshold', () {
      // hit_rate 0.51 barely above null → z-test ≈ 0.11 with n=30
      final result = Calibrator.calibrate(
        stats(hitRate: 0.51, avgReturn: 2.0, triggerCount: 30),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );

      expect(result.active, isFalse);
      expect(result.cutReason, 't_stat_below_threshold');
      expect(result.tStat, lessThan(Calibrator.tStatCutThreshold));
    });

    test(
      'cut: hit_rate_below_threshold (t-stat passes but hit_rate < 0.55)',
      () {
        // hit_rate 0.54, n=500 → z ≈ 1.79 > 1.5 but hit_rate < 0.55
        final result = Calibrator.calibrate(
          stats(hitRate: 0.54, avgReturn: 2.0, triggerCount: 500),
          minRaw: minRaw,
          maxRaw: maxRaw,
        );

        expect(result.active, isFalse);
        expect(result.cutReason, 'hit_rate_below_threshold');
        expect(result.tStat, greaterThan(Calibrator.tStatCutThreshold));
      },
    );

    test('cut order: sample_size checked first', () {
      // All 3 thresholds fail, but sample_size reported first
      final result = Calibrator.calibrate(
        stats(hitRate: 0.40, avgReturn: 0.5, triggerCount: 10),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );
      expect(result.cutReason, 'sample_too_small');
    });

    test('cut order: t_stat checked before hit_rate', () {
      // hit_rate = 0.52 — would fail both t_stat and hit_rate cuts, but
      // t_stat should be reported (checked earlier in cut sequence).
      // Need samples ≥ 30 so we bypass sample check.
      // z = (0.52 - 0.5) / sqrt(0.52 × 0.48 / 50) = 0.02 / 0.0707 ≈ 0.283
      final result = Calibrator.calibrate(
        stats(hitRate: 0.52, avgReturn: 2.0, triggerCount: 50),
        minRaw: minRaw,
        maxRaw: maxRaw,
      );
      expect(result.cutReason, 't_stat_below_threshold');
    });
  });

  // ==========================================================================
  // calibrateAll — batch with survivor-only normalization
  // ==========================================================================

  group('Calibrator.calibrateAll', () {
    test('empty input → empty output', () {
      expect(Calibrator.calibrateAll([]), isEmpty);
    });

    test('all-cut input → all results marked inactive', () {
      // weak_edge: hit_rate 0.54 @ n=500 → z-test ≈ 1.79 passes, but
      //            hit_rate < 0.55 → cut as hit_rate_below_threshold.
      //            (hit_rate < 0.5 would give NEGATIVE z-stat, triggering
      //             t_stat_below_threshold cut first — not what we test here.)
      // tiny: hit_rate 0.70 but samples < 30 → cut as sample_too_small
      //       regardless of other metrics.
      final allStats = [
        const RuleStats(
          ruleId: 'weak_edge',
          hitRate: 0.54,
          avgReturn: 1.0,
          triggerCount: 500,
        ),
        const RuleStats(
          ruleId: 'tiny',
          hitRate: 0.70,
          avgReturn: 5.0,
          triggerCount: 10,
        ),
      ];
      final result = Calibrator.calibrateAll(allStats);

      expect(result.length, 2);
      for (final rule in result.values) {
        expect(rule.active, isFalse);
        expect(rule.score, 0);
      }
      expect(result['weak_edge']!.cutReason, 'hit_rate_below_threshold');
      expect(result['tiny']!.cutReason, 'sample_too_small');
    });

    test(
      'mixed active + cut: normalization uses survivors only, cut rules reported',
      () {
        // cut_hitrate uses hit_rate 0.54 @ n=500 so z-test passes (~1.79)
        // but hit_rate < 0.55 still triggers hit_rate_below_threshold cut.
        // avg_return is intentionally huge (50) to verify the survivor-only
        // normalization ignores this rule's raw weight even though it would
        // otherwise dominate the max.
        final allStats = [
          // Survivor (strong): highest raw weight
          const RuleStats(
            ruleId: 'strong',
            hitRate: 0.70,
            avgReturn: 5.0,
            triggerCount: 100,
          ),
          // Survivor (medium)
          const RuleStats(
            ruleId: 'medium',
            hitRate: 0.60,
            avgReturn: 3.0,
            triggerCount: 100,
          ),
          // Cut (hit_rate in weak edge zone 0.5 < h < 0.55)
          const RuleStats(
            ruleId: 'cut_hitrate',
            hitRate: 0.54,
            avgReturn: 50.0,
            triggerCount: 500,
          ),
        ];
        final result = Calibrator.calibrateAll(allStats);

        expect(result.length, 3);
        expect(result['strong']!.active, isTrue);
        expect(result['medium']!.active, isTrue);
        expect(result['cut_hitrate']!.active, isFalse);
        expect(result['cut_hitrate']!.cutReason, 'hit_rate_below_threshold');

        // 'strong' should have higher score than 'medium' within normalized range
        expect(result['strong']!.score, greaterThan(result['medium']!.score));

        // Both active scores in [10, 35]
        expect(result['strong']!.score, inInclusiveRange(10, 35));
        expect(result['medium']!.score, inInclusiveRange(10, 35));
      },
    );

    test('single survivor → gets midpoint score (no range to normalize)', () {
      final allStats = [
        const RuleStats(
          ruleId: 'lonely',
          hitRate: 0.65,
          avgReturn: 2.0,
          triggerCount: 100,
        ),
      ];
      final result = Calibrator.calibrateAll(allStats);

      expect(result['lonely']!.active, isTrue);
      // With only one survivor, minRaw == maxRaw → midpoint (22)
      expect(result['lonely']!.score, 22);
    });
  });

  // ==========================================================================
  // CalibratedRule.toJson — output schema fidelity
  // ==========================================================================

  group('CalibratedRule.toJson', () {
    test('active rule serializes all required fields without cut_reason', () {
      const stats = RuleStats(
        ruleId: 'test',
        hitRate: 0.60,
        avgReturn: 2.5,
        triggerCount: 100,
      );
      final rule = CalibratedRule.activeRule(
        stats: stats,
        tStat: 2.0,
        score: 20,
      );

      final json = rule.toJson();
      expect(json['score'], 20);
      expect(json['hit_rate'], 0.6);
      expect(json['avg_return'], 2.5);
      expect(json['samples'], 100);
      expect(json['t_stat'], 2.0);
      expect(json['active'], true);
      expect(json.containsKey('cut_reason'), isFalse);
    });

    test('cut rule serializes with cut_reason', () {
      const stats = RuleStats(
        ruleId: 'test',
        hitRate: 0.40,
        avgReturn: 1.0,
        triggerCount: 100,
      );
      final rule = CalibratedRule.cutRule(
        stats: stats,
        tStat: -2.0,
        reason: 'hit_rate_below_threshold',
      );

      final json = rule.toJson();
      expect(json['score'], 0);
      expect(json['active'], false);
      expect(json['cut_reason'], 'hit_rate_below_threshold');
    });

    test('rounding: hit_rate rounded to 4 decimal places', () {
      // hit_rate with many decimals → truncated to 4 in JSON
      const stats = RuleStats(
        ruleId: 'test',
        hitRate: 1 / 3, // 0.333333...
        avgReturn: 1.0,
        triggerCount: 100,
      );
      final rule = CalibratedRule.activeRule(
        stats: stats,
        tStat: 1.0,
        score: 10,
      );
      final json = rule.toJson();
      expect(json['hit_rate'], 0.3333);
    });
  });

  // ==========================================================================
  // rawWeight — sanity check
  // ==========================================================================

  group('Calibrator.rawWeight', () {
    test('formula: hit_rate × avg_return × sqrt(n)', () {
      const stats = RuleStats(
        ruleId: 't',
        hitRate: 0.6,
        avgReturn: 2.5,
        triggerCount: 100,
      );
      // 0.6 × 2.5 × sqrt(100) = 0.6 × 2.5 × 10 = 15.0
      expect(Calibrator.rawWeight(stats), closeTo(15.0, 1e-9));
    });

    test('sqrt(n) scaling dampens large n', () {
      const small = RuleStats(
        ruleId: 's',
        hitRate: 0.6,
        avgReturn: 2.5,
        triggerCount: 4,
      );
      const large = RuleStats(
        ruleId: 'l',
        hitRate: 0.6,
        avgReturn: 2.5,
        triggerCount: 16,
      );
      // small: 0.6 × 2.5 × 2 = 3.0
      // large: 0.6 × 2.5 × 4 = 6.0
      expect(Calibrator.rawWeight(small), closeTo(3.0, 1e-9));
      expect(Calibrator.rawWeight(large), closeTo(6.0, 1e-9));
      // 4× samples → 2× raw weight (sqrt scaling)
      expect(
        Calibrator.rawWeight(large),
        closeTo(2 * Calibrator.rawWeight(small), 1e-9),
      );
    });
  });

  // Unused import prevention — ensure `dart:math` import stays tied to Calibrator math
  test('sanity: dart:math sqrt exists', () {
    expect(sqrt(4), 2);
  });
}
