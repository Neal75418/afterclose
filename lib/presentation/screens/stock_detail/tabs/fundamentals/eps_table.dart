import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/taiwan_date_formatter.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Displays a table of the most recent 8 quarters of EPS data with
/// quarter-over-quarter growth badges.
class EpsTable extends StatelessWidget {
  const EpsTable({
    super.key,
    required this.epsHistory,
    required this.showROCYear,
  });

  final List<FinancialDataEntry> epsHistory;
  final bool showROCYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayData = epsHistory.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'stockDetail.quarter'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.eps'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.qoqGrowth'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Data rows
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final eps = entry.value;
              final epsValue = eps.value;

              // Calculate QoQ growth
              double? qoqGrowth;
              if (index < displayData.length - 1) {
                final prevEps = displayData[index + 1].value;
                if (epsValue != null && prevEps != null && prevEps != 0) {
                  qoqGrowth = (epsValue - prevEps) / prevEps.abs() * 100;
                }
              }

              // Format quarter label from date
              final quarter = ((eps.date.month - 1) ~/ 3) + 1;
              final quarterLabel = showROCYear
                  ? TaiwanDateFormatter.formatQuarter(eps.date.year, quarter)
                  : '${eps.date.year} Q$quarter';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: getRowColor(context, index),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        quarterLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        epsValue != null ? epsValue.toStringAsFixed(2) : '-',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: epsValue != null && epsValue < 0
                              ? AppTheme.downColor
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: buildGrowthBadge(context, qoqGrowth),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
