import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// A data holder for a single profitability metric (label + percentage value).
class ProfitMetric {
  const ProfitMetric(this.label, this.value);
  final String label;
  final double value;
}

/// Displays a card with key profitability metrics (gross margin, operating
/// margin, net margin, ROE) laid out in a horizontal row.
class ProfitabilityCard extends StatelessWidget {
  const ProfitabilityCard({super.key, required this.metrics});

  final Map<String, double> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = <ProfitMetric>[];
    if (metrics.containsKey('GrossProfit')) {
      items.add(
        ProfitMetric('stockDetail.grossMargin'.tr(), metrics['GrossProfit']!),
      );
    }
    if (metrics.containsKey('OperatingIncome')) {
      items.add(
        ProfitMetric(
          'stockDetail.operatingMargin'.tr(),
          metrics['OperatingIncome']!,
        ),
      );
    }
    if (metrics.containsKey('NetIncome')) {
      items.add(
        ProfitMetric('stockDetail.netMargin'.tr(), metrics['NetIncome']!),
      );
    }
    if (metrics.containsKey('ROE')) {
      items.add(ProfitMetric('stockDetail.roe'.tr(), metrics['ROE']!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 12),
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
                          const SizedBox(height: 4),
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
