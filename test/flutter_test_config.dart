import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全域測試設定
///
/// Flutter test runner 會自動執行此檔案的 [testExecutable]。
/// 用於初始化 EasyLocalization 並抑制 `Localization key [xxx] not found` 警告，
/// 避免測試輸出被大量無關 warning 淹沒。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];

  await testMain();
}
