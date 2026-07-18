import 'dart:ui';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
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
        expect(
          _inPriceHueZone(c),
          isFalse,
          reason:
              'QualityColors 含 ${c.toARGB32().toRadixString(16)}，'
              '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}° 落在股價語意區',
        );
      }
    });

    test('WarningColors 不得落在股價色相區', () {
      for (final c in WarningColors.all) {
        expect(
          _inPriceHueZone(c),
          isFalse,
          reason:
              'WarningColors 含 ${c.toARGB32().toRadixString(16)}，'
              '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}°',
        );
      }
    });

    test('CategoryColors.chartPalette 不得落在股價色相區', () {
      for (final c in CategoryColors.chartPalette) {
        expect(
          _inPriceHueZone(c),
          isFalse,
          reason:
              'chartPalette 含 ${c.toARGB32().toRadixString(16)}，'
              '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}°',
        );
      }
    });
  });

  group('第二層：對比度守門 —— 深色主題', () {
    const darkBg = SemanticColors.darkBackground;
    const darkCard = SemanticColors.darkSurface;

    test('品牌文字色對深色背景與卡片皆達 AA 4.5:1', () {
      expect(
        ColorContrast.ratio(QualityColors.brandOnDark, darkBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        ColorContrast.ratio(QualityColors.brandOnDark, darkCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('品牌填色上的文字色達 AA 4.5:1', () {
      expect(
        ColorContrast.ratio(QualityColors.onBrand, QualityColors.brand),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('圖表色盤每色對深色背景達圖形物件門檻 3:1', () {
      for (final c in CategoryColors.chartPalette) {
        expect(
          ColorContrast.ratio(c, darkBg),
          greaterThanOrEqualTo(3.0),
          reason: 'chartPalette ${c.toARGB32().toRadixString(16)} 對比不足',
        );
      }
    });

    test('警示色（深色主題）對深色背景達 AA 4.5:1', () {
      // 用 darkOnly 而非 all——warningOnLight 是淺色主題專用色，
      // 預定背景是白底，對深色背景驗證不適用，見下方淺色主題分組。
      for (final c in WarningColors.darkOnly) {
        expect(ColorContrast.ratio(c, darkBg), greaterThanOrEqualTo(4.5));
      }
    });

    test('品牌文字色對「裝飾底疊加卡片背景」的合成色達 AA 4.5:1（ReasonTags 深色情境）', () {
      // reason_tags.dart 深色主題底色不是平面卡片背景——是 brandDecorative
      // 以 DesignTokens.opacity25（實際生產 alpha）疊加卡片背景（darkCard，
      // 即 SemanticColors.darkSurface）後的合成色。上面幾個測試只驗證品牌
      // 文字對「平面」背景（darkBg／darkCard）的對比度，brand（#A78BFA）
      // 對此合成色僅 4.1:1，兩者是不同的顏色配對，不能互相替代——這正是
      // 上一輪疊色情境退步完全沒被攔下的原因。
      final composite = ColorContrast.compositeOver(
        QualityColors.brandDecorative,
        darkCard,
        DesignTokens.opacity25,
      );
      expect(
        ColorContrast.ratio(QualityColors.brandOnDecorative, composite),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('品牌文字色對「12% 疊色卡片背景」的合成色達 AA 4.5:1（PinnedThesis 深色情境）', () {
      // pinned_thesis_section.dart 深色主題「有效狀態」徽章文字色是
      // DesignTokens.successColor(theme)（深色主題委派至 successDark，即
      // QualityColors.brand），底色是同一個 successDark 以生產碼字面值 12%
      // alpha（pinned_thesis_section.dart 未走 DesignTokens.opacityNN 命名、
      // 直接寫字面值 0.12）疊加卡片背景（darkCard）後的合成色。
      //
      // successDark 由舊值 #4ADE80（emerald，對此疊色情境曾達 6.62:1）
      // 遷移為 brand（#A78BFA）後，對比度收窄至 4.5038237667945165:1
      // （`ColorContrast` 精算，非四捨五入）——餘裕僅約 0.0038（不到
      // 0.1%）。任何未來的 Card 底色調整、alpha 微調或品牌色相微調都可能
      // 讓它悄悄跌破 4.5:1，需要獨立守門，不能只靠上面「平面背景」或
      // ReasonTags 疊色情境的品牌色測試涵蓋——那些驗證的是不同的顏色配對。
      final composite = ColorContrast.compositeOver(
        DesignTokens.successDark,
        darkCard,
        0.12,
      );
      expect(
        ColorContrast.ratio(DesignTokens.successDark, composite),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('第二層：對比度守門 —— 淺色主題', () {
    const lightBg = SemanticColors.lightBackground;

    test('品牌色（淺色主題）對白底達 AA 4.5:1', () {
      expect(
        ColorContrast.ratio(QualityColors.brandOnLight, lightBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('警示色（淺色主題）對白底達 AA 4.5:1', () {
      expect(
        ColorContrast.ratio(WarningColors.warningOnLight, lightBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('下跌色（淺色主題）對白底達大字門檻 3.0:1', () {
      // downOnLight 只套 WCAG 大字（Large Text）門檻 3.0:1，不套一般文字
      // 門檻 4.5:1：股價數字一律為粗體 ≥15px，符合大字定義。這是既有的
      // 台股綠色值，設計文件明訂不因對比度小數點差異而更動漲跌色——
      // 同樣理由也適用於 PriceColors.up 對卡片底的 4.46:1（見
      // docs/plans/2026-07-18-color-system-semantic-redesign-design.md）。
      expect(
        ColorContrast.ratio(PriceColors.downOnLight, lightBg),
        greaterThanOrEqualTo(3.0),
        reason: '股價數字為粗體大字，適用 WCAG 大字門檻 3.0:1，非一般文字 4.5:1',
      );
    });
  });

  group('第三層：語意單調性守門', () {
    test('籌碼評等五級全部落在股價色相區或為灰階', () {
      for (final r in ChipRating.values) {
        final c = PriceColors.chipRating(r);
        final h = ColorContrast.hue(c);
        expect(h < 0 || _inPriceHueZone(c), isTrue, reason: '$r 對應色非股價語意色');
      }
    });

    test('籌碼評等自強勢至弱勢單調由紅轉綠', () {
      // 以「紅色分量減綠色分量」作為多空傾向指標，強勢端最大、弱勢端最小。
      double bias(Color c) => c.r - c.g;

      final values = ChipRating.values
          .map((r) => bias(PriceColors.chipRating(r)))
          .toList();

      for (var i = 0; i < values.length - 1; i++) {
        expect(
          values[i],
          greaterThan(values[i + 1]),
          reason:
              '${ChipRating.values[i]} 到 ${ChipRating.values[i + 1]} '
              '未維持由紅至綠的單調性',
        );
      }
    });

    test('籌碼強勢與上漲同色、弱勢與下跌同色', () {
      expect(PriceColors.chipRating(ChipRating.strong), PriceColors.up);
      expect(PriceColors.chipRating(ChipRating.weak), PriceColors.down);
    });
  });

  group('Quality 類綠色已完成遷移', () {
    test('DesignTokens success 兩主題皆非綠色相', () {
      for (final c in [DesignTokens.successLight, DesignTokens.successDark]) {
        final h = ColorContrast.hue(c);
        expect(
          h >= 88 && h <= 175,
          isFalse,
          reason:
              'success 仍為綠色 ${h.toStringAsFixed(1)}°，'
              '會與「下跌」語意混淆',
        );
      }
    });

    test('warning 色僅宣告一處', () {
      // AppTheme.warningColor 與 DesignTokens.warningDark 曾各自宣告不同值
      // （#FF9800 36° vs #FB923C 27°），合併後兩者必須同值。兩側都要斷言
      // ——先前只斷言 DesignTokens.warningDark 一側，AppTheme.warningColor
      // 單獨改回舊值 #FF9800 不會被抓到（整份測試檔仍全綠），防不住註解
      // 宣稱要防的雙處宣告漂移。
      expect(DesignTokens.warningDark, WarningColors.warning);
      expect(AppTheme.warningColor, WarningColors.warning);
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
            expect(
              hiR / loR,
              greaterThanOrEqualTo(1.5),
              reason: '同色族 $i/$j 明度差不足，線條會難以區分',
            );
          } else {
            expect(
              delta,
              greaterThanOrEqualTo(35.0),
              reason: '色族 $i/$j 間距 ${delta.toStringAsFixed(1)}° 過近',
            );
          }
        }
      }
    });
  });
}
