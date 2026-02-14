import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/taiwan_date_formatter.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';

/// Displays a table of the most recent 8 quarters of EPS data with
/// quarter-over-quarter growth badges.
class EpsTable extends StatelessWidget {
  const EpsTable({
    super.key,
    required this.epsHistory,
    required this.showROCYear,
  });

  final List<FinancialDataEntry> epsHistory;
  final bool showROCYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayData = epsHistory.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            buildTableHeader(context, [
              buildHeaderCell(context, 'stockDetail.quarter'.tr(), flex: 3),
              buildHeaderCell(
                context,
                'stockDetail.eps'.tr(),
                textAlign: TextAlign.end,
              ),
              buildHeaderCell(
                context,
                'stockDetail.qoqGrowth'.tr(),
                textAlign: TextAlign.end,
              ),
            ]),
            const SizedBox(height: 8),
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final eps = entry.value;
              final epsValue = eps.value;

              // 計算季增率
              double? qoqGrowth;
              if (index < displayData.length - 1) {
                final prevEps = displayData[index + 1].value;
                if (epsValue != null && prevEps != null && prevEps != 0) {
                  qoqGrowth = (epsValue - prevEps) / prevEps.abs() * 100;
                }
              }

              // 從日期格式化季度標籤
              final quarter = ((eps.date.month - 1) ~/ 3) + 1;
              final quarterLabel = showROCYear
                  ? TaiwanDateFormatter.formatQuarter(eps.date.year, quarter)
                  : '${eps.date.year} Q$quarter';

              return buildTableDataRow(context, index, [
                Expanded(
                  flex: 3,
                  child: Text(
                    quarterLabel,
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
                    epsValue != null ? epsValue.toStringAsFixed(2) : '-',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: epsValue != null && epsValue < 0
                          ? AppTheme.downColor
                          : null,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: buildGrowthBadge(context, qoqGrowth)),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}
