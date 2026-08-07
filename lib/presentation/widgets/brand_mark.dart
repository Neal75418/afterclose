import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:daredevil/core/theme/design_tokens.dart';

/// Daredevil 品牌標記——「雷達感知」同心弧(2026-08-07 更名時建立)。
///
/// **為什麼是幾何而非角色圖**:Marvel 的角色像與 DD 胸章是註冊商標,
/// 不進本專案。同心弧是夜魔俠能力的視覺語言,也正好是這個 app 的核心
/// 隱喻——不看盤中跳動,收盤後靠資料「感知」整個市場;三道弧由內而外
/// 遞減不透明度,像一次向外掃描。
///
/// 純 [CustomPainter] 繪製:無圖檔資產、任意尺寸不失真、顏色跟隨主題。
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
    this.showWordmark = false,
    this.color,
  });

  /// 圖形邊長(正方形)
  final double size;

  /// 是否在圖形右側顯示 "Daredevil" 字樣
  final bool showWordmark;

  /// 覆寫顏色;預設取主題 primary
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markColor = color ?? theme.colorScheme.primary;

    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RadarSensePainter(color: markColor)),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: DesignTokens.spacing8),
        Text(
          'Daredevil',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: markColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _RadarSensePainter extends CustomPainter {
  const _RadarSensePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 原點在左下角內縮處:弧線朝右上開展,讀起來是「由此向外感知」
    final origin = Offset(size.width * 0.22, size.height * 0.78);
    final unit = size.shortestSide;

    // 實心圓點=感知源
    canvas.drawCircle(
      origin,
      unit * 0.075,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // 三道同心弧,由內而外變細變淡=訊號向外衰減
    const sweepStart = -math.pi * 0.92; // 約 -166°,朝右上開口
    const sweepAngle = math.pi * 0.58;
    for (var i = 0; i < 3; i++) {
      final radius = unit * (0.24 + i * 0.20);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        sweepStart,
        sweepAngle,
        false,
        Paint()
          ..color = color.withValues(alpha: 1.0 - i * 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * (0.10 - i * 0.022)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarSensePainter oldDelegate) =>
      oldDelegate.color != color;
}
