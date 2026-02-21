import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

import '../../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('IndicatorCardContainer', () {
    testWidgets('renders child widget', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const IndicatorCardContainer(child: Text('Test Content'))),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const IndicatorCardContainer(child: Text('Dark')),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('Dark'), findsOneWidget);
    });
  });

  group('LabeledValue', () {
    testWidgets('displays label and formatted value', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const LabeledValue(label: 'DIF', value: 12.345, color: Colors.blue),
        ),
      );

      expect(find.text('DIF'), findsOneWidget);
      expect(find.text('12.35'), findsOneWidget);
    });

    testWidgets('displays dash when value is null', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const LabeledValue(label: 'DEA', value: null, color: Colors.red),
        ),
      );

      expect(find.text('DEA'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const LabeledValue(label: 'HIST', value: 5.0, color: Colors.green),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('HIST'), findsOneWidget);
      expect(find.text('5.00'), findsOneWidget);
    });
  });
}
