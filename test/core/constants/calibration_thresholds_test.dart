// Drift-prevention guardrail for calibration thresholds.
//
// Three writers stamp the rule_accuracy table:
//   1. RuleAccuracyService (app runtime)
//   2. replay_calibrator (Stage 4 tool)
//   3. recalibrate.dart (Stage 4 tool)
//
// 過去這三處各自寫死數字，註解寫「對齊 X」但實際值不同 →
// rule_accuracy 表內容受最後 writer 影響，calibration JSON 不可重現。
// 現在三處都讀 CalibrationThresholds — 這支 test 鎖住 canonical 值，
// 任何人想偷改某一處會被擋下。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibration_thresholds.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';

void main() {
  group('CalibrationThresholds canonical values', () {
    test('successThresholds match canonical values', () {
      // 5D / 60D 走實證 calibration 校正值（2 年市場資料下的「1σ-above-noise」)。
      // 10D / 20D 走 Stage 2 LEAN plan 原設計值，待後續實證 follow-up。
      // 改動任何值前請先更新 calibration_thresholds.dart docstring。
      expect(CalibrationThresholds.successThresholds[5], equals(1.5));
      expect(CalibrationThresholds.successThresholds[10], equals(5.0));
      expect(CalibrationThresholds.successThresholds[20], equals(8.0));
      expect(CalibrationThresholds.successThresholds[60], equals(8.0));
    });

    test('1D and 3D fall back to defaultSuccessThreshold (no entry)', () {
      // 短線雜訊大，門檻嚴反而測不出真訊號 → 1D / 3D 不列出，走 default。
      expect(CalibrationThresholds.successThresholds.containsKey(1), isFalse);
      expect(CalibrationThresholds.successThresholds.containsKey(3), isFalse);
      expect(CalibrationThresholds.defaultSuccessThreshold, equals(0.0));
    });

    test('cut thresholds match scoring overhaul plan', () {
      // Plan：hit_rate < 55% 砍 / |t-stat| < 1.5 砍 / samples < 30 砍
      expect(CalibrationThresholds.hitRateCutThreshold, equals(0.55));
      expect(CalibrationThresholds.tStatCutThreshold, equals(1.5));
      expect(CalibrationThresholds.sampleSizeCutThreshold, equals(30));
    });
  });

  group('Drift prevention — writers share canonical thresholds', () {
    test(
      'RuleAccuracyService.successThresholds === CalibrationThresholds.successThresholds',
      () {
        // 確保 RuleAccuracyService 沒有重新 hardcode 自己一份。
        // 任何人偷改 service 內 const 都會在這支 test 失敗。
        expect(
          RuleAccuracyService.successThresholds,
          same(CalibrationThresholds.successThresholds),
          reason: 'RuleAccuracyService 必須 import canonical 常數，不可重新定義',
        );
      },
    );

    // 註：tool/replay_calibrator.dart 與 tool/recalibrate.dart 對 canonical
    // 常數的依賴透過 `import + 直接讀`保證 — 不寫死數字。flutter analyze 會
    // 在被 import 後仍重新定義 const 時提示 unused field，這是 build-time
    // guardrail（沒辦法在 unit test 內 import tool/ 檔做 runtime 驗證，
    // 因為它們是 main() entry-point 而不是 library）。
  });
}
