import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 單一獲利指標的資料容器（標籤 + 百分比值）。
class ProfitMetric {
  const ProfitMetric(this.label, this.value);
  final String label;
  final double value;
}

/// 顯示關鍵獲利指標卡片（毛利率、營業利益率、淨利率、ROE），
/// 以水平排列呈現。
class ProfitabilityCard extends StatelessWidget {
  const ProfitabilityCard({super.key, required this.metrics});

  final Map<String, double> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = <ProfitMetric>[];
    final revenue = metrics['Revenue'];

    // 毛利率 = GrossProfit / Revenue × 100
    if (metrics.containsKey('GrossProfit') && revenue != null && revenue != 0) {
      items.add(
        ProfitMetric(
          'stockDetail.grossMargin'.tr(),
          metrics['GrossProfit']! / revenue * 100,
        ),
      );
    }
    // 營業利益率 = OperatingIncome / Revenue × 100
    if (metrics.containsKey('OperatingIncome') &&
        revenue != null &&
        revenue != 0) {
      items.add(
        ProfitMetric(
          'stockDetail.operatingMargin'.tr(),
          metrics['OperatingIncome']! / revenue * 100,
        ),
      );
    }
    // 稅後淨利率 = NetIncome / Revenue × 100
    if (metrics.containsKey('NetIncome') && revenue != null && revenue != 0) {
      items.add(
        ProfitMetric(
          'stockDetail.netMargin'.tr(),
          metrics['NetIncome']! / revenue * 100,
        ),
      );
    }
    if (metrics.containsKey('ROE')) {
      items.add(ProfitMetric('stockDetail.roe'.tr(), metrics['ROE']!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'stockDetail.profitability'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: DesignTokens.spacing12),
            Row(
              children: items
                  .map(
                    (m) => Expanded(
                      child: Column(
                        children: [
                          Text(
                            m.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing4),
                          Text(
                            '${m.value.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: m.value >= 0
                                  ? AppTheme.upColor
                                  : AppTheme.downColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
