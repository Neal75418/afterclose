import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/obv_card.dart';

import '../../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  final indicatorService = TechnicalIndicatorService();

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('OBVCard', () {
    testWidgets('displays OBV label', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0 + i * 50000);
      final obv = indicatorService.calculateOBV(closes, volumes);

      await tester.pumpWidget(buildTestApp(OBVCard(obv: obv)));

      expect(find.text('OBV'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when fewer than 5 points', (
      tester,
    ) async {
      widenViewport(tester);
      final obv = indicatorService.calculateOBV(
        const [100, 101],
        const [1000, 2000],
      );

      await tester.pumpWidget(buildTestApp(OBVCard(obv: obv)));

      // Should show SizedBox.shrink
      expect(find.text('OBV'), findsNothing);
    });

    testWidgets('shows 5-day change', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0);
      final obv = indicatorService.calculateOBV(closes, volumes);

      await tester.pumpWidget(buildTestApp(OBVCard(obv: obv)));

      expect(find.textContaining('(5d)'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0);
      final obv = indicatorService.calculateOBV(closes, volumes);

      await tester.pumpWidget(
        buildTestApp(OBVCard(obv: obv), brightness: Brightness.dark),
      );

      expect(find.text('OBV'), findsOneWidget);
    });

    testWidgets('平盤 5 日變化（0）不帶 + 號', (tester) async {
      widenViewport(tester);
      // 第 5 根前的 OBV 與最新值相等 → obvChange == 0
      await tester.pumpWidget(
        buildTestApp(const OBVCard(obv: [100.0, 50.0, 60.0, 70.0, 80.0, 50.0])),
      );

      expect(find.text('+0 (5d)'), findsNothing, reason: '平盤 5 日變化不得帶 +');
      expect(find.text('0 (5d)'), findsOneWidget);
    });
  });
}
