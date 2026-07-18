# 色彩系統語意重構 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓紅綠色專屬於多空語意，非方向性語意改用品牌紫與中性灰，並以守門測試防止未來漂移。

**Architecture:** 新增 `lib/core/theme/semantic_colors.dart` 作為單一色彩來源，依語意類別（Directional / Quality / Category / Warning）分組。既有 `AppTheme`、`IndicatorColors`、`DesignTokens` 的色彩常數改為委派至新檔，呼叫端逐步遷移。三層守門測試（色相禁區、對比度、語意單調性）在第一個 Task 就建立，後續每個 Task 的顏色改動都受其約束。

**Tech Stack:** Flutter / Dart 3、`flutter_test`、`dart:ui` `Color`、`HSLColor`

設計依據：`docs/plans/2026-07-18-color-system-semantic-redesign-design.md`

## Global Constraints

- 禁區色相：紅區 `hue >= 345 || hue <= 15`、綠區 `88 <= hue <= 175`。僅 `PriceColors` 可使用。
- 對比度門檻：正常文字 ≥4.5:1、≥18px 粗體 ≥3.0:1、圖形物件 ≥3.0:1（WCAG 2.1）。
- 深色主題背景 `#18181B`、卡片 `#27272A`；淺色主題背景 `#FFFFFF`、卡片 `#FFFFFF`。
- 對比度一律以 WCAG 2.1 相對亮度公式計算，不得以目測或估算填寫。
- 每個 Task 結束前 `flutter test` 必須全綠（基準 3,129 個測試）。
- Commit 訊息使用 Conventional Commits，繁體中文描述。

---

## File Structure

**新增**

- `lib/core/theme/semantic_colors.dart` — 四個語意類別的色彩常數與查表函式。單一色彩真相來源。
- `lib/core/theme/color_contrast.dart` — WCAG 相對亮度／對比度／色相計算工具。生產碼與測試共用，避免測試自行實作一套。
- `test/core/theme/color_contrast_test.dart` — 計算工具本身的正確性測試。
- `test/core/theme/semantic_colors_test.dart` — 三層守門測試。

**修改**

- `lib/core/theme/app_theme.dart` — 表面色改 Zinc、品牌色改 Violet、語意色委派 `SemanticColors`、移除法人三色。
- `lib/core/theme/indicator_colors.dart` — 籌碼評等五色翻轉、`volatilityLow` / `obvLabel` 改色。
- `lib/core/theme/design_tokens.dart` — `chartPalette` 縮為 6 色、`successDark` 改紫、warning 合併至 `SemanticColors`。
- 呼叫端共 11 個檔案（各 Task 內列出精確路徑）。

---

## Task 1: 對比度計算工具

先建立計算工具，因為後續所有守門測試都依賴它。生產碼也會用到（`AppTheme` 需要在 debug 模式下自檢）。

**Files:**
- Create: `lib/core/theme/color_contrast.dart`
- Test: `test/core/theme/color_contrast_test.dart`

**Interfaces:**
- Consumes: 無
- Produces: `ColorContrast.relativeLuminance(Color) -> double`、`ColorContrast.ratio(Color, Color) -> double`、`ColorContrast.hue(Color) -> double`（無彩度時回傳 `-1`）

- [ ] **Step 1: 寫失敗測試**

建立 `test/core/theme/color_contrast_test.dart`：

```dart
import 'dart:ui';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativeLuminance', () {
    test('純黑為 0、純白為 1', () {
      expect(ColorContrast.relativeLuminance(const Color(0xFF000000)),
          closeTo(0.0, 0.0001));
      expect(ColorContrast.relativeLuminance(const Color(0xFFFFFFFF)),
          closeTo(1.0, 0.0001));
    });
  });

  group('ratio', () {
    test('黑白對比為 21:1', () {
      final r = ColorContrast.ratio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      expect(r, closeTo(21.0, 0.01));
    });

    test('順序不影響結果', () {
      const a = Color(0xFF8B5CF6);
      const b = Color(0xFF18181B);
      expect(ColorContrast.ratio(a, b), closeTo(ColorContrast.ratio(b, a), 1e-9));
    });

    test('品牌紫 500 對深色背景為 4.18:1', () {
      final r = ColorContrast.ratio(
        const Color(0xFF8B5CF6),
        const Color(0xFF18181B),
      );
      expect(r, closeTo(4.18, 0.01));
    });

    test('品牌紫 400 對深色背景為 6.51:1', () {
      final r = ColorContrast.ratio(
        const Color(0xFFA78BFA),
        const Color(0xFF18181B),
      );
      expect(r, closeTo(6.51, 0.01));
    });
  });

  group('hue', () {
    test('三原色色相正確', () {
      expect(ColorContrast.hue(const Color(0xFFFF0000)), closeTo(0.0, 0.01));
      expect(ColorContrast.hue(const Color(0xFF00FF00)), closeTo(120.0, 0.01));
      expect(ColorContrast.hue(const Color(0xFF0000FF)), closeTo(240.0, 0.01));
    });

    test('無彩度回傳 -1', () {
      expect(ColorContrast.hue(const Color(0xFF808080)), -1.0);
    });

    test('上漲紅色相為 355 度', () {
      expect(ColorContrast.hue(const Color(0xFFFF4757)), closeTo(354.8, 0.1));
    });
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/color_contrast_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'afterclose/core/theme/color_contrast.dart'`（檔案不存在）

- [ ] **Step 3: 實作**

建立 `lib/core/theme/color_contrast.dart`：

```dart
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
```

- [ ] **Step 4: 執行測試確認通過**

Run: `flutter test test/core/theme/color_contrast_test.dart`
Expected: PASS，10 個測試全綠

- [ ] **Step 5: 全套測試確認無迴歸**

Run: `flutter test`
Expected: PASS，3,139 個測試（原 3,129 + 新增 10）

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/color_contrast.dart test/core/theme/color_contrast_test.dart
git commit -m "feat(theme): 新增 WCAG 對比度與色相計算工具

生產碼與守門測試共用同一份公式實作，避免兩套公式分歧
造成「測試綠但實際不合格」。"
```

---

## Task 2: 語意色彩類別與三層守門測試

**Files:**
- Create: `lib/core/theme/semantic_colors.dart`
- Test: `test/core/theme/semantic_colors_test.dart`

**Interfaces:**
- Consumes: `ColorContrast`（Task 1）
- Produces:
  - `PriceColors.up / .down / .flat`（`Color`）
  - `PriceColors.chipRating(ChipRating) -> Color`
  - `QualityColors.brand / .brandOnDark / .brandLight / .muted`（`Color`）
  - `QualityColors.all -> List<Color>`
  - `CategoryColors.chartPalette -> List<Color>`、`CategoryColors.neutral`
  - `WarningColors.warning / .caution`、`WarningColors.all -> List<Color>`
  - `SemanticColors.darkBackground / .darkSurface / .lightBackground / .lightSurface`

- [ ] **Step 1: 寫失敗測試**

建立 `test/core/theme/semantic_colors_test.dart`：

```dart
import 'dart:ui';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:flutter_test/flutter_test.dart';

/// 紅區：hue >= 345 或 <= 15。綠區：88 <= hue <= 175。
bool _inPriceHueZone(Color c) {
  final h = ColorContrast.hue(c);
  if (h < 0) return false; // 灰階不佔用色相
  return h >= 345 || h <= 15 || (h >= 88 && h <= 175);
}

void main() {
  group('第一層：色相禁區守門', () {
    test('QualityColors 不得落在股價色相區', () {
      for (final c in QualityColors.all) {
        expect(_inPriceHueZone(c), isFalse,
            reason: 'QualityColors 含 ${c.toARGB32().toRadixString(16)}，'
                '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}° 落在股價語意區');
      }
    });

    test('WarningColors 不得落在股價色相區', () {
      for (final c in WarningColors.all) {
        expect(_inPriceHueZone(c), isFalse,
            reason: 'WarningColors 含 ${c.toARGB32().toRadixString(16)}，'
                '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}°');
      }
    });

    test('CategoryColors.chartPalette 不得落在股價色相區', () {
      for (final c in CategoryColors.chartPalette) {
        expect(_inPriceHueZone(c), isFalse,
            reason: 'chartPalette 含 ${c.toARGB32().toRadixString(16)}，'
                '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}°');
      }
    });
  });

  group('第二層：對比度守門', () {
    const darkBg = SemanticColors.darkBackground;
    const darkCard = SemanticColors.darkSurface;

    test('品牌文字色對深色背景與卡片皆達 AA 4.5:1', () {
      expect(ColorContrast.ratio(QualityColors.brandOnDark, darkBg),
          greaterThanOrEqualTo(4.5));
      expect(ColorContrast.ratio(QualityColors.brandOnDark, darkCard),
          greaterThanOrEqualTo(4.5));
    });

    test('品牌填色上的文字色達 AA 4.5:1', () {
      expect(ColorContrast.ratio(QualityColors.onBrand, QualityColors.brand),
          greaterThanOrEqualTo(4.5));
    });

    test('圖表色盤每色對深色背景達圖形物件門檻 3:1', () {
      for (final c in CategoryColors.chartPalette) {
        expect(ColorContrast.ratio(c, darkBg), greaterThanOrEqualTo(3.0),
            reason: 'chartPalette ${c.toARGB32().toRadixString(16)} 對比不足');
      }
    });

    test('警示色對深色背景達 AA 4.5:1', () {
      for (final c in WarningColors.all) {
        expect(ColorContrast.ratio(c, darkBg), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('第三層：語意單調性守門', () {
    test('籌碼評等五級全部落在股價色相區或為灰階', () {
      for (final r in ChipRating.values) {
        final c = PriceColors.chipRating(r);
        final h = ColorContrast.hue(c);
        expect(h < 0 || _inPriceHueZone(c), isTrue,
            reason: '$r 對應色非股價語意色');
      }
    });

    test('籌碼評等自強勢至弱勢單調由紅轉綠', () {
      // 以「紅色分量減綠色分量」作為多空傾向指標，強勢端最大、弱勢端最小。
      double bias(Color c) => c.r - c.g;

      final values = ChipRating.values
          .map((r) => bias(PriceColors.chipRating(r)))
          .toList();

      for (var i = 0; i < values.length - 1; i++) {
        expect(values[i], greaterThan(values[i + 1]),
            reason: '${ChipRating.values[i]} 到 ${ChipRating.values[i + 1]} '
                '未維持由紅至綠的單調性');
      }
    });

    test('籌碼強勢與上漲同色、弱勢與下跌同色', () {
      expect(PriceColors.chipRating(ChipRating.strong), PriceColors.up);
      expect(PriceColors.chipRating(ChipRating.weak), PriceColors.down);
    });
  });

  group('圖表色盤色族間距', () {
    test('不同色族間距 >= 35 度、同色族對比比值 >= 1.5', () {
      const bg = SemanticColors.darkBackground;
      final palette = CategoryColors.chartPalette;

      // 色相差 <= 15 度視為同族
      for (var i = 0; i < palette.length; i++) {
        for (var j = i + 1; j < palette.length; j++) {
          final hi = ColorContrast.hue(palette[i]);
          final hj = ColorContrast.hue(palette[j]);
          var delta = (hi - hj).abs();
          if (delta > 180) delta = 360 - delta;

          if (delta <= 15) {
            final ri = ColorContrast.ratio(palette[i], bg);
            final rj = ColorContrast.ratio(palette[j], bg);
            final hiR = ri > rj ? ri : rj;
            final loR = ri > rj ? rj : ri;
            expect(hiR / loR, greaterThanOrEqualTo(1.5),
                reason: '同色族 $i/$j 明度差不足，線條會難以區分');
          } else {
            expect(delta, greaterThanOrEqualTo(35.0),
                reason: '色族 $i/$j 間距 ${delta.toStringAsFixed(1)}° 過近');
          }
        }
      }
    });
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/semantic_colors_test.dart`
Expected: FAIL — 找不到 `package:afterclose/core/theme/semantic_colors.dart`

- [ ] **Step 3: 實作**

建立 `lib/core/theme/semantic_colors.dart`：

```dart
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
  static const flat = Color(0xFFA1A1AA);

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
  static const caution = Color(0xFFFCD34D);

  /// 淺色主題的警示色（白底對比加強）
  static const warningOnLight = Color(0xFFB45309);

  static const all = <Color>[warning, caution, warningOnLight];
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `flutter test test/core/theme/semantic_colors_test.dart`
Expected: PASS，11 個測試全綠

若「不同色族間距」測試失敗，代表色盤選色有誤，修正 `chartPalette` 色值而非放寬測試門檻。

- [ ] **Step 5: 全套測試**

Run: `flutter test`
Expected: PASS，3,150 個測試

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/semantic_colors.dart test/core/theme/semantic_colors_test.dart
git commit -m "feat(theme): 建立語意色彩類別與三層守門測試

依 Directional/Quality/Category/Warning 四類分組色彩，紅綠色相
保留給股價語意。守門測試檢查色相禁區、對比度、評等單調性。"
```

---

## Task 3: 表面色 Slate 改 Zinc

**Files:**
- Modify: `lib/core/theme/app_theme.dart:80-83`（深色表面）、`:105-108`（colorScheme）、`:120`（AppBar 文字）、`:147-149`（導航列圖示）、`:167`（按鈕邊框）、`:207`（分隔線）、`:421`、`:443`（卡片裝飾）
- Test: `test/core/theme/app_theme_surfaces_test.dart`

**Interfaces:**
- Consumes: `SemanticColors`（Task 2）
- Produces: 無新介面，僅色值變更

- [ ] **Step 1: 寫失敗測試**

建立 `test/core/theme/app_theme_surfaces_test.dart`：

```dart
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('深色主題表面色飽和度低於 10%', () {
    final theme = AppTheme.darkTheme;
    for (final c in [
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
      theme.dividerTheme.color!,
    ]) {
      final s = HSLColor.fromColor(c).saturation;
      expect(s, lessThan(0.10),
          reason: '${c.toARGB32().toRadixString(16)} 飽和度 '
              '${(s * 100).toStringAsFixed(0)}% 過高，會與股價綠色競爭色相');
    }
  });

  test('深色主題表面色取自 SemanticColors', () {
    final theme = AppTheme.darkTheme;
    expect(theme.scaffoldBackgroundColor, SemanticColors.darkBackground);
    expect(theme.colorScheme.surface, SemanticColors.darkSurface);
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/app_theme_surfaces_test.dart`
Expected: FAIL — 飽和度 47%（`#6C63FF|64748B|0F172A`）超過門檻，且不等於 `SemanticColors.darkBackground`

- [ ] **Step 3: 實作**

修改 `lib/core/theme/app_theme.dart`，將第 79-83 行替換為：

```dart
  // 深色主題表面顏色（Tailwind Zinc — 飽和度 4%，不與股價色競爭色相）
  static const _surfaceDark = SemanticColors.darkSurface; // Zinc 800
  static const _backgroundDark = SemanticColors.darkBackground; // Zinc 900
  static const _cardDark = SemanticColors.darkSurface; // Zinc 800
  static const _cardDarkSurface = SemanticColors.darkElevated; // Zinc 700
```

於檔案頂部加入 import：

```dart
import 'package:afterclose/core/theme/semantic_colors.dart';
```

將 `colorScheme` 內的 Slate 硬編碼（第 105-108 行）替換為：

```dart
        onSurface: SemanticColors.darkTextPrimary,
        onSurfaceVariant: SemanticColors.darkTextSecondary,
        error: const Color(0xFFFF6B6B),
        outline: SemanticColors.darkOutline,
```

其餘 Slate 硬編碼一併替換：第 120 行 `Color(0xFFF1F5F9)` → `SemanticColors.darkTextPrimary`；第 147 行同理；第 149 行 `Color(0xFF94A3B8)` → `SemanticColors.darkTextSecondary`；第 167 行 `Color(0xFF475569)` → `SemanticColors.darkOutline`；第 207 行 `Color(0xFF334155)` → `SemanticColors.darkElevated`；第 421 行 `Color(0xFF475569)` → `SemanticColors.darkOutline`；第 443 行 `Color(0xFF334155)` → `SemanticColors.darkElevated`。

`premiumGradient`（第 399-406 行）改為：

```dart
  static LinearGradient get premiumGradient => LinearGradient(
    colors: [
      SemanticColors.darkSurface,
      SemanticColors.darkElevated.withValues(alpha: 0.5),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
```

- [ ] **Step 4: 執行測試確認通過**

Run: `flutter test test/core/theme/app_theme_surfaces_test.dart`
Expected: PASS

- [ ] **Step 5: 確認無殘留 Slate 色值**

Run: `grep -nE '0xFF(6C63FF|64748B|0F172A|1E293B|334155|475569|94A3B8|F1F5F9)' lib/core/theme/app_theme.dart`
Expected: 無輸出

- [ ] **Step 6: 全套測試並 Commit**

```bash
flutter test
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_surfaces_test.dart
git commit -m "refactor(theme): 深色表面 Slate 改 Zinc

飽和度 47% 降至 4%，背景不再與股價綠色競爭色相。
新增測試斷言表面飽和度低於 10%。"
```

---

## Task 4: 品牌色改 Violet

**Files:**
- Modify: `lib/core/theme/app_theme.dart:19-25`（品牌色常數）、`:100-103`（colorScheme）、`:186`、`:216`、`:322`、`:360`
- Modify 呼叫端：`lib/presentation/screens/settings/settings_screen.dart:487`、`lib/presentation/widgets/section_header.dart:55-56`、`lib/presentation/widgets/update_progress_banner.dart:25`、`lib/presentation/widgets/empty_state.dart:205`
- Test: 追加至 `test/core/theme/app_theme_surfaces_test.dart`

**Interfaces:**
- Consumes: `QualityColors`（Task 2）
- Produces: `AppTheme.primaryColor` 改為 `QualityColors.brand`；`AppTheme.secondaryColor` 移除

- [ ] **Step 1: 寫失敗測試**

於 `test/core/theme/app_theme_surfaces_test.dart` 追加：

```dart
  test('深色主題 primary 對背景達 AA、onPrimary 為深色', () {
    final theme = AppTheme.darkTheme;
    expect(
      ColorContrast.ratio(theme.colorScheme.primary, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ColorContrast.ratio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('主題內不再出現 Material 預設 teal', () {
    final theme = AppTheme.darkTheme;
    expect(theme.colorScheme.secondary, isNot(const Color(0xFF03DAC6)));
  });
```

需追加 import：`import 'package:afterclose/core/theme/color_contrast.dart';`

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/app_theme_surfaces_test.dart`
Expected: FAIL — `secondary` 仍為 `#03DAC6`；`onPrimary` 對比不足

- [ ] **Step 3: 實作**

`lib/core/theme/app_theme.dart` 第 18-25 行替換為：

```dart
  /// 主品牌色（Violet 400）。深色主題採 M3 色調邏輯：淺色 primary + 深色 onPrimary。
  static const primaryColor = QualityColors.brand;

  /// 品牌裝飾色（Violet 500）—— 僅用於邊框、低透明度底色，不承載文字。
  static const brandDecorative = QualityColors.brandDecorative;

  /// 第三強調色 - Material Deep Orange
  static const tertiaryColor = Color(0xFFFF5722);
```

深色 `colorScheme`（第 100-103 行）替換為：

```dart
      colorScheme: ColorScheme.dark(
        primary: QualityColors.brand,
        onPrimary: QualityColors.onBrand,
        secondary: QualityColors.brand,
        onSecondary: QualityColors.onBrand,
        tertiary: tertiaryColor,
```

淺色 `colorScheme` 的 `primary` 改為 `QualityColors.brandOnLight`、`onPrimary` 為 `Color(0xFFFFFFFF)`。

第 186、322 行的 `borderSide: const BorderSide(color: primaryColor, width: 2)` 保持不變（`primaryColor` 已指向新值）。第 216 行 `actionTextColor: secondaryColor` 改為 `QualityColors.brand`；第 360 行同理。

呼叫端漸層改為單色或品牌雙階：
- `settings_screen.dart:487`：`colors: [AppTheme.primaryColor, AppTheme.brandDecorative]`
- `section_header.dart:55-56`：兩個分支皆改為 `[AppTheme.primaryColor, AppTheme.brandDecorative]` 與其反序
- `update_progress_banner.dart:25`：`const gradientColors = [AppTheme.primaryColor, AppTheme.brandDecorative];`
- `empty_state.dart:205`：`iconColor: AppTheme.primaryColor`

- [ ] **Step 4: 處理另外兩個未列於遷移表的常數**

自審時發現設計文件的遷移對照表漏了這兩個：

`AppTheme.notificationColor = #6C63FF` 色相 243.5°，與新品牌色 255° **僅隔 12°**——通知紫與品牌紫會難以區分。改用琥珀，與品牌色及股價色皆充分分離：

```dart
  /// 通知標記 —— 原為 #6C63FF（243°），與品牌紫 255° 僅隔 12° 難以區分
  static const notificationColor = WarningColors.caution;
```

`AppTheme.neutralSlateColor = #64748B` 是 Slate 殘留（4 處呼叫端），改用 Zinc 對應階：

```dart
  /// 中性灰 —— 用於非漲跌的平穩狀態
  static const neutralSlateColor = QualityColors.muted;
```

Run: `grep -rn 'AppTheme.secondaryColor' lib --include="*.dart"`
Expected: 無輸出

Run: `grep -nE '0xFF(6C63FF|64748B)' lib/core/theme/app_theme.dart`
Expected: 無輸出

- [ ] **Step 5: 執行測試並 Commit**

```bash
flutter test
git add lib/core/theme/app_theme.dart lib/presentation/screens/settings/settings_screen.dart lib/presentation/widgets/section_header.dart lib/presentation/widgets/update_progress_banner.dart lib/presentation/widgets/empty_state.dart test/core/theme/app_theme_surfaces_test.dart
git commit -m "feat(theme): 品牌色改 Violet 並移除 Material 預設 teal

teal #03DAC6 色相 174° 落在股價綠色語意區。改用 Violet 400
配深色 onPrimary，符合 M3 深色主題色調邏輯（primary 用淺調）。"
```

---

## Task 5: 籌碼評等五色翻轉

**Files:**
- Modify: `lib/core/theme/indicator_colors.dart:56-72`（評等色階）
- Modify: `lib/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart:119-127`
- Test: `test/presentation/screens/stock_detail/widgets/chip_strength_indicator_test.dart`

**Interfaces:**
- Consumes: `PriceColors.chipRating`（Task 2）
- Produces: `IndicatorColors.rating*` 常數移除，改由 `PriceColors.chipRating` 提供

- [ ] **Step 1: 寫失敗測試**

建立 `test/presentation/screens/stock_detail/widgets/chip_strength_indicator_test.dart`：

```dart
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('籌碼強勢為紅（台股慣例：與上漲同色）', () {
    expect(PriceColors.chipRating(ChipRating.strong), PriceColors.up);
  });

  test('籌碼弱勢為綠（台股慣例：與下跌同色）', () {
    expect(PriceColors.chipRating(ChipRating.weak), PriceColors.down);
  });

  test('籌碼中性為灰階，不佔用色相', () {
    expect(PriceColors.chipRating(ChipRating.neutral), PriceColors.flat);
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/presentation/screens/stock_detail/widgets/chip_strength_indicator_test.dart`
Expected: 若 Task 2 已完成則 PASS。此時改為驗證 widget 端仍使用舊常數：

Run: `grep -n 'IndicatorColors.rating' lib/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart`
Expected: 5 行命中 —— 代表 widget 尚未遷移

- [ ] **Step 3: 實作**

`chip_strength_indicator.dart` 第 119-127 行替換為：

```dart
  Color _ratingColor(ChipRating rating) => PriceColors.chipRating(rating);
```

並將 import `package:afterclose/core/theme/indicator_colors.dart` 換為（或追加）`package:afterclose/core/theme/semantic_colors.dart`。

`indicator_colors.dart` 移除第 56-72 行的五個 `rating*` 常數，於原處留下說明註解：

```dart
  // 籌碼評等色階已移至 PriceColors.chipRating()。
  // 該色階屬方向性語意（籌碼強弱＝多空），與漲跌共用紅綠色彩語言，
  // 故不放在本檔（本檔為圖表與指標的分類色）。
```

- [ ] **Step 4: 確認無殘留並執行測試**

Run: `grep -rn 'IndicatorColors.rating' lib --include="*.dart"`
Expected: 無輸出

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/indicator_colors.dart lib/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart test/presentation/screens/stock_detail/widgets/chip_strength_indicator_test.dart
git commit -m "fix(theme): 籌碼評等色階翻轉為台股慣例

原本強勢＝綠、弱勢＝紅（國際慣例），與同畫面股價的紅漲綠跌
相反：個股詳情頁上緣紅色代表上漲、下緣紅色代表籌碼弱勢。
籌碼強弱與漲跌屬同一多空語意軸，改為共用紅綠語言。"
```

---

## Task 6: Quality 類綠色遷移

**Files:**
- Modify: `lib/core/theme/app_theme.dart:51-61`（successColor、dividendColor）
- Modify: `lib/core/theme/design_tokens.dart:191-206`（successLight/Dark、warningLight/Dark）
- Modify: `lib/core/theme/indicator_colors.dart:41`（volatilityLow）、`:32`（obvLabel）
- Modify 呼叫端：`lib/presentation/screens/stock_detail/widgets/ai_summary_card.dart:408`、`lib/presentation/screens/alerts/alerts_screen.dart:286,295,312`、`lib/presentation/widgets/pinned_thesis_section.dart:200`、`lib/presentation/widgets/update_history_sheet.dart:333`
- Test: 追加至 `test/core/theme/semantic_colors_test.dart`

**Interfaces:**
- Consumes: `QualityColors`、`WarningColors`（Task 2）
- Produces: `DesignTokens.successColor(theme)` / `warningColor(theme)` 保留簽章，內部改用 `QualityColors` / `WarningColors`

- [ ] **Step 1: 寫失敗測試**

於 `test/core/theme/semantic_colors_test.dart` 追加：

```dart
  group('Quality 類綠色已完成遷移', () {
    test('DesignTokens success 兩主題皆非綠色相', () {
      for (final c in [DesignTokens.successLight, DesignTokens.successDark]) {
        final h = ColorContrast.hue(c);
        expect(h >= 88 && h <= 175, isFalse,
            reason: 'success 仍為綠色 ${h.toStringAsFixed(1)}°，'
                '會與「下跌」語意混淆');
      }
    });

    test('warning 色僅宣告一處', () {
      // AppTheme.warningColor 與 DesignTokens.warningDark 曾各自宣告不同值
      // （#FF9800 36° vs #FB923C 27°），合併後兩者必須同值。
      expect(DesignTokens.warningDark, WarningColors.warning);
    });
  });
```

需追加 import：`import 'package:afterclose/core/theme/design_tokens.dart';`

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/semantic_colors_test.dart`
Expected: FAIL — `successDark` 為 `#4ADE80`（色相 142°，落在綠區）；`warningDark` 為 `#FB923C` 不等於 `#F59E0B`

- [ ] **Step 3: 實作**

`design_tokens.dart` 第 188-206 行替換為：

```dart
  /// Success 語意色（淺色主題）
  ///
  /// 「成功／高信心」屬非方向性語意，不使用綠色 —— 綠色在本 app
  /// 代表下跌。改用品牌紫，與股價語意徹底分離。
  static const Color successLight = QualityColors.brandOnLight;

  /// Success 語意色（深色主題）
  static const Color successDark = QualityColors.brand;

  /// Warning 語意色（淺色主題）
  static const Color warningLight = WarningColors.warningOnLight;

  /// Warning 語意色（深色主題）
  ///
  /// 與 `WarningColors.warning` 同值 —— 此處曾與 `AppTheme.warningColor`
  /// 各自宣告不同值（#FB923C 27° vs #FF9800 36°），造成同語意雙色漂移。
  static const Color warningDark = WarningColors.warning;
```

`app_theme.dart` 第 51-61 行：

```dart
  /// 正面/成功 —— 非方向性語意，使用品牌紫
  static const successColor = QualityColors.brand;

  /// 警示 —— 委派 WarningColors，避免雙處宣告漂移
  static const warningColor = WarningColors.warning;

  /// 注意
  static const cautionColor = WarningColors.caution;

  /// 股利正面指標 —— 非方向性語意，使用品牌紫
  static const dividendColor = QualityColors.brand;
```

`indicator_colors.dart`：第 32 行 `obvLabel` 改為 `Color(0xFF3B82F6)`（藍，分類語意）；第 41 行 `volatilityLow` 改為 `Color(0xFF71717A)`（灰，非方向性）。同時將 `volatilityMedium` / `volatilityHigh` 改為 `WarningColors.caution` / `WarningColors.warning`——波動度是「請注意」而非多空訊號。

呼叫端無需修改（皆透過常數取值）。

- [ ] **Step 4: 確認無殘留綠色語意常數**

Run: `grep -rnE '0xFF(4CAF50|27AE60|10B981|4ADE80|8BC34A)' lib --include="*.dart"`
Expected: 無輸出

- [ ] **Step 5: 執行測試並 Commit**

```bash
flutter test
git add lib/core/theme/app_theme.dart lib/core/theme/design_tokens.dart lib/core/theme/indicator_colors.dart test/core/theme/semantic_colors_test.dart
git commit -m "refactor(theme): 非方向性語意綠色改用品牌紫

successColor/dividendColor/successDark/volatilityLow 原本使用綠色，
與「下跌」語意衝突。一併合併 warning 的雙處宣告漂移
（AppTheme #FF9800 36° vs DesignTokens #FB923C 27°）。"
```

---

## Task 7: 法人分類色移除

**Files:**
- Modify: `lib/core/theme/app_theme.dart:69-77`（法人三色）
- Modify: `lib/presentation/screens/stock_detail/tabs/chip/institutional_section.dart:60,70,80,99,136,141,146`
- Modify: `lib/presentation/screens/stock_detail/tabs/chip/insider_section.dart:183-184`
- Modify: `lib/presentation/screens/stock_detail/tabs/insider_tab.dart:27-28`
- Modify: `lib/presentation/screens/stock_detail/widgets/shareholding_section.dart:115`
- Test: `test/presentation/screens/stock_detail/tabs/chip/institutional_section_test.dart`

**Interfaces:**
- Consumes: `CategoryColors.neutral`（Task 2）
- Produces: `AppTheme.foreignColor` / `investmentTrustColor` / `dealerColor` 移除

- [ ] **Step 1: 寫失敗測試**

建立 `test/presentation/screens/stock_detail/tabs/chip/institutional_section_test.dart`：

```dart
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('法人分類標記為灰階，不佔用色相', () {
    expect(ColorContrast.hue(CategoryColors.neutral), -1.0);
  });

  test('法人分類標記對卡片底達 AA 4.5:1', () {
    expect(
      ColorContrast.ratio(CategoryColors.neutral, SemanticColors.darkSurface),
      greaterThanOrEqualTo(4.5),
    );
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `grep -rn 'AppTheme.foreignColor\|AppTheme.investmentTrustColor\|AppTheme.dealerColor' lib --include="*.dart" | wc -l`
Expected: 15 —— 代表尚未遷移

- [ ] **Step 3: 實作**

`app_theme.dart` 第 69-77 行替換為：

```dart
  // 法人分類色已移除。
  //
  // 外資／投信／自營商原本各有專屬色（#3498DB / #9B59B6 / #E67E22），
  // 但實際只用於 14px 圖示、8px 圓點與 alpha 0.3 邊框，且每個實例都
  // 緊鄰文字標籤，顏色屬冗餘的第三重編碼。
  //
  // 移除同時消除四組色相過近問題，其中最嚴重的是自營橘 27° 與上漲紅
  // 355° 僅隔 32° 且出現在同一張卡片上（橘圖示配紅數字）。
  // 身分改由圖示形狀（language / account_balance / store）與文字標籤區分。
```

所有 `AppTheme.foreignColor`、`AppTheme.investmentTrustColor`、`AppTheme.dealerColor` 呼叫端一律替換為 `CategoryColors.neutral`，並於各檔加入 import：

```dart
import 'package:afterclose/core/theme/semantic_colors.dart';
```

`insider_tab.dart:27-28` 兩個常數改為：

```dart
const _kInsiderRatioColor = CategoryColors.chartPalette[0]; // 藍 500
const _kPledgeRatioColor = CategoryColors.chartPalette[2]; // 紫 500
```

此二者為折線圖序列色而非分類標記，故取自 `chartPalette`。

- [ ] **Step 4: 確認無殘留**

Run: `grep -rn 'foreignColor\|investmentTrustColor\|dealerColor' lib --include="*.dart"`
Expected: 無輸出

- [ ] **Step 5: 執行測試並 Commit**

```bash
flutter test
git add lib/core/theme/app_theme.dart lib/presentation/screens/stock_detail/ test/presentation/screens/stock_detail/tabs/chip/institutional_section_test.dart
git commit -m "refactor(theme): 移除法人分類色改用中性灰

自營橘 27° 與上漲紅 355° 僅隔 32° 且同卡片出現。法人身分已由
圖示形狀與文字標籤表達，顏色為冗餘編碼，移除不損失資訊。"
```

---

## Task 8: 圖表色盤收斂

**Files:**
- Modify: `lib/core/theme/design_tokens.dart:212-224`（chartPalette）
- Modify: `lib/presentation/screens/portfolio/widgets/industry_allocation_card.dart:20-48`
- Test: 追加至 `test/core/theme/semantic_colors_test.dart`

**Interfaces:**
- Consumes: `CategoryColors.chartPalette`（Task 2）
- Produces: `DesignTokens.chartPalette` 委派至 `CategoryColors.chartPalette`

- [ ] **Step 1: 寫失敗測試**

於 `test/core/theme/semantic_colors_test.dart` 追加：

```dart
  test('DesignTokens.chartPalette 委派至 CategoryColors', () {
    expect(DesignTokens.chartPalette, CategoryColors.chartPalette);
  });

  test('股價疊圖不得出現股價語意色', () {
    // price_overlay_chart 以 chartPalette 繪製多檔股價線，
    // 若含綠色會被讀成「該檔在跌」。
    for (final c in DesignTokens.chartPalette) {
      expect(_inPriceHueZone(c), isFalse);
    }
  });
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/core/theme/semantic_colors_test.dart`
Expected: FAIL —— 現行 8 色含 `#4CAF50`（綠 122°）與 `#F44336`（紅 4°）

- [ ] **Step 3: 實作**

`design_tokens.dart` 第 212-224 行替換為：

```dart
  /// 通用圖表色盤 —— 委派至 [CategoryColors.chartPalette]。
  ///
  /// 原本 8 色含紅 `#F44336` 與綠 `#4CAF50`，在 `price_overlay_chart`
  /// 這類股價疊圖上會被誤讀為漲跌。收斂為 6 色且全數避開股價色相區。
  static const chartPalette = CategoryColors.chartPalette;
```

`industry_allocation_card.dart` 的 `_industryColors` 對照表中，落在禁區的三項替換：`金融保險業 #22C55E`（綠 142°）→ `#3B82F6`；`航運業 #14B8A6`（青綠 173°）→ `#93C5FD`；`食品工業 #84CC16`（黃綠 82°）→ `#FDBA74`。`_fallbackColors` 改為 `CategoryColors.chartPalette`。

- [ ] **Step 4: 確認產業色表無禁區色值**

Run: `grep -nE '0xFF(22C55E|14B8A6|84CC16|F43F5E|06B6D4)' lib/presentation/screens/portfolio/widgets/industry_allocation_card.dart`
Expected: 無輸出

- [ ] **Step 5: 全套測試並 Commit**

```bash
flutter test
git add lib/core/theme/design_tokens.dart lib/presentation/screens/portfolio/widgets/industry_allocation_card.dart test/core/theme/semantic_colors_test.dart
git commit -m "refactor(theme): 圖表色盤收斂為 6 色並避開股價色相

原 8 色含紅綠，在股價疊圖上會被誤讀為漲跌。改為 3 色相 ×
2 明度，同族靠明度區分、異族色相間距 >= 35 度。"
```

---

## Task 9: 文件同步與最終驗證

**Files:**
- Modify: `CLAUDE.md`（關鍵路徑表加入 `semantic_colors.dart`）
- Modify: `CHANGELOG.md`
- Test: 全套

- [ ] **Step 1: 更新 CLAUDE.md 關鍵路徑表**

於「關鍵路徑」表格加入一列：

```markdown
| `lib/core/theme/semantic_colors.dart`            | 色彩語意分類（紅綠專屬股價，見守門測試）              |
```

- [ ] **Step 2: 更新 CHANGELOG.md**

於未發布區段加入：

```markdown
### Changed
- 色彩系統依語意分類重構：紅綠專屬多空語意，非方向性語意改用品牌紫
- 籌碼評等色階翻轉為台股慣例（強勢＝紅、弱勢＝綠）
- 深色主題表面改用中性灰，品牌色改 Violet
```

- [ ] **Step 3: 全域殘留掃描**

Run:
```bash
grep -rnE '0xFF(03DAC6|4CAF50|27AE60|10B981|4ADE80|8BC34A|3498DB|9B59B6|E67E22|6C63FF|64748B|0F172A|1E293B|334155|475569)' lib --include="*.dart"
```
Expected: 無輸出。若有命中，逐項確認是否為遺漏遷移。

- [ ] **Step 4: 全套測試**

Run: `flutter test`
Expected: PASS，約 3,165 個測試

Run: `flutter analyze --no-fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md CHANGELOG.md
git commit -m "docs: 同步色彩系統重構至 CLAUDE.md 與 CHANGELOG"
```

---

## 實作階段可能需要調整的部分

設計文件已載明圖表色盤是把握度最低的一塊。若 Task 8 完成後實機檢視發現 6 色在折線圖上仍不易區分（特別是同色族的明度階在細線條上），可行的調整方向依序為：

1. 加大同色族的明度差（將 300 階換為 200 階）
2. 為線條加上不同虛線樣式作為第二區分維度
3. 將序列上限自 6 降為 4，超過時改用直接標註

不得為了塞下更多顏色而放寬色相禁區——那是本次重構的根本目的。
