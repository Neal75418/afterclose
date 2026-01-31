import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/domain/models/chip_strength.dart';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
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
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
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

          // Score + progress bar
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
                  borderRadius: BorderRadius.circular(4),
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

          // Institutional attitude
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
      ChipRating.strong => const Color(0xFF4CAF50),
      ChipRating.bullish => const Color(0xFF8BC34A),
      ChipRating.neutral => const Color(0xFFFFC107),
      ChipRating.bearish => const Color(0xFFFF9800),
      ChipRating.weak => const Color(0xFFF44336),
    };
  }

  Color _attitudeColor(InstitutionalAttitude attitude, ThemeData theme) {
    return switch (attitude) {
      InstitutionalAttitude.aggressiveBuy => const Color(0xFF4CAF50),
      InstitutionalAttitude.moderateBuy => const Color(0xFF8BC34A),
      InstitutionalAttitude.neutral => theme.colorScheme.onSurfaceVariant,
      InstitutionalAttitude.moderateSell => const Color(0xFFFF9800),
      InstitutionalAttitude.aggressiveSell => const Color(0xFFF44336),
    };
  }
}
