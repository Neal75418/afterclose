import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 成交額統計列
///
/// 顯示市場總成交額，單位為億元
class TradingTurnoverRow extends StatelessWidget {
  const TradingTurnoverRow({super.key, required this.data});

  final TradingTurnover data;

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

          // 數值
          Text(
            _formatTurnover(data.totalTurnover),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
