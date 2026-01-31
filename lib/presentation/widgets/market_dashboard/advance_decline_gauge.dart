import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 漲跌家數 Donut Chart
///
/// 以 PieChart 呈現上漲/持平/下跌家數比例，右側顯示數字圖例
class AdvanceDeclineGauge extends StatelessWidget {
  const AdvanceDeclineGauge({super.key, required this.data});

  final AdvanceDecline data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.total;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.advanceDecline'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: data.advance.toDouble(),
                            color: AppTheme.upColor,
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: data.unchanged.toDouble(),
                            color: AppTheme.neutralColor.withValues(alpha: 0.4),
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: data.decline.toDouble(),
                            color: AppTheme.downColor,
                            radius: 20,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    // 中心文字
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // 圖例
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendRow(
                      color: AppTheme.upColor,
                      label: 'marketOverview.advance'.tr(),
                      value: data.advance,
                      percentage: (data.advance / total * 100),
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: AppTheme.neutralColor,
                      label: 'marketOverview.unchanged'.tr(),
                      value: data.unchanged,
                      percentage: (data.unchanged / total * 100),
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: AppTheme.downColor,
                      label: 'marketOverview.decline'.tr(),
                      value: data.decline,
                      percentage: (data.decline / total * 100),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  final Color color;
  final String label;
  final int value;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          '$value',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
