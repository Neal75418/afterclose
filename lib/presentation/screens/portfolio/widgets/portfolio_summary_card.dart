import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';

/// 投資組合總覽卡片
class PortfolioSummaryCard extends StatelessWidget {
  const PortfolioSummaryCard({super.key, required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = summary.totalPnl >= 0;
    final pnlColor = isPositive ? AppTheme.upColor : AppTheme.downColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'portfolio.summary'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),

          // 總市值
          Text(
            'NT\$${_formatNumber(summary.totalMarketValue)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 總損益
          Row(
            children: [
              Text(
                'portfolio.totalPnl'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isPositive ? "+" : ""}NT\$${_formatNumber(summary.totalPnl)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pnlColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${isPositive ? "+" : ""}${summary.totalPnlPct.toStringAsFixed(1)}%)',
                style: theme.textTheme.bodySmall?.copyWith(color: pnlColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 損益明細
          Row(
            children: [
              Expanded(
                child: _PnlItem(
                  label: 'portfolio.unrealizedPnl'.tr(),
                  value: summary.totalUnrealizedPnl,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _PnlItem(
                  label: 'portfolio.realizedPnl'.tr(),
                  value: summary.totalRealizedPnl,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _PnlItem(
                  label: 'portfolio.dividendIncome'.tr(),
                  value: summary.totalDividends,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value.abs() >= 1e8) {
      return '${(value / 1e8).toStringAsFixed(1)}億';
    }
    if (value.abs() >= 1e4) {
      return '${(value / 1e4).toStringAsFixed(1)}萬';
    }
    return value.toStringAsFixed(0);
  }
}

class _PnlItem extends StatelessWidget {
  const _PnlItem({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final double value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = value == 0
        ? theme.colorScheme.onSurface
        : (isPositive ? AppTheme.upColor : AppTheme.downColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${isPositive && value != 0 ? "+" : ""}${value.toStringAsFixed(0)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
