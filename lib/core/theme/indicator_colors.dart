import 'dart:ui';

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

  /// OBV 指標標籤色（Emerald）
  static const obvLabel = Color(0xFF10B981);

  /// ATR 指標標籤色（Violet）
  static const atrLabel = Color(0xFF8B5CF6);

  // ==================================================
  // 波動度色階
  // ==================================================

  /// 低波動（ATR）— Green
  static const volatilityLow = Color(0xFF10B981);

  /// 中波動（ATR）— Amber
  static const volatilityMedium = Color(0xFFF59E0B);

  /// 高波動（ATR）— Red
  static const volatilityHigh = Color(0xFFEF4444);

  // ==================================================
  // 籌碼評等色階
  // ==================================================

  /// 強：籌碼強勢 / 法人積極買入
  static const ratingStrong = Color(0xFF4CAF50);

  /// 偏多：籌碼偏多 / 法人適度買入
  static const ratingBullish = Color(0xFF8BC34A);

  /// 中性
  static const ratingNeutral = Color(0xFFFFC107);

  /// 偏空：籌碼偏空 / 法人適度賣出
  static const ratingBearish = Color(0xFFFF9800);

  /// 弱：籌碼弱勢 / 法人積極賣出
  static const ratingWeak = Color(0xFFF44336);

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
