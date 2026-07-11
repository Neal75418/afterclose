// ScoreTier 測試 — 分數分級（2026-07 評分改進 #5）
//
// 分級邊界依 2026-07-11 本機 DB 實測訊號區分數分佈：
// P50=28、P75=41 → 強 [45,∞)、中 [25,45)、弱 [12,25)、觀察 [0,12)
// 約對應 19% / 40% / 41% 的訊號區組成。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/constants/score_tier.dart';

void main() {
  group('ScoreTier.fromScore', () {
    test('≥ 45 → strong', () {
      expect(ScoreTier.fromScore(45), ScoreTier.strong);
      expect(ScoreTier.fromScore(80), ScoreTier.strong);
    });

    test('[25, 45) → medium', () {
      expect(ScoreTier.fromScore(25), ScoreTier.medium);
      expect(ScoreTier.fromScore(44), ScoreTier.medium);
      expect(ScoreTier.fromScore(44.9), ScoreTier.medium);
    });

    test('[12, 25) → weak（訊號成立下限起算）', () {
      expect(ScoreTier.fromScore(12), ScoreTier.weak);
      expect(ScoreTier.fromScore(24.9), ScoreTier.weak);
    });

    test('< 12 → observation（觀察區、訊號未成立）', () {
      expect(ScoreTier.fromScore(11.9), ScoreTier.observation);
      expect(ScoreTier.fromScore(8), ScoreTier.observation);
      expect(ScoreTier.fromScore(0), ScoreTier.observation);
    });

    test('邊界值來自 RuleParams 常數（不得 hardcode 漂移）', () {
      expect(
        ScoreTier.fromScore(RuleParams.tierStrongThreshold.toDouble()),
        ScoreTier.strong,
      );
      expect(
        ScoreTier.fromScore(RuleParams.tierMediumThreshold.toDouble()),
        ScoreTier.medium,
      );
      expect(
        ScoreTier.fromScore(RuleParams.minScoreThreshold.toDouble()),
        ScoreTier.weak,
      );
    });
  });

  group('ScoreTier.i18nKey', () {
    test('對應 score.tier.* 命名', () {
      expect(ScoreTier.strong.i18nKey, 'score.tier.strong');
      expect(ScoreTier.medium.i18nKey, 'score.tier.medium');
      expect(ScoreTier.weak.i18nKey, 'score.tier.weak');
      expect(ScoreTier.observation.i18nKey, 'score.tier.observation');
    });
  });
}
