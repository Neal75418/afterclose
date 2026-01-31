import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_header.dart';

/// Overlay price chart that normalizes all stocks to % change from day-0.
class PriceOverlayChart extends StatelessWidget {
  const PriceOverlayChart({
    super.key,
    required this.symbols,
    required this.priceHistoriesMap,
    required this.stocksMap,
  });

  final List<String> symbols;
  final Map<String, List<DailyPriceEntry>> priceHistoriesMap;
  final Map<String, StockMasterEntry> stocksMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineData = _buildLineData();

    if (lineData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'comparison.chartTitle'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: lineData,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calcInterval(lineData),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final color = spot.bar.color ?? Colors.grey;
                          final symbol = spot.barIndex < symbols.length
                              ? symbols[spot.barIndex]
                              : '';
                          return LineTooltipItem(
                            '$symbol: ${spot.y.toStringAsFixed(1)}%',
                            TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineData() {
    final lines = <LineChartBarData>[];

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      final history = priceHistoriesMap[symbol];
      if (history == null || history.isEmpty) continue;

      // Sort by date ascending
      final sorted = List<DailyPriceEntry>.from(history)
        ..sort((a, b) => a.date.compareTo(b.date));

      final basePrice = sorted.first.close;
      if (basePrice == null || basePrice == 0) continue;

      final spots = <FlSpot>[];
      for (var j = 0; j < sorted.length; j++) {
        final close = sorted[j].close;
        if (close == null) continue;
        final pctChange = ((close / basePrice) - 1) * 100;
        spots.add(FlSpot(j.toDouble(), pctChange));
      }

      if (spots.isEmpty) continue;

      lines.add(
        LineChartBarData(
          spots: spots,
          color: comparisonColors[i % comparisonColors.length],
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return lines;
  }

  double _calcInterval(List<LineChartBarData> lines) {
    double maxVal = 0;
    for (final line in lines) {
      for (final spot in line.spots) {
        maxVal = max(maxVal, spot.y.abs());
      }
    }
    if (maxVal < 5) return 2;
    if (maxVal < 15) return 5;
    if (maxVal < 50) return 10;
    return 20;
  }

  Widget _buildLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (var i = 0; i < symbols.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: comparisonColors[i % comparisonColors.length],
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${symbols[i]} ${stocksMap[symbols[i]]?.name ?? ''}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
      ],
    );
  }
}
