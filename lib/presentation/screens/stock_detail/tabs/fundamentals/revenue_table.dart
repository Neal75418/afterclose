import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/utils/taiwan_date_formatter.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';

/// Displays a table of the most recent 12 months of revenue data with
/// month-over-month and year-over-year growth badges.
class RevenueTable extends StatelessWidget {
  const RevenueTable({
    super.key,
    required this.revenues,
    required this.showROCYear,
  });

  final List<FinMindRevenue> revenues;
  final bool showROCYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort by date descending and take last 12
    final sortedData = List<FinMindRevenue>.from(revenues)
      ..sort((a, b) {
        final yearCompare = b.revenueYear.compareTo(a.revenueYear);
        if (yearCompare != 0) return yearCompare;
        return b.revenueMonth.compareTo(a.revenueMonth);
      });
    final displayData = sortedData.take(12).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            buildTableHeader(context, [
              buildHeaderCell(
                context,
                'stockDetail.revenueMonth'.tr(),
                flex: 3,
              ),
              buildHeaderCell(
                context,
                'stockDetail.revenueAmount'.tr(),
                flex: 3,
                textAlign: TextAlign.end,
              ),
              buildHeaderCell(
                context,
                'stockDetail.revenueMoM'.tr(),
                textAlign: TextAlign.end,
              ),
              buildHeaderCell(
                context,
                'stockDetail.revenueYoY'.tr(),
                textAlign: TextAlign.end,
              ),
            ]),
            const SizedBox(height: 8),
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final rev = entry.value;

              return buildTableDataRow(context, index, [
                Expanded(
                  flex: 3,
                  child: Text(
                    showROCYear
                        ? TaiwanDateFormatter.formatYearMonth(
                            rev.revenueYear,
                            rev.revenueMonth,
                          )
                        : '${rev.revenueYear}/${rev.revenueMonth.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: index == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatRevenue(rev.revenue),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: buildGrowthBadge(context, rev.momGrowth),
                ),
                Expanded(
                  flex: 2,
                  child: buildGrowthBadge(context, rev.yoyGrowth),
                ),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  String _formatRevenue(double revenue) {
    // Revenue is in thousands (千元), convert to 億
    if (revenue >= 100000) {
      return '${(revenue / 100000).toStringAsFixed(1)}${'stockDetail.unitBillion'.tr()}';
    } else if (revenue >= 10000) {
      return '${(revenue / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}';
    }
    return '${revenue.toStringAsFixed(0)}${'stockDetail.unitThousand'.tr()}';
  }
}
