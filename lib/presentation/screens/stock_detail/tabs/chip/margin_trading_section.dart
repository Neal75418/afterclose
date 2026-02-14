import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Displays margin trading data: summary cards, trend chart, and table.
class MarginTradingSection extends StatelessWidget {
  const MarginTradingSection({super.key, required this.history});

  final List<MarginTradingEntry> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (history.isNotEmpty) _buildSummary(context),

        if (history.isNotEmpty) const SizedBox(height: 12),

        SectionHeader(title: 'chip.sectionMargin'.tr(), icon: Icons.swap_horiz),
        const SizedBox(height: 12),

        if (history.isEmpty)
          buildEmptyState(context, 'chip.noData'.tr())
        else ...[
          _buildTrendChart(),
          const SizedBox(height: 12),
          _buildTable(context),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);

    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;
    final marginBal = latest.marginBalance ?? 0;
    final shortBal = latest.shortBalance ?? 0;

    // Compute short/margin ratio
    final shortMarginRatio = marginBal > 0 ? (shortBal / marginBal * 100) : 0.0;
    final isHighRatio = shortMarginRatio > 10;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              border: Border.all(
                color: AppTheme.upColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: AppTheme.upColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.marginBalance'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatBalance(marginBal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              border: Border.all(
                color:
                    (isHighRatio
                            ? AppTheme.downColor
                            : theme.colorScheme.outline)
                        .withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.percent,
                      size: 14,
                      color: isHighRatio
                          ? AppTheme.downColor
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.shortMarginRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${shortMarginRatio.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isHighRatio
                        ? AppTheme.downColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.length < 2) return const SizedBox.shrink();

    final data = sorted.map((e) => (e.marginBalance ?? 0).toDouble()).toList();
    return MiniTrendChart(
      dataPoints: data,
      lineColor: AppTheme.upColor,
      minY: 0,
    );
  }

  Widget _buildTable(BuildContext context) {
    final theme = Theme.of(context);

    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayData = sorted.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.date'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'chip.marginBalance'.tr(),
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
                      'chip.shortBalance'.tr(),
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
                      'chip.shortMarginRatio'.tr(),
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
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final margin = entry.value;
              final marginBal = margin.marginBalance ?? 0;
              final shortBal = margin.shortBalance ?? 0;
              final ratio = marginBal > 0 ? (shortBal / marginBal * 100) : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        )
                      : (index.isEven
                            ? theme.colorScheme.surface
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${margin.date.month}/${margin.date.day}',
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
                        formatBalance(marginBal),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatBalance(shortBal),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ratio > 10
                              ? AppTheme.downColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusXs,
                          ),
                        ),
                        child: Text(
                          '${ratio.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: ratio > 10
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: ratio > 10
                                ? AppTheme.downColor
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
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
