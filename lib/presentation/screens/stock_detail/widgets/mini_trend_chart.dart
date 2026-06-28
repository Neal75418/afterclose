import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 迷你趨勢折線圖（10-60 筆資料點）
///
/// 用於籌碼分頁的法人動向、外資持股、融資融券、當沖趨勢，以及大盤總覽的
/// 加權指數走勢、漲跌家數、AD 騰落線、融資融券走勢視覺化。
///
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

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i]));
    }

    // 未指定 Y 範圍時自動加 ~8% 上下留白：避免線條緊貼上下緣、fill 被壓成一條。
    double? effMinY = minY;
    double? effMaxY = maxY;
    if (minY == null && maxY == null) {
      final dMin = dataPoints.reduce(math.min);
      final dMax = dataPoints.reduce(math.max);
      final range = dMax - dMin;
      final pad = range.abs() < 1e-9 ? (dMax.abs() * 0.08 + 1) : range * 0.08;
      effMinY = dMin - pad;
      effMaxY = dMax + pad;
    }

    return Semantics(
      label: 'accessibility.trendChart'.tr(),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            // 安全裁切在盒內（直線 + Y padding 下通常不會裁到線）
            clipData: const FlClipData.all(),
            minY: effMinY,
            maxY: effMaxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                // 直線連接真實資料點（不做 bezier 平滑）：逐日走勢該有真實稜角，
                // 平滑曲線會腦補出沒發生的轉折、看起來像裝飾波浪而非真實數據。
                isCurved: false,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: showDots),
                belowBarData: BarAreaData(
                  show: true,
                  // 預設用線色面積漸層（上濃下透明），把細線變成有質感的面積圖；
                  // caller 指定 fillColor 時走平塗
                  color: fillColor,
                  gradient: fillColor == null
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.38),
                            color.withValues(alpha: 0.10),
                            color.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
