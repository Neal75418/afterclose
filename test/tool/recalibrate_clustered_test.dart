// Synthetic-data unit tests for the excess-aware clustered decision layer
// (docs/plans/2026-07-10-excess-decision-layer-clustered-tstat.md).
//
// Tests pure-math additions to [Calibrator]:
//   1. clusteredTStat — date-clustered one-sample t（Fama-MacBeth 式）
//   2. rawWeightClustered — hitRate × mean(dailyMeans) × sqrt(distinctDates)
//   3. calibrateAllClustered — 4 個 cut 順序 + baseline-relative hit cut
//      + survivors-only normalization

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibration_thresholds.dart';

import '../../tool/recalibrate.dart';

/// 造 [count] 天、每天日均值 [mean] ± 交錯 [jitter] 的序列（sd > 0）。
List<double> dailyMeansOf(int count, double mean, {double jitter = 0.1}) {
  return [for (var i = 0; i < count; i++) mean + (i.isEven ? jitter : -jitter)];
}

/// clustered 測資 helper：日數與觸發數皆過樣本 cut 的 stats。
RuleStats statsWith({
  String ruleId = 'r',
  double hitRate = 0.60,
  double avgReturn = 1.0,
  int triggerCount = 1000,
  required List<double> dailyMeans,
}) {
  return RuleStats(
    ruleId: ruleId,
    hitRate: hitRate,
    avgReturn: avgReturn,
    triggerCount: triggerCount,
    dailyMeans: dailyMeans,
  );
}

void main() {
  // ==========================================================================
  // clusteredTStat — 對「日均值序列」的 one-sample t
  // ==========================================================================

  group('Calibrator.clusteredTStat', () {
    test('happy path: 手算對照（mean/sd/sqrt(D)）', () {
      // 序列 [1, 2, 3]：mean=2, sd=1（樣本標準差）, D=3
      // t = 2 / (1 / sqrt(3)) = 2 × 1.7320 ≈ 3.4641
      expect(Calibrator.clusteredTStat([1, 2, 3]), closeTo(3.4641, 0.001));
    });

    test('負均值 → 負 t', () {
      expect(Calibrator.clusteredTStat([-1, -2, -3]), closeTo(-3.4641, 0.001));
    });

    test('D 大幅膨脹不再發生：同均值、日數 100 vs 名目 n 十萬無關', () {
      // 100 天、日均值 0.5、sd 0.1005 → t ≈ 0.5/(0.1005/10) ≈ 49.7
      // 重點：t 只由「日」數決定，與 pooled firings 數無關。
      final means = dailyMeansOf(100, 0.5);
      final t = Calibrator.clusteredTStat(means);
      expect(t, greaterThan(10));
      expect(t, lessThan(100)); // 不是 pooled 式的 |t| > 200 天文數字
    });

    test('degenerate: 空序列 → 0', () {
      expect(Calibrator.clusteredTStat(const []), 0.0);
    });

    test('degenerate: 單日 → 0（無法估變異）', () {
      expect(Calibrator.clusteredTStat(const [5.0]), 0.0);
    });

    test('degenerate: sd = 0（全同值）→ 0', () {
      expect(Calibrator.clusteredTStat(const [2.0, 2.0, 2.0]), 0.0);
    });
  });

  // ==========================================================================
  // rawWeightClustered
  // ==========================================================================

  group('Calibrator.rawWeightClustered', () {
    test('formula: hitRate × mean(dailyMeans) × sqrt(distinctDates)', () {
      final stats = statsWith(
        hitRate: 0.6,
        // 100 天、日均 2.5（jitter 對稱不影響 mean）
        dailyMeans: dailyMeansOf(100, 2.5),
      );
      // 0.6 × 2.5 × sqrt(100) = 15.0
      expect(Calibrator.rawWeightClustered(stats), closeTo(15.0, 1e-9));
    });

    test('權重由日數而非 pooled n 決定', () {
      final fewDays = statsWith(
        triggerCount: 100000, // pooled n 天文數字
        dailyMeans: dailyMeansOf(4, 2.5),
      );
      final manyDays = statsWith(
        triggerCount: 100, // pooled n 很小
        dailyMeans: dailyMeansOf(16, 2.5),
      );
      // sqrt(4)=2 vs sqrt(16)=4 → 日數多的權重大，與 triggerCount 無關
      expect(
        Calibrator.rawWeightClustered(manyDays),
        closeTo(2 * Calibrator.rawWeightClustered(fewDays), 1e-9),
      );
    });
  });

  // ==========================================================================
  // calibrateAllClustered — cut 順序與 baseline-relative hit cut
  // ==========================================================================

  group('Calibrator.calibrateAllClustered', () {
    const baseline = 0.47; // 超額模式典型 universe baseline（右偏 → 略低於 0.5）

    test('cut 1: triggerCount < 30 → sample_too_small', () {
      final result = Calibrator.calibrateAllClustered([
        statsWith(triggerCount: 29, dailyMeans: dailyMeansOf(60, 1.0)),
      ], baselineHit: baseline);
      expect(result['r']!.active, isFalse);
      expect(result['r']!.cutReason, 'sample_too_small');
    });

    test('cut 2: distinctDates < 30 → dates_too_few（新 cut）', () {
      final result = Calibrator.calibrateAllClustered([
        statsWith(dailyMeans: dailyMeansOf(29, 1.0)),
      ], baselineHit: baseline);
      expect(result['r']!.active, isFalse);
      expect(result['r']!.cutReason, 'dates_too_few');
    });

    test('cut 3: clustered t < 1.5 → t_stat_below_threshold', () {
      // 日均 0.01、jitter 0.5 → t 遠小於 1.5
      final result = Calibrator.calibrateAllClustered([
        statsWith(dailyMeans: dailyMeansOf(40, 0.01, jitter: 0.5)),
      ], baselineHit: baseline);
      expect(result['r']!.active, isFalse);
      expect(result['r']!.cutReason, 't_stat_below_threshold');
      // JSON 記錄的 tStat 是 clustered 量
      expect(
        result['r']!.tStat,
        closeTo(
          Calibrator.clusteredTStat(dailyMeansOf(40, 0.01, jitter: 0.5)),
          1e-9,
        ),
      );
    });

    test('cut 4: hitRate < baseline + lift → hit_rate_below_threshold', () {
      // t 顯著但 hit 只有 baseline + 4pp（< +5pp lift 門檻）
      final result = Calibrator.calibrateAllClustered([
        statsWith(hitRate: baseline + 0.04, dailyMeans: dailyMeansOf(60, 1.0)),
      ], baselineHit: baseline);
      expect(result['r']!.active, isFalse);
      expect(result['r']!.cutReason, 'hit_rate_below_threshold');
    });

    test('hit = baseline + lift 恰好過（>= 語意）', () {
      final result = Calibrator.calibrateAllClustered([
        statsWith(
          hitRate: baseline + CalibrationThresholds.hitRateLiftThreshold,
          dailyMeans: dailyMeansOf(60, 1.0),
        ),
      ], baselineHit: baseline);
      expect(result['r']!.active, isTrue);
    });

    test('絕對 0.55 門檻已不適用：hit 0.53 在 baseline 0.47 下存活', () {
      // 舊絕對 cut 會砍 0.53 < 0.55；新 lift cut：0.53 ≥ 0.47+0.05=0.52 → 活
      final result = Calibrator.calibrateAllClustered([
        statsWith(hitRate: 0.53, dailyMeans: dailyMeansOf(60, 1.0)),
      ], baselineHit: baseline);
      expect(result['r']!.active, isTrue);
    });

    test('倖存者 min-max normalize 到 [10, 35]、cut 者不參與 range', () {
      final result = Calibrator.calibrateAllClustered([
        statsWith(
          ruleId: 'weak',
          hitRate: 0.55,
          dailyMeans: dailyMeansOf(40, 0.5),
        ),
        statsWith(
          ruleId: 'strong',
          hitRate: 0.70,
          dailyMeans: dailyMeansOf(200, 3.0),
        ),
        // outlier 大權重但樣本不足 → cut，不得扭曲 normalization range
        statsWith(
          ruleId: 'cut-outlier',
          hitRate: 0.99,
          triggerCount: 5,
          dailyMeans: dailyMeansOf(5, 50.0),
        ),
      ], baselineHit: baseline);
      expect(result['weak']!.active, isTrue);
      expect(result['strong']!.active, isTrue);
      expect(result['cut-outlier']!.active, isFalse);
      // 兩個倖存者佔 min/max → 得端點分
      expect(result['weak']!.score, Calibrator.minScore);
      expect(result['strong']!.score, Calibrator.maxScore);
    });

    test('空輸入 → 空輸出', () {
      expect(
        Calibrator.calibrateAllClustered(const [], baselineHit: baseline),
        isEmpty,
      );
    });
  });

  // ==========================================================================
  // RuleStats.dailyMeans 預設值（向後相容）
  // ==========================================================================

  test('RuleStats 未給 dailyMeans → const []（舊路徑相容）', () {
    const stats = RuleStats(
      ruleId: 'legacy',
      hitRate: 0.6,
      avgReturn: 1.0,
      triggerCount: 100,
    );
    expect(stats.dailyMeans, isEmpty);
  });

  // 新常數 sanity
  test('CalibrationThresholds 新常數存在且值正確', () {
    expect(CalibrationThresholds.hitRateLiftThreshold, 0.05);
    expect(CalibrationThresholds.minDistinctDates, 30);
  });

  test('sanity: dart:math sqrt', () {
    expect(sqrt(9), 3);
  });
}
