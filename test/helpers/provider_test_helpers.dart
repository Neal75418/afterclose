import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// 建立需要 Riverpod Provider 的測試用 MaterialApp 包裝
///
/// 適用於依賴 Provider 的 Widget 測試（如 Screen 子元件）。
/// [overrides] 傳入 mock provider override 列表。
/// 預設覆寫 [databaseProvider] 為 in-memory DB，避免 Drift multiple-database warning。
Widget buildProviderTestApp(
  Widget child, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(AppDatabase.forTesting()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}
