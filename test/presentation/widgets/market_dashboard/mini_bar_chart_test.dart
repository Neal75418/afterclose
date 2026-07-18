// 迷你柱狀圖配色迴歸 —— flat-value sign/color 缺陷類第三輪
//
// 原本柱色以 `v >= 0 ? upColor : downColor` 二分，平盤（0）被著成漲色。
// 對齊 institutional_flow_chart 的嚴格三分法：> 0 漲色 / < 0 跌色 /
// == 0 中性色。
//
// 柱色畫在 canvas 上、painter 為私有類別，無法從 widget tree 觀察，
// 因此把選色抽成純函式 [miniBarColor] 直接驗證。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/mini_bar_chart.dart';

void main() {
  const up = Color(0xFFFF4757);
  const down = Color(0xFF2ED573);
  const neutral = AppTheme.neutralColor;

  Color colorFor(double v) =>
      miniBarColor(v, upColor: up, downColor: down, neutralColor: neutral);

  group('miniBarColor 嚴格三分法', () {
    test('正值走漲色', () {
      expect(colorFor(1.0), up);
      expect(colorFor(0.0001), up);
    });

    test('負值走跌色', () {
      expect(colorFor(-1.0), down);
      expect(colorFor(-0.0001), down);
    });

    test('平盤（0）走中性色，不著漲色', () {
      expect(colorFor(0), neutral);
      expect(colorFor(0), isNot(up));
    });
  });

  group('MiniBarChart 渲染', () {
    testWidgets('含 0 的序列可正常渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MiniBarChart(dataPoints: [1.0, 0.0, -1.0, 2.0]),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MiniBarChart), findsOneWidget);
    });

    testWidgets('少於 2 筆資料不繪製', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: MiniBarChart(dataPoints: [1.0])),
        ),
      );

      // Scaffold 自身也有 CustomPaint，需限定在 MiniBarChart 子樹內判斷
      expect(
        find.descendant(
          of: find.byType(MiniBarChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
