import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/theme/app_theme.dart';
import 'package:daredevil/core/theme/color_contrast.dart';
import 'package:daredevil/core/theme/semantic_colors.dart';
import 'package:daredevil/presentation/screens/stock_detail/widgets/chart_indicator_styles.dart';

/// 副圖指標色彩守門(2026-08-05 複審 High #3 迴歸鎖)。
///
/// 遷移 1.0.4 時副圖曾用套件預設樣式:MACD 柱「綠=正、紅=負」與台股
/// 語意相反(1.0.3 吃 app 設定本來正確),預設線色踩股價紅綠禁區。
/// 此測試鎖兩個不變量:
/// 1. MACD 柱色必須**等於** app 的漲跌語意色(紅=多、綠=空)
/// 2. 全部線色不得落入股價色相禁區(紅 ≥345/≤15、綠 88–175)
void main() {
  bool inPriceHueZone(Color c) {
    final h = ColorContrast.hue(c);
    if (h < 0) return false;
    return h >= 345 || h <= 15 || (h >= 88 && h <= 175);
  }

  for (final b in Brightness.values) {
    group('副圖樣式($b)', () {
      test('🚨 MACD 柱=台股語意:正=漲色、負=跌色(1.0.3→1.0.4 迴歸鎖)', () {
        final macd = ChartIndicatorStyles.macdFor(b);
        expect(macd.upColor, AppTheme.upColor, reason: '正柱必須是 app 漲色(紅)');
        expect(macd.dnColor, PriceColors.downFor(b), reason: '負柱必須是 app 跌色(綠)');
      });

      test('全部線色不落股價紅綠色相禁區', () {
        for (final c in ChartIndicatorStyles.lineColorsFor(b)) {
          expect(
            inPriceHueZone(c),
            isFalse,
            reason:
                '線色 ${c.toARGB32().toRadixString(16)} '
                '(${ColorContrast.hue(c).toStringAsFixed(1)}°) 落入漲跌禁區',
          );
        }
      });
    });
  }
}
