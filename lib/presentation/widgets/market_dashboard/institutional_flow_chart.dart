import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 法人動向圖表
///
/// 以 3 根垂直 BarChart 呈現外資/投信/自營淨買賣，下方顯示金額
class InstitutionalFlowChart extends StatelessWidget {
  const InstitutionalFlowChart({super.key, required this.data});

  final InstitutionalTotals data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.totalNet == 0 &&
        data.foreignNet == 0 &&
        data.trustNet == 0 &&
        data.dealerNet == 0) {
      return const SizedBox.shrink();
    }

    final items = [
      _FlowItem(
        'marketOverview.foreign'.tr(),
        data.foreignNet,
        AppTheme.foreignColor,
      ),
      _FlowItem(
        'marketOverview.trust'.tr(),
        data.trustNet,
        AppTheme.investmentTrustColor,
      ),
      _FlowItem(
        'marketOverview.dealer'.tr(),
        data.dealerNet,
        AppTheme.dealerColor,
      ),
    ];

    // 計算最大絕對值作為 Y 軸範圍
    final maxAbs = items
        .map((e) => e.value.abs())
        .reduce((a, b) => a > b ? a : b);
    final yRange = maxAbs * 1.3; // 留 30% 頭部空間

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.institutional'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // Bar Chart
        SizedBox(
          height: 80,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yRange,
              minY: -yRange,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= items.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          items[idx].label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: items[idx].color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yRange,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(items.length, (i) {
                final item = items[i];
                final isPositive = item.value >= 0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: item.value,
                      color: isPositive
                          ? item.color
                          : item.color.withValues(alpha: 0.6),
                      width: 28,
                      borderRadius: isPositive
                          ? const BorderRadius.vertical(top: Radius.circular(6))
                          : const BorderRadius.vertical(
                              bottom: Radius.circular(6),
                            ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 金額數字行
        Row(
          children: items.map((item) {
            return Expanded(
              child: _AmountLabel(
                label: item.label,
                value: item.value,
                color: item.color,
              ),
            );
          }).toList(),
        ),

        // 合計
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${'marketOverview.totalNet'.tr()}: ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatAmount(data.totalNet),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: data.totalNet > 0
                    ? AppTheme.upColor
                    : data.totalNet < 0
                    ? AppTheme.downColor
                    : AppTheme.neutralColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatAmount(double value) {
    final absVal = value.abs();
    final sign = value > 0
        ? '+'
        : value < 0
        ? '-'
        : '';
    if (absVal >= 1e8) {
      return '$sign${(absVal / 1e8).toStringAsFixed(1)}億';
    } else if (absVal >= 1e4) {
      return '$sign${(absVal / 1e4).toStringAsFixed(0)}萬';
    }
    return '$sign${absVal.toStringAsFixed(0)}';
  }
}

class _FlowItem {
  const _FlowItem(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = value > 0
        ? AppTheme.upColor
        : value < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    return Column(
      children: [
        Text(
          _formatAmount(value),
          style: theme.textTheme.labelSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _formatAmount(double value) {
    final absVal = value.abs();
    final sign = value > 0
        ? '+'
        : value < 0
        ? '-'
        : '';
    if (absVal >= 1e8) {
      return '$sign${(absVal / 1e8).toStringAsFixed(1)}億';
    } else if (absVal >= 1e4) {
      return '$sign${(absVal / 1e4).toStringAsFixed(0)}萬';
    }
    return '$sign${absVal.toStringAsFixed(0)}';
  }
}
