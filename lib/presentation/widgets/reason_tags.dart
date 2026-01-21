import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// Size variants for reason tags
enum ReasonTagSize {
  /// Compact size for card views (smaller padding, smaller text)
  compact,

  /// Normal size for detail views
  normal,
}

/// Reusable widget for displaying reason tags with consistent styling
class ReasonTags extends StatelessWidget {
  const ReasonTags({
    super.key,
    required this.reasons,
    this.size = ReasonTagSize.normal,
    this.maxTags,
    this.translateCodes = false,
  });

  /// List of reason labels or codes to display
  final List<String> reasons;

  /// Size variant for the tags
  final ReasonTagSize size;

  /// Maximum number of tags to display (null = show all)
  final int? maxTags;

  /// Whether to translate reason codes (for raw database codes)
  final bool translateCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayReasons = maxTags != null ? reasons.take(maxTags!) : reasons;

    final isCompact = size == ReasonTagSize.compact;

    return Wrap(
      spacing: isCompact ? 6 : 8,
      runSpacing: isCompact ? 4 : 8,
      children: displayReasons.map((reason) {
        final label = translateCodes ? translateReasonCode(reason) : reason;
        return _ReasonTag(
          label: label,
          isCompact: isCompact,
          isDark: isDark,
          theme: theme,
        );
      }).toList(),
    );
  }

  /// Convert database reason code to translated label
  static String translateReasonCode(String code) {
    final key = switch (code) {
      'REVERSAL_W2S' => 'reasons.reversalW2S',
      'REVERSAL_S2W' => 'reasons.reversalS2W',
      'TECH_BREAKOUT' => 'reasons.breakout',
      'TECH_BREAKDOWN' => 'reasons.breakdown',
      'VOLUME_SPIKE' => 'reasons.volumeSpike',
      'PRICE_SPIKE' => 'reasons.priceSpike',
      'INSTITUTIONAL_SHIFT' => 'reasons.institutional',
      'NEWS_RELATED' => 'reasons.news',
      _ => code, // fallback to original code if unknown
    };
    return key.tr();
  }
}

class _ReasonTag extends StatelessWidget {
  const _ReasonTag({
    required this.label,
    required this.isCompact,
    required this.isDark,
    required this.theme,
  });

  final String label;
  final bool isCompact;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.secondaryColor.withValues(alpha: 0.15)
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
      child: Text(
        label,
        style: (isCompact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(
          color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
