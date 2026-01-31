import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 報酬分佈直方圖
class ReturnDistributionChart extends StatelessWidget {
  const ReturnDistributionChart({super.key, required this.distribution});

  /// bucket label → count
  final Map<String, int> distribution;

  static const _bucketLabels = [
    '< -10%',
    '-10~-5%',
    '-5~0%',
    '0~5%',
    '5~10%',
    '> 10%',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = distribution.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'backtest.returnDistribution'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? maxCount.toDouble() * 1.2 : 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = _bucketLabels[group.x];
                        final count = rod.toY.toInt();
                        return BarTooltipItem(
                          '$label\n$count',
                          theme.textTheme.bodySmall!.copyWith(
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return Text(
                              value.toInt().toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _bucketLabels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _bucketLabels[idx],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _gridInterval(maxCount.toDouble()),
                  ),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_bucketLabels.length, (index) {
      final label = _bucketLabels[index];
      final count = distribution[label] ?? 0;
      // 前 3 個 bucket 是負報酬（綠），後 3 個是正報酬（紅）
      final isNegative = index < 3;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: isNegative ? AppTheme.downColor : AppTheme.upColor,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  double _gridInterval(double maxValue) {
    if (maxValue <= 5) return 1;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    return 20;
  }
}
