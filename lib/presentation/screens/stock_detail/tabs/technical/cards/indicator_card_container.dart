import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';

/// 所有技術指標卡片共用的半透明容器。
class IndicatorCardContainer extends StatelessWidget {
  const IndicatorCardContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}

/// A label + value column used in MACD and Bollinger cards.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
