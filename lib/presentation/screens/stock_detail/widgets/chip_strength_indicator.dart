import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Top banner card showing chip strength score (0-100) with progress bar
/// and institutional attitude label.
class ChipStrengthIndicator extends StatelessWidget {
  const ChipStrengthIndicator({super.key, required this.strength});

  final ChipStrengthResult strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _ratingColor(strength.rating);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              Icon(Icons.battery_charging_full, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                'chip.strength'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 評等徽章
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Text(
                  strength.rating.i18nKey.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 分數＋進度條
          Row(
            children: [
              Text(
                '${strength.score}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' / 100',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                  child: LinearProgressIndicator(
                    value: strength.score / 100,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 法人態度
          Row(
            children: [
              Text(
                'chip.institutionalAttitude'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strength.attitude.i18nKey.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _attitudeColor(strength.attitude, theme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _ratingColor(ChipRating rating) {
    return switch (rating) {
      ChipRating.strong => IndicatorColors.ratingStrong,
      ChipRating.bullish => IndicatorColors.ratingBullish,
      ChipRating.neutral => IndicatorColors.ratingNeutral,
      ChipRating.bearish => IndicatorColors.ratingBearish,
      ChipRating.weak => IndicatorColors.ratingWeak,
    };
  }

  Color _attitudeColor(InstitutionalAttitude attitude, ThemeData theme) {
    return switch (attitude) {
      InstitutionalAttitude.aggressiveBuy => IndicatorColors.ratingStrong,
      InstitutionalAttitude.moderateBuy => IndicatorColors.ratingBullish,
      InstitutionalAttitude.neutral => theme.colorScheme.onSurfaceVariant,
      InstitutionalAttitude.moderateSell => IndicatorColors.ratingBearish,
      InstitutionalAttitude.aggressiveSell => IndicatorColors.ratingWeak,
    };
  }
}
