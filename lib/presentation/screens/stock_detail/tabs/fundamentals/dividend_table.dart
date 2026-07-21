import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/core/utils/taiwan_date_formatter.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 顯示近 5 年股利資料表，並附摘要列顯示平均現金股利。
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

    // 計算現金股利平均值供摘要使用
    double totalCash = 0;
    for (final div in displayData) {
      totalCash += div.cashDividend;
    }
    final avgCash = displayData.isNotEmpty
        ? totalCash / displayData.length
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        child: Column(
          children: [
            // 平均值摘要列
            if (displayData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing12),
                margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
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
                    // tint 底上的前景不得用 dividendColor 本色——淺色主題
                    // 對自身 @0.1 合成底僅 2.2:1，改依主題解析
                    Icon(
                      Icons.payments,
                      size: 16,
                      color: theme.brightness == Brightness.light
                          ? QualityColors.brandOnLight
                          : AppTheme.dividendColor,
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Text(
                      S.dividendYearAverage(displayData.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      AppNumberFormat.currency(avgCash, decimals: 2),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.light
                            ? QualityColors.brandOnLight
                            : AppTheme.dividendColor,
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
            const SizedBox(height: DesignTokens.spacing8),
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
