import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart'; // HSLColor

/// WCAG 2.1 對比度與色相計算。
///
/// 生產碼與守門測試共用同一份實作——若測試自行實作一套公式，
/// 兩邊出現分歧時會出現「測試綠但實際不合格」的假安全。
abstract final class ColorContrast {
  /// sRGB 分量線性化（WCAG 2.1 定義）。
  static double _linearize(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  /// 相對亮度，範圍 0（純黑）至 1（純白）。
  ///
  /// Flutter 的 `Color.r/g/b` 已是 0.0-1.0 的 double，直接餵入線性化即可，
  /// 不需經過 0-255 整數轉換（多一次量化只會引入誤差）。
  static double relativeLuminance(Color color) {
    return 0.2126 * _linearize(color.r) +
        0.7152 * _linearize(color.g) +
        0.0722 * _linearize(color.b);
  }

  /// 兩色對比度，範圍 1:1 至 21:1。與參數順序無關。
  static double ratio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 色相角度（0-360）。無彩度（灰階）回傳 -1。
  static double hue(Color color) {
    final h = HSLColor.fromColor(color);
    return h.saturation == 0 ? -1.0 : h.hue;
  }
}
