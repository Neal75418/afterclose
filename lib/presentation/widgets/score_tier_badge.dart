import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/score_tier.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';

/// 分級徽章 + 小字數字（評分改進 #5）
///
/// 分數點值差異無統計意義（score-報酬 IC ≈ 0.17）——列表以強/中/弱
/// 分級為主視覺，確切分數退為小字輔助（診斷/驗證仍看得到）。
///
/// 雙 horizon 模式（[ScoreTierBadge.dual]）：徽章級別取兩者較高分
/// （與訊號成立「任一 horizon ≥ 門檻」同語意）；兩個 horizon 的
/// 小字數字與 5D/60D 標籤保留，分數相同時 collapse 成單一數字。
class ScoreTierBadge extends StatelessWidget {
  const ScoreTierBadge({super.key, required double score})
    : shortScore = score,
      longScore = score;

  const ScoreTierBadge.dual({
    super.key,
    required this.shortScore,
    required this.longScore,
  });

  final double shortScore;
  final double longScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayScore = shortScore > longScore ? shortScore : longScore;
    final tier = ScoreTier.fromScore(displayScore);
    final color = _tierColor(theme, tier);
    final collapsed = shortScore == longScore;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Text(
            tier.i18nKey.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        if (collapsed)
          _scoreText(theme, shortScore)
        else ...[
          _horizonScore(theme, '5D', shortScore),
          const SizedBox(width: 4),
          _horizonScore(theme, '60D', longScore),
        ],
      ],
    );
  }

  Widget _scoreText(ThemeData theme, double score) {
    return Text(
      score.toStringAsFixed(0),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 11,
        height: 1,
      ),
    );
  }

  Widget _horizonScore(ThemeData theme, String label, double score) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 8,
            height: 1,
          ),
        ),
        const SizedBox(height: 1),
        _scoreText(theme, score),
      ],
    );
  }

  Color _tierColor(ThemeData theme, ScoreTier tier) => switch (tier) {
    ScoreTier.strong => IndicatorColors.ratingStrong,
    ScoreTier.medium => IndicatorColors.ratingBullish,
    ScoreTier.weak => IndicatorColors.ratingNeutral,
    ScoreTier.observation => theme.colorScheme.onSurfaceVariant,
  };
}
