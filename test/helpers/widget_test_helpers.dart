import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 建立測試用的 MaterialApp 包裝
///
/// 使用 production 主題（AppTheme），確保測試環境與實際 app 一致。
Widget buildTestApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light
        ? AppTheme.lightTheme
        : AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}
