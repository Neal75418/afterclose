import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';

/// 持倉配置圓餅圖
class AllocationPieChart extends StatelessWidget {
  const AllocationPieChart({super.key, required this.allocationMap});

  /// symbol -> 百分比
  final Map<String, double> allocationMap;

  static const _colors = DesignTokens.chartPalette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (allocationMap.isEmpty) return const SizedBox.shrink();

    final entries = allocationMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'portfolio.allocation'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            children: [
              // 圓餅圖
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sections: _buildSections(entries),
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 圖例
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < entries.length && i < 6; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[i % _colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${entries[i].key} ${entries[i].value.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
  ) {
    return [
      for (int i = 0; i < entries.length; i++)
        PieChartSectionData(
          value: entries[i].value,
          color: _colors[i % _colors.length],
          radius: 40,
          showTitle: entries[i].value >= 10,
          title: '${entries[i].value.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];
  }
}
