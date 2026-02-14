import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/core/utils/taiwan_date_formatter.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Displays a table of the most recent 5 years of dividend data with
/// a summary row showing the average cash dividend.
class DividendTable extends StatelessWidget {
  const DividendTable({
    super.key,
    required this.dividends,
    required this.showROCYear,
  });

  final List<FinMindDividend> dividends;
  final bool showROCYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort by year descending and take last 5
    final sortedData = List<FinMindDividend>.from(dividends)
      ..sort((a, b) => b.year.compareTo(a.year));
    final displayData = sortedData.take(5).toList();

    // Calculate average cash dividend for summary
    double totalCash = 0;
    for (final div in displayData) {
      totalCash += div.cashDividend;
    }
    final avgCash = displayData.isNotEmpty
        ? totalCash / displayData.length
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Average summary row
            if (displayData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.dividendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  border: Border.all(
                    color: AppTheme.dividendColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.payments,
                      size: 16,
                      color: AppTheme.dividendColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${displayData.length}年平均: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      AppNumberFormat.currency(avgCash, decimals: 2),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dividendColor,
                      ),
                    ),
                  ],
                ),
              ),
            buildTableHeader(context, [
              buildHeaderCell(context, 'stockDetail.dividendYear'.tr()),
              buildHeaderCell(
                context,
                'stockDetail.cashDividend'.tr(),
                textAlign: TextAlign.end,
              ),
              buildHeaderCell(
                context,
                'stockDetail.stockDividend'.tr(),
                textAlign: TextAlign.end,
              ),
              buildHeaderCell(
                context,
                'stockDetail.totalDividend'.tr(),
                textAlign: TextAlign.end,
              ),
            ]),
            const SizedBox(height: 8),
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final div = entry.value;
              final total = div.cashDividend + div.stockDividend;

              return buildTableDataRow(context, index, [
                Expanded(
                  flex: 2,
                  child: Text(
                    showROCYear
                        ? TaiwanDateFormatter.formatDualYear(div.year)
                        : div.year.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: index == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    div.cashDividend > 0
                        ? AppNumberFormat.currency(
                            div.cashDividend,
                            decimals: 2,
                          )
                        : '-',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: div.cashDividend > 0
                          ? AppTheme.dividendColor
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    div.stockDividend > 0
                        ? AppNumberFormat.currency(
                            div.stockDividend,
                            decimals: 2,
                          )
                        : '-',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    total > 0
                        ? AppNumberFormat.currency(total, decimals: 2)
                        : '-',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}
