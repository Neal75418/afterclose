import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Displays insider holding data: ratios, shares change, and pledge warning.
class InsiderSection extends StatelessWidget {
  const InsiderSection({super.key, required this.history});

  final List<InsiderHoldingEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionInsider'.tr(),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        if (history.isEmpty) buildEmptyState(theme) else _buildCard(context),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<InsiderHoldingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    final insiderRatio = latest.insiderRatio ?? 0;
    final pledgeRatio = latest.pledgeRatio ?? 0;
    final sharesChange = latest.sharesChange ?? 0;
    final isHighPledge = pledgeRatio >= 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ratio row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'chip.insiderRatio'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${insiderRatio.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
                        'chip.pledgeRatio'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pledgeRatio.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighPledge ? AppTheme.downColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Shares change
            Row(
              children: [
                Text(
                  'chip.sharesChange'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatSharesChange(sharesChange),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: sharesChange > 0
                        ? AppTheme.upColor
                        : sharesChange < 0
                        ? AppTheme.downColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            // Pledge warning
            if (isHighPledge) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.downColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppTheme.downColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.pledgeWarning'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.downColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
