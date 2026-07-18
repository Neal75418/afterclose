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
