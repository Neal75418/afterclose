import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 依數值取柱色——嚴格三分法（與 institutional_flow_chart 一致）
///
/// `> 0` 漲色 / `< 0` 跌色 / `== 0` 中性色。平盤不著漲跌色，避免零值柱
/// 被誤讀為買超。抽成純函式供測試直接驗證（柱色畫在 canvas 上，無法從
/// widget tree 觀察）。
Color miniBarColor(
  double value, {
  required Color upColor,
  required Color downColor,
  required Color neutralColor,
}) {
  if (value > 0) return upColor;
  if (value < 0) return downColor;
  return neutralColor;
}

/// 迷你柱狀圖（CustomPainter 實作，輕量無 fl_chart 依賴）
///
/// 用於法人買賣超、成交額等 30 日趨勢顯示。
/// 正值使用 [AppTheme.upColor]，負值使用 [AppTheme.downColor]，
/// 平盤使用 [AppTheme.neutralColor]。
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
            neutralColor: AppTheme.neutralColor,
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
    required this.neutralColor,
    required this.hasNegative,
    required this.barRadius,
  });

  final List<double> values;
  final Color upColor;
  final Color downColor;
  final Color neutralColor;
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
        ..color = miniBarColor(
          v,
          upColor: upColor,
          downColor: downColor,
          neutralColor: neutralColor,
        ).withValues(alpha: 0.7);

      // 平盤柱貼齊零線、兩端皆不倒角（不偽裝成向上或向下的柱）
      final isUpBar = v > 0;
      final isDownBar = v < 0;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x, barTop, x + barWidth, barBottom),
        topLeft: isUpBar ? radius : Radius.zero,
        topRight: isUpBar ? radius : Radius.zero,
        bottomLeft: isDownBar ? radius : Radius.zero,
        bottomRight: isDownBar ? radius : Radius.zero,
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
      downColor != oldDelegate.downColor ||
      neutralColor != oldDelegate.neutralColor;
}
