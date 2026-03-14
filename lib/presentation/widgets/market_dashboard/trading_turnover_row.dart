import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 成交額統計列
///
/// 顯示市場總成交額，單位為億元
class TradingTurnoverRow extends StatelessWidget {
  const TradingTurnoverRow({
    super.key,
    required this.data,
    this.turnoverComparison,
  });

  final TradingTurnover data;
  final TurnoverComparison? turnoverComparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.totalTurnover == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 標籤
          Row(
            children: [
              Icon(
                Icons.paid_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'marketOverview.tradingTurnover'.tr(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          // 數值 + 均量比較
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTurnover(data.totalTurnover),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (turnoverComparison != null &&
                  turnoverComparison!.avg5dTurnover > 0) ...[
                const SizedBox(width: 8),
                _Avg5dBadge(changePercent: turnoverComparison!.changePercent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 格式化成交額顯示
  ///
  /// 將元轉換為億元顯示
  /// 例如：642195569620 → "6,421.96 億元"
  String _formatTurnover(double turnover) {
    if (turnover == 0) return '0 ${'marketOverview.unitBillion'.tr()}';

    final turnoverInHundredMillion = turnover / 100000000; // 轉換為億元

    if (turnoverInHundredMillion >= 10000) {
      // >= 10000 億（兆），顯示兩位小數
      final formatted = NumberFormat(
        '#,##0.00',
      ).format(turnoverInHundredMillion);
      return '$formatted ${'marketOverview.unitBillion'.tr()}';
    } else if (turnoverInHundredMillion >= 1000) {
      // >= 1000 億，顯示一位小數
      final formatted = NumberFormat(
        '#,##0.0',
      ).format(turnoverInHundredMillion);
      return '$formatted ${'marketOverview.unitBillion'.tr()}';
    } else {
      // < 1000 億，顯示兩位小數
      final formatted = NumberFormat(
        '#,##0.00',
      ).format(turnoverInHundredMillion);
      return '$formatted ${'marketOverview.unitBillion'.tr()}';
    }
  }
}

class _Avg5dBadge extends StatelessWidget {
  const _Avg5dBadge({required this.changePercent});

  final double changePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = changePercent > 0;
    final color = isUp
        ? AppTheme.upColor
        : changePercent < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final sign = isUp ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        color: color.withValues(alpha: 0.1),
      ),
      child: Text(
        '${'marketOverview.avg5d'.tr()} $sign${changePercent.toStringAsFixed(0)}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: DesignTokens.fontSizeXs,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
