import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 融資融券精簡顯示
///
/// 兩欄並排，顯示融資增減和融券增減，帶漲跌箭頭
class MarginCompactRow extends StatelessWidget {
  const MarginCompactRow({super.key, required this.data});

  final MarginTradingTotals data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.marginChange == 0 && data.shortChange == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.margin'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MarginItem(
                label: 'marketOverview.marginBalance'.tr(),
                change: data.marginChange,
                balance: data.marginBalance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MarginItem(
                label: 'marketOverview.shortBalance'.tr(),
                change: data.shortChange,
                balance: data.shortBalance,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarginItem extends StatelessWidget {
  const _MarginItem({
    required this.label,
    required this.change,
    required this.balance,
  });

  final String label;
  final double change;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = change > 0
        ? AppTheme.upColor
        : change < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final icon = change > 0
        ? Icons.arrow_upward_rounded
        : change < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatSheets(change),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (balance != 0) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${'marketOverview.balance'.tr()} ${_formatBalance(balance)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化增減張數，大數字用「萬張」
  String _formatSheets(double value) {
    final absVal = value.abs();
    final sign = value > 0
        ? '+'
        : value < 0
        ? '-'
        : '';

    if (absVal >= 10000) {
      return '$sign${(absVal / 10000).toStringAsFixed(1)} 萬張';
    }
    return '$sign${NumberFormat('#,##0').format(absVal)} 張';
  }

  /// 格式化餘額（萬張/億張）
  String _formatBalance(double value) {
    final absVal = value.abs();
    if (absVal >= 1e8) {
      return '${(absVal / 1e8).toStringAsFixed(1)} 億張';
    } else if (absVal >= 10000) {
      return '${(absVal / 10000).toStringAsFixed(1)} 萬張';
    }
    return '${NumberFormat('#,##0').format(absVal)} 張';
  }
}
