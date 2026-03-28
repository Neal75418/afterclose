import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 迷你柱狀圖（CustomPainter 實作，輕量無 fl_chart 依賴）
///
/// 用於法人買賣超、成交額等 30 日趨勢顯示。
/// 正值使用 [AppTheme.upColor]，負值使用 [AppTheme.downColor]。
/// 若所有值同號（如成交額皆為正），則使用 [positiveOnlyColor]。
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.dataPoints,
    this.height = 40,
    this.positiveOnlyColor,
    this.barRadius = 1.5,
  });

  /// 時序數值（oldest→newest）
  final List<double> dataPoints;
  final double height;

  /// 全為正值時的柱色（預設取 theme primary）
  final Color? positiveOnlyColor;

  /// 每根柱子的圓角半徑
  final double barRadius;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.length < 2) return SizedBox(height: height);

    final theme = Theme.of(context);
    final hasNegative = dataPoints.any((v) => v < 0);

    return Semantics(
      label: 'accessibility.barChart'.tr(),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarChartPainter(
            values: dataPoints,
            upColor: hasNegative
                ? AppTheme.upColor
                : (positiveOnlyColor ?? theme.colorScheme.primary),
            downColor: AppTheme.downColor,
            hasNegative: hasNegative,
            barRadius: barRadius,
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.upColor,
    required this.downColor,
    required this.hasNegative,
    required this.barRadius,
  });

  final List<double> values;
  final Color upColor;
  final Color downColor;
  final bool hasNegative;
  final double barRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final n = values.length;
    // 每根柱子佔 60% 寬度，40% 間距
    final barWidth = size.width / n * 0.6;
    final step = size.width / n;

    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);

    // 決定基準線位置
    double zeroY;
    double range;
    if (hasNegative) {
      // 有正有負：零線在中間（按比例）
      range = maxVal - minVal;
      if (range == 0) range = 1;
      zeroY = size.height * (maxVal / range);
    } else {
      // 全正值：基準線在底部，讓柱子有最小高度
      range = maxVal - minVal;
      if (range == 0) range = 1;
      zeroY = size.height;
    }

    final radius = Radius.circular(barRadius);

    for (int i = 0; i < n; i++) {
      final v = values[i];
      final x = step * i + (step - barWidth) / 2;

      double barTop;
      double barBottom;

      if (hasNegative) {
        final barHeight = (v.abs() / range) * size.height;
        if (v >= 0) {
          barTop = zeroY - barHeight;
          barBottom = zeroY;
        } else {
          barTop = zeroY;
          barBottom = zeroY + barHeight;
        }
      } else {
        // 全正值：映射到 [10%, 100%] 高度，避免最小值看不見
        final normalized = (v - minVal) / range;
        final barHeight = size.height * (0.1 + 0.9 * normalized);
        barTop = size.height - barHeight;
        barBottom = size.height;
      }

      // 確保柱子至少有 1px 高度
      if ((barBottom - barTop).abs() < 1) {
        barTop = barBottom - 1;
      }

      final paint = Paint()
        ..color = (v >= 0 ? upColor : downColor).withValues(alpha: 0.7);

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x, barTop, x + barWidth, barBottom),
        topLeft: v >= 0 ? radius : Radius.zero,
        topRight: v >= 0 ? radius : Radius.zero,
        bottomLeft: v < 0 ? radius : Radius.zero,
        bottomRight: v < 0 ? radius : Radius.zero,
      );

      canvas.drawRRect(rect, paint);
    }

    // 有正負值時畫零線
    if (hasNegative) {
      final zeroPaint = Paint()
        ..color = upColor.withValues(alpha: 0.2)
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      upColor != oldDelegate.upColor ||
      downColor != oldDelegate.downColor;
}
