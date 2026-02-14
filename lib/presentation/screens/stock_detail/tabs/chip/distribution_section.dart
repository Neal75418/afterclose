import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';

/// Displays holding distribution data as horizontal bar charts.
class DistributionSection extends StatelessWidget {
  const DistributionSection({super.key, required this.distribution});

  final List<HoldingDistributionEntry> distribution;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionDistribution'.tr(),
          icon: Icons.pie_chart_outline,
        ),
        const SizedBox(height: 12),
        if (distribution.isEmpty)
          buildEmptyState(context, 'chip.noData'.tr())
        else
          _buildBars(context),
      ],
    );
  }

  Widget _buildBars(BuildContext context) {
    final theme = Theme.of(context);

    // 依百分比分組顯示各級距
    final sorted = List<HoldingDistributionEntry>.from(distribution)
      ..sort((a, b) => (b.percent ?? 0).compareTo(a.percent ?? 0));

    // Take top 8 levels for display
    final display = sorted.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: display.map((entry) {
            final pct = entry.percent ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(entry.level, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct > 20
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
