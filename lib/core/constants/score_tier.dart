import 'package:afterclose/core/constants/rule_params.dart';

/// 分數分級（呈現層）
///
/// 分數點值差異無統計意義（score-報酬 IC ≈ 0.17），列表以分級為主視覺、
/// 確切分數退為小字輔助。邊界見 [RuleParams.tierStrongThreshold] docstring。
enum ScoreTier {
  strong,
  medium,
  weak,

  /// 訊號未成立（< [RuleParams.minScoreThreshold]），觀察區專用。
  observation;

  static ScoreTier fromScore(double score) {
    if (score >= RuleParams.tierStrongThreshold) return ScoreTier.strong;
    if (score >= RuleParams.tierMediumThreshold) return ScoreTier.medium;
    if (score >= RuleParams.minScoreThreshold) return ScoreTier.weak;
    return ScoreTier.observation;
  }

  String get i18nKey => switch (this) {
    ScoreTier.strong => 'score.tier.strong',
    ScoreTier.medium => 'score.tier.medium',
    ScoreTier.weak => 'score.tier.weak',
    ScoreTier.observation => 'score.tier.observation',
  };
}
