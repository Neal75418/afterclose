import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/presentation/widgets/brand_mark.dart';

import '../../helpers/widget_test_helpers.dart';

/// 品牌標記(2026-08-07 更名 Daredevil 時新增)。
///
/// 刻意是**原創幾何**(雷達感知同心弧)而非角色圖:Marvel 角色像與 DD
/// 胸章是註冊商標,不進本專案;同心弧同時是「不看盤、靠資料感知市場」
/// 的視覺語言,比角色頭像更貼題。
void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  for (final brightness in Brightness.values) {
    testWidgets('渲染不拋例外($brightness)', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const BrandMark(), brightness: brightness),
      );
      expect(find.byType(BrandMark), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('含文字時顯示 Daredevil 字樣', (tester) async {
    await tester.pumpWidget(buildTestApp(const BrandMark(showWordmark: true)));
    expect(find.text('Daredevil'), findsOneWidget);
  });

  testWidgets('showWordmark: false 時只有圖形,不佔文字空間', (tester) async {
    await tester.pumpWidget(buildTestApp(const BrandMark()));
    expect(find.text('Daredevil'), findsNothing);
  });

  testWidgets('size 決定圖形尺寸', (tester) async {
    await tester.pumpWidget(buildTestApp(const BrandMark(size: 40)));
    // 量 BrandMark 本身:內部 CustomPaint 之外 Material 也會產生 CustomPaint,
    // 用 byType(CustomPaint).first 會量到整個 Scaffold
    expect(tester.getSize(find.byType(BrandMark)), const Size(40, 40));
  });
}
