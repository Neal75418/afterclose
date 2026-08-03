import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/chart_indicators.dart';

/// K 線圖四條均線的配色守門(2026-08-03)。
///
/// 起因:`k_chart_plus` 1.0.3 的 `ChartColors.getMAColor` 用 `index % 3`
/// 循環三色,而 app 畫四條線(MA5/10/20/60)——**MA60 撞回 MA5 的藍色**。
/// 使用者從圖例兩個同色標籤發現異常。同一次調查還挖出更嚴重的:1.0.3 的
/// `drawMaLine` 寫死 `if (i == 3) break;`,**第四條線根本沒被畫到 canvas**,
/// 只有圖例文字存在。兩者都在 1.0.4 修掉。
///
/// 這支測試鎖住 app 端的不變量,讓同型缺陷(不論來自套件或我們自己改
/// maDayList)在 CI 就紅:
/// 1. 四條線互不同色
/// 2. 色數 ≥ 天數(1.0.4 的 getMAColor 仍有 `% maColors.length` wrap,
///    天數長過色數會靜默撞色)
/// 3. 不落在股價語意色相禁區(紅綠專屬漲跌,K 線圖上紅綠已代表 K 棒)
/// 4. 對圖表背景達圖形物件對比門檻,且同色族的一對靠明度可區分
void main() {
  Color chartBgFor(Brightness b) => b == Brightness.dark
      ? IndicatorColors.chartDarkBackground
      : SemanticColors.lightBackground;

  bool inPriceHueZone(Color c) {
    final h = ColorContrast.hue(c);
    if (h < 0) return false; // 灰階不佔色相
    return h >= 345 || h <= 15 || (h >= 88 && h <= 175);
  }

  for (final brightness in Brightness.values) {
    group('MA 線色（$brightness）', () {
      late List<Color> ma;
      setUp(() => ma = IndicatorColors.maColorsFor(brightness));

      test('🚨 四條線互不同色（1.0.3 的 MA60 撞 MA5 迴歸鎖）', () {
        expect(ma.toSet().length, ma.length, reason: '四條均線不得共用顏色，否則圖上分不出短線與季線');
      });

      test('色數 ≥ 均線天數（防 getMAColor 的 % 長度 wrap 靜默撞色）', () {
        expect(
          ma.length,
          greaterThanOrEqualTo(kTechnicalMaDayList.length),
          reason:
              '加均線天數時必須同步加色；套件的 getMAColor 超出色數會 wrap，'
              '不會報錯只會撞色',
        );
      });

      test('不得落在股價語意色相禁區（紅綠專屬 K 棒漲跌）', () {
        for (final c in ma) {
          expect(
            inPriceHueZone(c),
            isFalse,
            reason:
                'MA 用色 ${c.toARGB32().toRadixString(16)} '
                '色相 ${ColorContrast.hue(c).toStringAsFixed(1)}° 落在漲跌色區，'
                '會與 K 棒的紅綠語意打架',
          );
        }
      });

      test('對圖表背景達圖形物件門檻 3:1', () {
        final bg = chartBgFor(brightness);
        for (final c in ma) {
          expect(
            ColorContrast.ratio(c, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'MA 線 ${c.toARGB32().toRadixString(16)} 對圖表背景對比不足',
          );
        }
      });

      test('同色族的一對須靠明度區分（比值 >= 1.5）', () {
        final bg = chartBgFor(brightness);
        for (var i = 0; i < ma.length; i++) {
          for (var j = i + 1; j < ma.length; j++) {
            final hi = ColorContrast.hue(ma[i]);
            final hj = ColorContrast.hue(ma[j]);
            var delta = (hi - hj).abs();
            if (delta > 180) delta = 360 - delta;
            if (delta > 15) continue; // 不同色族，色相本身就分得開

            final ri = ColorContrast.ratio(ma[i], bg);
            final rj = ColorContrast.ratio(ma[j], bg);
            final ratio = ri > rj ? ri / rj : rj / ri;
            expect(
              ratio,
              greaterThanOrEqualTo(1.5),
              reason:
                  '第 $i 與第 $j 條線同色族（Δ${delta.toStringAsFixed(1)}°）'
                  '且明度接近，圖上無法區分',
            );
          }
        }
      });
    });
  }

  test('maPaletteIndices 與均線天數一一對應', () {
    expect(
      IndicatorColors.maPaletteIndices.length,
      kTechnicalMaDayList.length,
      reason: '色 index tuple 與天數清單必須等長，順序即對應關係',
    );
  });
}
