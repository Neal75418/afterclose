import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/insider_section.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  InsiderHoldingEntry createEntry({
    String symbol = '2330',
    double? insiderRatio = 15.0,
    double? pledgeRatio = 5.0,
    double? sharesChange = 1000,
    DateTime? date,
  }) {
    return InsiderHoldingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      insiderRatio: insiderRatio,
      pledgeRatio: pledgeRatio,
      sharesChange: sharesChange,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpSection(
    WidgetTester tester,
    Widget widget, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(buildTestApp(widget, brightness: brightness));
    await tester.pump(const Duration(seconds: 1));
  }

  group('InsiderSection', () {
    testWidgets('displays shield_outlined icon', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, InsiderSection(history: [createEntry()]));

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const InsiderSection(history: []));

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('displays insider ratio', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InsiderSection(history: [createEntry(insiderRatio: 15.0)]),
      );

      expect(find.text('15.00%'), findsOneWidget);
    });

    testWidgets('shows pledge warning when pledge ratio >= 30', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InsiderSection(history: [createEntry(pledgeRatio: 35.0)]),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides pledge warning when pledge ratio < 30', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InsiderSection(history: [createEntry(pledgeRatio: 10.0)]),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InsiderSection(history: [createEntry()]),
        brightness: Brightness.dark,
      );

      expect(find.byType(InsiderSection), findsOneWidget);
    });
  });
}
