import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Foreign shareholding section with ratio card + trend chart.
class ShareholdingSection extends StatelessWidget {
  const ShareholdingSection({super.key, required this.history});

  final List<ShareholdingEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'chip.sectionShareholding'.tr(),
            icon: Icons.language,
          ),
          const SizedBox(height: 12),
          _buildEmpty(theme),
        ],
      );
    }

    final sorted = List<ShareholdingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last;
    final ratio = latest.foreignSharesRatio ?? 0;

    // 判斷趨勢
    String trendKey = 'chip.trendStable';
    if (sorted.length >= 5) {
      final fiveDaysAgo = sorted[sorted.length - 5].foreignSharesRatio ?? 0;
      final diff = ratio - fiveDaysAgo;
      if (diff >= 0.1) trendKey = 'chip.trendIncreasing';
      if (diff <= -0.1) trendKey = 'chip.trendDecreasing';
    }

    final chartData = sorted
        .map((e) => (e.foreignSharesRatio ?? 0).toDouble())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionShareholding'.tr(),
          icon: Icons.language,
        ),
        const SizedBox(height: 12),

        // Summary card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.shareholdingRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ratio.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _trendColor(trendKey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Text(
                  trendKey.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _trendColor(trendKey),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Trend chart
        MiniTrendChart(
          dataPoints: chartData,
          lineColor: const Color(0xFF3498DB),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
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

  Color _trendColor(String key) {
    return switch (key) {
      'chip.trendIncreasing' => const Color(0xFF4CAF50),
      'chip.trendDecreasing' => const Color(0xFFF44336),
      _ => const Color(0xFF9E9E9E),
    };
  }
}
