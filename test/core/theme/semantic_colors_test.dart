import 'dart:ui';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:flutter/material.dart' show ThemeData;
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

    test('CategoryColors.chartPalette 不得落在股價色相區（深色＋淺色主題）', () {
      for (final c in [
        ...CategoryColors.chartPaletteDark,
        ...CategoryColors.chartPaletteLight,
      ]) {
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

    test('圖表色盤每色對深色主題兩種實際背景達圖形物件門檻 3:1', () {
      // chartPaletteDark 的消費者落在兩種不同的深色背景：comparison_* 四個
      // widget（包在 Card 內）與 insider_tab 的 MetricCard 圖示走 Card／
      // surface（#27272A，即 darkCard）；price_overlay_chart 等無自身背景
      // 容器者落在 scaffoldBackgroundColor（#18181B，即 darkBg）。darkCard
      // 是較嚴苛的背景——同一顏色對 darkCard 的對比恆比對 darkBg 低（例：
      // 紫 500 對 darkBg 4.18:1、對 darkCard 僅 3.52:1，是六色中對 darkCard
      // 餘裕最小者，`ColorContrast` 精算）。過去只驗證過 scaffold 背景，
      // 與淺色主題兩種背景皆驗證的作法不對稱——這正是紫 500 若調整為貼近
      // darkBg 邊界的色值（例如 #7D4FE8，對 darkBg 仍有 3.51:1 合格）時，
      // 對 darkCard 已跌破門檻（2.95:1）卻不會被舊測試攔下的原因，兩種
      // 深色背景都要驗證，不能只驗其中一種。
      for (final c in CategoryColors.chartPaletteDark) {
        expect(
          ColorContrast.ratio(c, darkBg),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteDark ${c.toARGB32().toRadixString(16)} '
              '對 background(#18181B) 對比不足',
        );
        expect(
          ColorContrast.ratio(c, darkCard),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteDark ${c.toARGB32().toRadixString(16)} '
              '對 card(#27272A) 對比不足',
        );
      }
    });

    test('圖表色盤每色對「MetricCard 圖示 10% 疊色 card」的合成背景達圖形物件門檻 3:1（深色主題）', () {
      // 淺色主題已驗證 MetricCard 疊色情境（見下方淺色主題分組），深色
      // 主題卻從未驗證對應的合成背景——這正是同一種「只驗證其中一種背景」
      // 疏漏在深淺主題間再次出現的地方。fundamentals_tab.dart 的 P/E／
      // P/B／殖利率三張 MetricCard（Task 9 由字面值色改為取自本色盤）與
      // insider_tab.dart 皆落在這個情境，若不獨立守門，任何未來調色都可能
      // 讓深色主題的合成對比悄悄跌破 3.0:1 卻不被任何測試攔下。
      for (final c in CategoryColors.chartPaletteDark) {
        final composite = ColorContrast.compositeOver(
          c,
          darkCard,
          DesignTokens.opacity10,
        );
        expect(
          ColorContrast.ratio(c, composite),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteDark ${c.toARGB32().toRadixString(16)} '
              '疊色後對 MetricCard 合成背景（深色）對比不足',
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
    const lightBg = SemanticColors.lightBackground; // #FFFFFF（Card／scaffold）
    const lightSurface = SemanticColors.lightSurface; // #F8F9FA（surface）

    test('圖表色盤每色對淺色主題兩種實際背景達圖形物件門檻 3:1', () {
      // chartPaletteLight 的消費者落在兩種不同的淺色背景：
      // IndustryAllocationCard 的備用色、insider_tab 的 MetricCard 圖示走
      // surfaceContainerLow（#F8F9FA，即 lightSurface）；AllocationPieChart
      // 無自身背景容器落在 scaffoldBackgroundColor，comparison_* 系列走
      // Card，兩者皆為 #FFFFFF（lightBg）。過去只驗證過深色背景，這正是
      // chartPalette 6 色中有 4 色對淺色背景低於 3.0:1 從未被攔下的原因，
      // 兩種淺色背景都要驗證，不能只驗其中一種。
      for (final c in CategoryColors.chartPaletteLight) {
        expect(
          ColorContrast.ratio(c, lightSurface),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteLight ${c.toARGB32().toRadixString(16)} '
              '對 surface(#F8F9FA) 對比不足',
        );
        expect(
          ColorContrast.ratio(c, lightBg),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteLight ${c.toARGB32().toRadixString(16)} '
              '對 background(#FFFFFF) 對比不足',
        );
      }
    });

    test('圖表色盤每色對「MetricCard 圖示 10% 疊色 surface」的合成背景達圖形物件門檻 3:1（淺色主題）', () {
      // metric_card.dart 圖示的實際渲染背景不是純色 surfaceContainerLow
      // ——圖示外圓是 accentColor 以 10%（DesignTokens.opacity10）alpha
      // 疊加在 surfaceContainerLow（淺色主題 #F8F9FA，即 lightSurface）
      // 之上的合成色，圖示本身（accentColor 純色）才是疊加在這個合成色
      // 上方的前景。insider_tab.dart 的 insiderRatio／pledgeRatio 兩張
      // MetricCard 正是分別取用 chartPaletteLight[0]／[2] 作為
      // accentColor。上面「兩種實際背景」測試驗證的是 `ColorContrast
      // .ratio(c, lightSurface)`（純色背景假設），對 600 階三色（索引
      // 0/1/2）算出 3.42-3.43:1；但實際合成背景因疊入 10% 前景色而更
      // 接近前景本身，真實對比收窄至 3.07-3.08:1（`ColorContrast
      // .compositeOver` 精算，最窄為橘 600 `#D76618` 的 3.0653:1）——仍
      // 達 3.0:1 門檻，但餘裕已不到 0.07，純色背景假設高估了實際餘裕，
      // 需要獨立守門，不能只靠上面的純背景測試涵蓋。
      for (final c in CategoryColors.chartPaletteLight) {
        final composite = ColorContrast.compositeOver(
          c,
          lightSurface,
          DesignTokens.opacity10,
        );
        expect(
          ColorContrast.ratio(c, composite),
          greaterThanOrEqualTo(3.0),
          reason:
              'chartPaletteLight ${c.toARGB32().toRadixString(16)} '
              '疊色後對 MetricCard 合成背景對比不足',
        );
      }
    });

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
    // 色相差 <= 15 度視為同族（需明度比值 >= 1.5 區分），否則須間距 >= 35 度。
    // 抽成共用函式讓深色／淺色兩組色盤套同一份判準，而非各自重寫一份、
    // 兩邊標準悄悄分岔。
    void checkFamilySpacing(List<Color> palette, Color bg) {
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
    }

    test('深色主題：不同色族間距 >= 35 度、同色族對比比值 >= 1.5', () {
      checkFamilySpacing(
        CategoryColors.chartPaletteDark,
        SemanticColors.darkBackground,
      );
    });

    test('淺色主題：不同色族間距 >= 35 度、同色族對比比值 >= 1.5', () {
      // 深色主題只驗證過這條規則，淺色主題從未套用過——這正是
      // chartPaletteLight 需要獨立設計、獨立驗證的原因之一。
      checkFamilySpacing(
        CategoryColors.chartPaletteLight,
        SemanticColors.lightBackground,
      );
    });
  });

  group('圖表色盤收斂（Task 8）', () {
    test(
      'DesignTokens.chartPaletteFor 依主題委派至 CategoryColors.chartPaletteFor',
      () {
        // chartPalette 曾是 `static const` 直接指向深色那組色盤，改為依主題
        // 解析的方法後，委派關係要兩個 Brightness 都驗證——只驗證其中一個
        // 會漏掉「淺色主題忘記接上新色盤」這類回歸。
        expect(
          DesignTokens.chartPaletteFor(ThemeData(brightness: Brightness.dark)),
          CategoryColors.chartPaletteFor(Brightness.dark),
        );
        expect(
          DesignTokens.chartPaletteFor(ThemeData(brightness: Brightness.light)),
          CategoryColors.chartPaletteFor(Brightness.light),
        );
      },
    );

    test('股價疊圖不得出現股價語意色（兩主題）', () {
      // price_overlay_chart 以 chartPalette 繪製多檔股價線，
      // 若含綠色會被讀成「該檔在跌」。
      for (final c in [
        ...CategoryColors.chartPaletteDark,
        ...CategoryColors.chartPaletteLight,
      ]) {
        expect(_inPriceHueZone(c), isFalse);
      }
    });
  });
}
