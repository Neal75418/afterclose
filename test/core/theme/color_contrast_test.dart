import 'dart:ui';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativeLuminance', () {
    test('純黑為 0、純白為 1', () {
      expect(
        ColorContrast.relativeLuminance(const Color(0xFF000000)),
        closeTo(0.0, 0.0001),
      );
      expect(
        ColorContrast.relativeLuminance(const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.0001),
      );
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
      expect(
        ColorContrast.ratio(a, b),
        closeTo(ColorContrast.ratio(b, a), 1e-9),
      );
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

  group('compositeOver', () {
    test('alpha 1.0 回傳前景色', () {
      const fg = Color(0xFF8B5CF6);
      const bg = Color(0xFF27272A);
      final result = ColorContrast.compositeOver(fg, bg, 1.0);
      expect(result.r, closeTo(fg.r, 1e-9));
      expect(result.g, closeTo(fg.g, 1e-9));
      expect(result.b, closeTo(fg.b, 1e-9));
    });

    test('alpha 0.0 回傳背景色', () {
      const fg = Color(0xFF8B5CF6);
      const bg = Color(0xFF27272A);
      final result = ColorContrast.compositeOver(fg, bg, 0.0);
      expect(result.r, closeTo(bg.r, 1e-9));
      expect(result.g, closeTo(bg.g, 1e-9));
      expect(result.b, closeTo(bg.b, 1e-9));
    });

    test('黑疊 50% 於白之上為中灰', () {
      final result = ColorContrast.compositeOver(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        0.5,
      );
      expect(result.r, closeTo(0.5, 1e-9));
      expect(result.g, closeTo(0.5, 1e-9));
      expect(result.b, closeTo(0.5, 1e-9));
    });

    test('reason_tags 深色情境合成色與手算結果一致（約 #40345D）', () {
      // brandDecorative(#8B5CF6) 以 25% alpha 疊加卡片背景(#27272A)。
      final result = ColorContrast.compositeOver(
        const Color(0xFF8B5CF6),
        const Color(0xFF27272A),
        0.25,
      );
      expect(result.r * 255, closeTo(0x40, 0.6));
      expect(result.g * 255, closeTo(0x34, 0.6));
      expect(result.b * 255, closeTo(0x5D, 0.6));
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
