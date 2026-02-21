import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_selectors.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('MainIndicatorSelector', () {
    testWidgets('displays show_chart icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          MainIndicatorSelector(selectedIndicators: const {}, onToggle: (_) {}),
        ),
      );

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('displays MA, BOLL, SAR chips', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          MainIndicatorSelector(selectedIndicators: const {}, onToggle: (_) {}),
        ),
      );

      expect(find.text('MA'), findsOneWidget);
      expect(find.text('BOLL'), findsOneWidget);
      expect(find.text('SAR'), findsOneWidget);
    });

    testWidgets('calls onToggle when chip tapped', (tester) async {
      widenViewport(tester);
      MainState? toggled;
      await tester.pumpWidget(
        buildTestApp(
          MainIndicatorSelector(
            selectedIndicators: const {},
            onToggle: (state) => toggled = state,
          ),
        ),
      );

      await tester.tap(find.text('MA'));
      expect(toggled, MainState.MA);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          MainIndicatorSelector(
            selectedIndicators: {MainState.MA},
            onToggle: (_) {},
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(MainIndicatorSelector), findsOneWidget);
    });
  });

  group('SecondaryIndicatorSelector', () {
    testWidgets('displays analytics_outlined icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SecondaryIndicatorSelector(
            selectedIndicators: const {},
            onToggle: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('displays MACD, KDJ, RSI, WR, CCI chips', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SecondaryIndicatorSelector(
            selectedIndicators: const {},
            onToggle: (_) {},
          ),
        ),
      );

      expect(find.text('MACD'), findsOneWidget);
      expect(find.text('KDJ'), findsOneWidget);
      expect(find.text('RSI'), findsOneWidget);
      expect(find.text('WR'), findsOneWidget);
      expect(find.text('CCI'), findsOneWidget);
    });

    testWidgets('calls onToggle when chip tapped', (tester) async {
      widenViewport(tester);
      SecondaryState? toggled;
      await tester.pumpWidget(
        buildTestApp(
          SecondaryIndicatorSelector(
            selectedIndicators: const {},
            onToggle: (state) => toggled = state,
          ),
        ),
      );

      await tester.tap(find.text('RSI'));
      expect(toggled, SecondaryState.RSI);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SecondaryIndicatorSelector(
            selectedIndicators: {SecondaryState.MACD},
            onToggle: (_) {},
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(SecondaryIndicatorSelector), findsOneWidget);
    });
  });
}
