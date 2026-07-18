import 'dart:ui';

import 'package:afterclose/domain/models/chip_strength.dart';

/// 色彩語意類別的單一真相來源。
///
/// 分類判準：
/// - [PriceColors]     值變大代表偏多或偏空 —— 唯一可使用紅綠色相者
/// - [QualityColors]   有好壞之分但無多空方向
/// - [CategoryColors]  純分類，無好壞也無方向
/// - [WarningColors]   「請注意」，與多空無關
///
/// 紅區（hue >= 345 或 <= 15）與綠區（88-175）為股價語意保留區，
/// 除 [PriceColors] 外不得使用。此約束由
/// `test/core/theme/semantic_colors_test.dart` 強制。
abstract final class SemanticColors {
  static const darkBackground = Color(0xFF18181B); // Zinc 900
  static const darkSurface = Color(0xFF27272A); // Zinc 800
  static const darkElevated = Color(0xFF3F3F46); // Zinc 700
  static const darkOutline = Color(0xFF52525B); // Zinc 600
  static const darkTextPrimary = Color(0xFFF4F4F5); // Zinc 100
  static const darkTextSecondary = Color(0xFFA1A1AA); // Zinc 400

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF8F9FA);
}

/// 方向性語意 —— 唯一可使用紅綠色相的類別。
abstract final class PriceColors {
  /// 上漲（台股慣例：紅）。色相 354.8°
  static const up = Color(0xFFFF4757);

  /// 下跌（台股慣例：綠）。色相 145.4°
  static const down = Color(0xFF2ED573);

  /// 下跌（淺色主題專用，白底對比加強）
  static const downOnLight = Color(0xFF1B9E50);

  /// 平盤。刻意使用灰階，不佔用任何色相。
  static const flat = Color(0xFFA1A1A1);

  /// 籌碼偏多（上漲紅的淺色階）
  static const chipBullish = Color(0xFFFF8A94);

  /// 籌碼偏空（下跌綠的淺色階）
  static const chipBearish = Color(0xFF7DD8A0);

  /// 籌碼評等對應色。
  ///
  /// 籌碼強弱與漲跌屬同一多空語意軸，故共用紅綠色彩語言：
  /// 強勢＝紅、弱勢＝綠，與台股慣例一致。
  static Color chipRating(ChipRating rating) => switch (rating) {
    ChipRating.strong => up,
    ChipRating.bullish => chipBullish,
    ChipRating.neutral => flat,
    ChipRating.bearish => chipBearish,
    ChipRating.weak => down,
  };
}

/// 非方向性的好壞語意。
abstract final class QualityColors {
  /// 品牌主色（填色用）。Violet 400。
  ///
  /// 深色主題採 Material 3 色調邏輯：primary 用淺色調、onPrimary 用深色。
  /// Violet 500 (#8B5CF6) 對深色背景僅 4.18:1，白字在其上僅 4.23:1，
  /// 兩者皆不符 AA，故不作為文字或填色使用。
  static const brand = Color(0xFFA78BFA);

  /// 品牌填色上的文字色
  static const onBrand = Color(0xFF18181B);

  /// 深色底上的品牌文字與圖示色（與 [brand] 同值，語意不同故分開命名）
  static const brandOnDark = Color(0xFFA78BFA);

  /// 淺色主題的品牌色（白底對比加強）
  static const brandOnLight = Color(0xFF6D28D9);

  /// 純裝飾用品牌色 —— 邊框、低透明度底色、focus ring。
  /// 不承載文字，故不適用 WCAG 文字門檻。
  static const brandDecorative = Color(0xFF8B5CF6);

  /// 低強度／停用／低波動
  static const muted = Color(0xFF71717A);

  /// 守門測試掃描對象。新增常數時必須加入此清單。
  static const all = <Color>[
    brand,
    onBrand,
    brandOnDark,
    brandOnLight,
    brandDecorative,
    muted,
  ];
}

/// 純分類語意，無好壞也無方向。
abstract final class CategoryColors {
  /// 法人／中性分類標記。
  ///
  /// 外資／投信／自營商原本各有專屬色，但實際只用於 14px 圖示、
  /// 8px 圓點與 alpha 0.3 邊框，且每個實例都緊鄰文字標籤，
  /// 顏色屬冗餘的第三重編碼。統一為中性灰後同時消除四組色相過近問題。
  static const neutral = Color(0xFFA1A1AA);

  /// 圖表序列色盤（3 色相 × 2 明度）。
  ///
  /// 排除紅綠禁區後可用色相僅剩 243°，無法容納 6 個互隔 60° 的色相。
  /// 改以 3 個充分分離的色相（25° / 217° / 258°）各取兩個明度階，
  /// 同族靠明度區分、異族靠色相區分。
  /// 序列超過 6 個時應改用直接標註，不得再增加顏色。
  static const chartPalette = <Color>[
    Color(0xFF3B82F6), // 藍 500 — 217°
    Color(0xFFF97316), // 橘 500 — 25°
    Color(0xFF8B5CF6), // 紫 500 — 258°
    Color(0xFF93C5FD), // 藍 300 — 212°
    Color(0xFFFDBA74), // 橘 300 — 31°
    Color(0xFFC4B5FD), // 紫 300 — 252°
  ];
}

/// 「請注意」語意，與多空無關。
abstract final class WarningColors {
  /// 警示。色相 37.7°
  static const warning = Color(0xFFF59E0B);

  /// 注意。色相 45.9°
  static const caution = Color(0xFFFBBF24);

  /// 淺色主題的警示色（白底對比加強）
  static const warningOnLight = Color(0xFFFEF08A);

  static const all = <Color>[warning, caution, warningOnLight];
}
