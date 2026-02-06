import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Shared helper widgets and formatting utilities used across chip tab sections.

Widget buildSummaryCard(
  BuildContext context,
  String label,
  double value,
  IconData icon,
  Color accentColor,
) {
  final theme = Theme.of(context);
  final isPositive = value >= 0;
  final valueColor = isPositive ? AppTheme.upColor : AppTheme.downColor;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          formatNet(value),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

Widget buildEmptyState(ThemeData theme) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
    ),
    child: Center(
      child: Text(
        'chip.noData'.tr(),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ),
  );
}

Widget buildColoredHeader(ThemeData theme, String label, Color color) {
  return Expanded(
    flex: 2,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    ),
  );
}

Widget buildDataRow(
  BuildContext context,
  ThemeData theme,
  int index,
  String dateLabel,
  List<double> values,
) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      color: index == 0
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : (index.isEven ? theme.colorScheme.surface : Colors.transparent),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        for (final v in values)
          Expanded(flex: 2, child: buildNetValue(context, v)),
      ],
    ),
  );
}

Widget buildNetValue(BuildContext context, double value) {
  final isPositive = value >= 0;
  final color = isPositive ? AppTheme.upColor : AppTheme.downColor;

  return Text(
    formatNet(value),
    textAlign: TextAlign.end,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
  );
}

/// Format net value with Chinese units (shares -> 張)
String formatNet(double value) {
  final prefix = value >= 0 ? '+' : '';
  final absValue = value.abs();
  final lots = absValue / 1000;

  if (lots >= 10000) {
    return '$prefix${(value / 1000 / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
  } else if (lots >= 1000) {
    return '$prefix${(value / 1000 / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
  } else if (lots >= 1) {
    return '$prefix${(value / 1000).toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
  }
  return '$prefix${value.toStringAsFixed(0)}';
}

/// Format balance with Chinese units (already in 張)
String formatBalance(double value) {
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
  }
  return '${value.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
}

/// Format shares change (in 千股)
String formatSharesChange(double value) {
  final prefix = value >= 0 ? '+' : '';
  final absValue = value.abs();
  if (absValue >= 1000) {
    return '$prefix${(value / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
  }
  return '$prefix${value.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
}
