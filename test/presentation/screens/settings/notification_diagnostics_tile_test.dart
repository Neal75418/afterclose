import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/presentation/screens/settings/widgets/notification_diagnostics_tile.dart';

import '../../../helpers/widget_test_helpers.dart';

/// 通知診斷面板(2026-08-08)。
///
/// 存在理由:實機發現授權對話框不跳,排查時卻沒有任何可觀察狀態——
/// 版本、簽章、初始化、entitlement 逐一排除後仍不知道請求有沒有發出去。
/// **沒有可觀察的狀態就沒有可驗證的修復。**
void main() {
  setUpAll(() async => setupTestLocalization());

  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 2000);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('顯示三個關鍵事實與三顆動作鈕', (tester) async {
    widen(tester);
    await tester.pumpWidget(
      buildTestApp(const ProviderScope(child: NotificationDiagnosticsTile())),
    );
    await tester.pump();

    expect(find.textContaining('服務已初始化'), findsOneWidget);
    expect(find.textContaining('系統通知權限'), findsOneWidget);
    expect(find.textContaining('平台'), findsOneWidget);

    expect(find.text('重新初始化'), findsOneWidget);
    expect(find.text('請求通知權限'), findsOneWidget);
    expect(find.text('送測試通知'), findsOneWidget);
  });

  testWidgets('未授權時以錯誤色標示(要看得出來是壞的)', (tester) async {
    widen(tester);
    await tester.pumpWidget(
      buildTestApp(const ProviderScope(child: NotificationDiagnosticsTile())),
    );
    await tester.pump();
    // 預設狀態為未初始化/未授權 → 應顯示「否」與「未授權」
    expect(find.text('否'), findsOneWidget);
    expect(find.text('未授權'), findsOneWidget);
  });
}
