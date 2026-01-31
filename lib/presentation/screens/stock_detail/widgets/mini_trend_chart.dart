import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A compact line chart for showing trends (10-60 data points).
///
/// Used in the chip analysis tab for institutional flow,
/// shareholding, margin, and day trading trend visualization.
class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({
    super.key,
    required this.dataPoints,
    this.height = 80,
    this.lineColor,
    this.fillColor,
    this.showDots = false,
    this.minY,
    this.maxY,
  });

  /// Y-values in chronological order (oldest first).
  final List<double> dataPoints;
  final double height;
  final Color? lineColor;
  final Color? fillColor;
  final bool showDots;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.length < 2) return SizedBox(height: height);

    final theme = Theme.of(context);
    final color = lineColor ?? theme.colorScheme.primary;
    final fill = fillColor ?? color.withValues(alpha: 0.1);

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i]));
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: showDots),
              belowBarData: BarAreaData(show: true, color: fill),
            ),
          ],
        ),
      ),
    );
  }
}
