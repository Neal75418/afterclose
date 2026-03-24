import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// 顯示內部人持股資料：持股比例、持股變動與質押警示。
class InsiderSection extends StatelessWidget {
  const InsiderSection({super.key, required this.history});

  final List<InsiderHoldingEntry> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionInsider'.tr(),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: DesignTokens.spacing12),
        if (history.isEmpty)
          buildEmptyState(context, 'chip.noData'.tr())
        else
          _buildCard(context),
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
    final isHighPledge =
        pledgeRatio >= FundamentalParams.highPledgeRatioThreshold;

    // 依時間升冪排列（oldest first）供趨勢圖使用
    final insiderRatioHistory = sorted.reversed
        .map((e) => e.insiderRatio)
        .whereType<double>()
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 比率列
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
                      const SizedBox(height: DesignTokens.spacing4),
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
                      const SizedBox(height: DesignTokens.spacing4),
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

            const SizedBox(height: DesignTokens.spacing12),

            // 持股變動
            Row(
              children: [
                Text(
                  'chip.sharesChange'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing8),
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

            // 質押警示
            if (isHighPledge) ...[
              const SizedBox(height: DesignTokens.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing8,
                  vertical: DesignTokens.spacing4,
                ),
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
                    const SizedBox(width: DesignTokens.spacing4),
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

            // 董監持股比例趨勢圖（至少 2 筆資料才顯示）
            if (insiderRatioHistory.length >= 2) ...[
              const SizedBox(height: DesignTokens.spacing12),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'chip.insiderRatioTrend'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing4),
              MiniTrendChart(
                dataPoints: insiderRatioHistory,
                height: 56,
                lineColor: const Color(0xFF3498DB),
                fillColor: const Color(0xFF3498DB).withValues(alpha: 0.08),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
