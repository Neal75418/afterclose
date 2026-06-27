import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 毛玻璃背景（frosted glass）— 半透明 surface tint + BackdropFilter blur。
///
/// 用於固定 header / tab bar：捲動內容在後方**模糊化**而非直接穿透（純半透明無
/// blur 會看到下方文字疊到 header 後方，視覺像 bleed-through）。blur 後即使半透明
/// 透出的也是模糊色塊、不會是可讀文字。
///
/// blur sigma 與 tint alpha 集中此處，調整一次兩個 header 一致。
class FrostedBackground extends StatelessWidget {
  const FrostedBackground({super.key, this.child, this.alpha = _defaultAlpha});

  /// 疊在模糊層上的內容（如 TabBar）。null 時僅作背景填滿（如 SliverAppBar
  /// flexibleSpace）。
  final Widget? child;

  /// surface tint 不透明度（越低越透、blur 越明顯）。
  final double alpha;

  /// 模糊強度。視覺微調集中此常數。
  static const double blurSigma = 16;
  static const double _defaultAlpha = 0.75;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: alpha),
          child: child,
        ),
      ),
    );
  }
}
