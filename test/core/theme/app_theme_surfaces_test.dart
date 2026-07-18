import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('深色主題 primary 對背景達 AA、onPrimary 為深色', () {
    final theme = AppTheme.darkTheme;
    expect(
      ColorContrast.ratio(
        theme.colorScheme.primary,
        theme.scaffoldBackgroundColor,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ColorContrast.ratio(
        theme.colorScheme.onPrimary,
        theme.colorScheme.primary,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('主題內不再出現 Material 預設 teal', () {
    final theme = AppTheme.darkTheme;
    expect(theme.colorScheme.secondary, isNot(const Color(0xFF03DAC6)));
  });

  test('深色主題表面色飽和度低於 10%', () {
    final theme = AppTheme.darkTheme;
    for (final c in [
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
      theme.dividerTheme.color!,
    ]) {
      final s = HSLColor.fromColor(c).saturation;
      expect(
        s,
        lessThan(0.10),
        reason:
            '${c.toARGB32().toRadixString(16)} 飽和度 '
            '${(s * 100).toStringAsFixed(0)}% 過高，會與股價綠色競爭色相',
      );
    }
  });

  test('深色主題表面色取自 SemanticColors', () {
    final theme = AppTheme.darkTheme;
    expect(theme.scaffoldBackgroundColor, SemanticColors.darkBackground);
    expect(theme.colorScheme.surface, SemanticColors.darkSurface);
  });
}
