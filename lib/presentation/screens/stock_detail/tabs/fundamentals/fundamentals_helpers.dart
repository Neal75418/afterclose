import 'package:afterclose/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared helper widgets used across fundamentals section widgets.

/// Builds a growth badge showing a percentage with color coding.
///
/// Positive growth is shown in [AppTheme.upColor], negative in [AppTheme.downColor].
/// Values with absolute magnitude >= 10% get a tinted background and bold text.
Widget buildGrowthBadge(BuildContext context, double? growth) {
  final theme = Theme.of(context);

  if (growth == null) {
    return Text(
      '-',
      textAlign: TextAlign.end,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

  final isPositive = growth >= 0;
  final color = isPositive ? AppTheme.upColor : AppTheme.downColor;
  final prefix = isPositive ? '+' : '';
  final isSignificant = growth.abs() >= 10;

  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSignificant
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$prefix${growth.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSignificant ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ),
    ),
  );
}

/// Builds a loading placeholder with a centered circular progress indicator.
Widget buildLoadingState(BuildContext context) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(child: CircularProgressIndicator()),
  );
}

/// Builds an empty-state placeholder displaying [message].
Widget buildEmptyState(BuildContext context, String message) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ),
  );
}

/// Returns the alternating row background color for data tables.
///
/// Index 0 gets a highlighted primary container tint; even indices get
/// [surface]; odd indices are transparent.
Color? getRowColor(BuildContext context, int index) {
  final theme = Theme.of(context);

  if (index == 0) {
    return theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
  }
  if (index.isEven) {
    return theme.colorScheme.surface;
  }
  return Colors.transparent;
}
