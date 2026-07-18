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

  group('第二層：對比度守門', () {
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
