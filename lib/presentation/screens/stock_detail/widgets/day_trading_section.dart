import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Day trading section with ratio card + trend chart.
class DayTradingSection extends StatelessWidget {
  const DayTradingSection({super.key, required this.history});

  final List<DayTradingEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'chip.sectionDayTrading'.tr(),
            icon: Icons.flash_on,
          ),
          const SizedBox(height: 12),
          _buildEmpty(theme),
        ],
      );
    }

    final sorted = List<DayTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last;
    final latestRatio = latest.dayTradingRatio ?? 0;

    // 5-day average
    final recentCount = sorted.length >= 5 ? 5 : sorted.length;
    final recent = sorted.sublist(sorted.length - recentCount);
    double avg5 = 0;
    for (final e in recent) {
      avg5 += (e.dayTradingRatio ?? 0);
    }
    avg5 = avg5 / recentCount;

    final isHigh = latestRatio >= 35;

    final chartData = sorted
        .map((e) => (e.dayTradingRatio ?? 0).toDouble())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionDayTrading'.tr(),
          icon: Icons.flash_on,
        ),
        const SizedBox(height: 12),

        // Summary card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isHigh
                ? Border.all(color: AppTheme.downColor.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.dayTradingRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${latestRatio.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isHigh ? AppTheme.downColor : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.dayTradingAvg5'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${avg5.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Trend chart
        MiniTrendChart(
          dataPoints: chartData,
          lineColor: isHigh ? AppTheme.downColor : const Color(0xFFFF9800),
          minY: 0,
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
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
}
