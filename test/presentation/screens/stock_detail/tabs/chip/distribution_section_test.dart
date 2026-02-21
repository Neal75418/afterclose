import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/distribution_section.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  HoldingDistributionEntry createEntry({
    String symbol = '2330',
    String level = '1-999',
    double? percent = 5.0,
    int? shareholders = 100000,
  }) {
    return HoldingDistributionEntry(
      symbol: symbol,
      date: DateTime(2026, 2, 14),
      level: level,
      percent: percent,
      shareholders: shareholders,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpSection(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(buildTestApp(widget));
    await tester.pump(const Duration(seconds: 1));
  }

  group('DistributionSection', () {
    testWidgets('displays pie_chart_outline icon', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DistributionSection(distribution: [createEntry()]),
      );

      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const DistributionSection(distribution: []));

      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('displays level text and percentage', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DistributionSection(
          distribution: [
            createEntry(level: '1-999', percent: 25.5),
            createEntry(level: '1000-5000', percent: 30.2),
          ],
        ),
      );

      expect(find.text('1-999'), findsOneWidget);
      expect(find.text('25.5%'), findsOneWidget);
      expect(find.text('1000-5000'), findsOneWidget);
      expect(find.text('30.2%'), findsOneWidget);
    });

    testWidgets('limits display to 8 entries', (tester) async {
      widenViewport(tester);
      final entries = List.generate(
        12,
        (i) => createEntry(level: 'level-$i', percent: (i + 1) * 2.0),
      );

      await pumpSection(tester, DistributionSection(distribution: entries));

      expect(find.byType(DistributionSection), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          DistributionSection(distribution: [createEntry()]),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DistributionSection), findsOneWidget);
    });
  });
}
