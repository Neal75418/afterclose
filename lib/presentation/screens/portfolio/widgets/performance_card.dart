import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 投資組合績效卡片
///
/// 顯示期間報酬、最大回撤等績效指標
class PerformanceCard extends StatelessWidget {
  const PerformanceCard({super.key, required this.performance});

  final PortfolioPerformance performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'portfolio.performance'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 期間報酬
          _buildSectionLabel(theme, 'portfolio.periodReturns'.tr()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ReturnItem(
                  label: 'portfolio.daily'.tr(),
                  value: performance.periodReturns.daily,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _ReturnItem(
                  label: 'portfolio.weekly'.tr(),
                  value: performance.periodReturns.weekly,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _ReturnItem(
                  label: 'portfolio.monthly'.tr(),
                  value: performance.periodReturns.monthly,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _ReturnItem(
                  label: 'portfolio.yearly'.tr(),
                  value: performance.periodReturns.yearly,
                  theme: theme,
                  isAnnualized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 總報酬與最大回撤
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'portfolio.totalReturn'.tr(),
                  value: performance.totalReturn,
                  isPercentage: true,
                  theme: theme,
                ),
              ),
              Expanded(
                child: _MetricItem(
                  label: 'portfolio.maxDrawdown'.tr(),
                  value: -performance.maxDrawdown,
                  isPercentage: true,
                  isInverted: true,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ReturnItem extends StatelessWidget {
  const _ReturnItem({
    required this.label,
    required this.value,
    required this.theme,
    this.isAnnualized = false,
  });

  final String label;
  final double value;
  final ThemeData theme;
  final bool isAnnualized;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = value == 0
        ? theme.colorScheme.onSurface
        : (isPositive ? AppTheme.upColor : AppTheme.downColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (isAnnualized) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.info_outline,
                size: 12,
                color: theme.colorScheme.outline,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${isPositive ? "+" : ""}${value.toStringAsFixed(2)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.theme,
    this.isPercentage = false,
    this.isInverted = false,
  });

  final String label;
  final double value;
  final ThemeData theme;
  final bool isPercentage;
  final bool isInverted;

  @override
  Widget build(BuildContext context) {
    final displayValue = isInverted ? -value : value;
    final isPositive = displayValue >= 0;
    final color = displayValue == 0
        ? theme.colorScheme.onSurface
        : (isPositive ? AppTheme.upColor : AppTheme.downColor);

    String formatted;
    if (isPercentage) {
      final sign = value >= 0 ? (isInverted ? '' : '+') : '';
      formatted = '$sign${value.toStringAsFixed(2)}%';
    } else {
      formatted = '${isPositive ? "+" : ""}${value.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
