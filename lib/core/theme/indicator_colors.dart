import 'dart:ui';

import 'package:afterclose/core/theme/semantic_colors.dart';

/// 技術指標圖表與相關元件的色彩常數
///
/// 統一管理所有指標相關的硬編碼顏色，確保一致性並便於維護。
abstract final class IndicatorColors {
  // ==================================================
  // 圖表線條顏色
  // ==================================================

  /// 主要指標線（K, DIF, MA5, MACD）— Sky Blue
  static const chartPrimary = Color(0xFF60A5FA);

  /// 次要指標線（D, DEA, MA10, RSI）— Yellow
  static const chartSecondary = Color(0xFFFACC15);

  /// 第三指標線（J, MA30）— Purple
  static const chartTertiary = Color(0xFFA78BFA);

  // ==================================================
  // 圖表背景
  // ==================================================

  /// K 線圖深色模式背景
  static const chartDarkBackground = Color(0xFF0F172A);

  // ==================================================
  // 指標標籤顏色
  // ==================================================

  /// OBV 指標標籤色（藍，分類語意）
  static const obvLabel = Color(0xFF3B82F6);

  /// ATR 指標標籤色（Violet）
  static const atrLabel = Color(0xFF8B5CF6);

  // ==================================================
  // 波動度色階
  // ==================================================

  /// 低波動（ATR）—— 非方向性，使用中性灰
  static const volatilityLow = Color(0xFF71717A);

  /// 中波動（ATR）—— 波動度是「請注意」而非多空訊號
  static const volatilityMedium = WarningColors.caution;

  /// 高波動（ATR）—— 波動度是「請注意」而非多空訊號，不使用紅色
  static const volatilityHigh = WarningColors.warning;

  // 籌碼評等色階已移至 PriceColors.chipRating()。
  // 該色階屬方向性語意（籌碼強弱＝多空），與漲跌共用紅綠色彩語言，
  // 故不放在本檔（本檔為圖表與指標的分類色）。

  // ==================================================
  // 指標選擇標籤
  // ==================================================

  /// MA / MACD 選擇器
  static const selectorBlue = Color(0xFF3498DB);

  /// BOLL / RSI 選擇器
  static const selectorPurple = Color(0xFF9B59B6);

  /// SAR / KDJ 選擇器
  static const selectorOrange = Color(0xFFE67E22);

  /// WR 選擇器
  static const selectorTeal = Color(0xFF1ABC9C);

  /// CCI 選擇器
  static const selectorRed = Color(0xFFE74C3C);
}
