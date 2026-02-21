import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/day_trading_section.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  DayTradingEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? dayTradingRatio = 20.0,
  }) {
    return DayTradingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      dayTradingRatio: dayTradingRatio,
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

  group('DayTradingSection', () {
    testWidgets('displays flash_on icon', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(
          history: List.generate(
            5,
            (i) => createEntry(date: DateTime(2026, 2, 10 + i)),
          ),
        ),
      );

      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const DayTradingSection(history: []));

      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('displays latest day trading ratio', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(
          history: [
            createEntry(date: DateTime(2026, 2, 13), dayTradingRatio: 15.0),
            createEntry(date: DateTime(2026, 2, 14), dayTradingRatio: 22.5),
          ],
        ),
      );

      expect(find.text('22.5%'), findsOneWidget);
    });

    testWidgets('renders with high ratio (>= 35)', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(history: [createEntry(dayTradingRatio: 40.0)]),
      );

      // latest ratio and avg5 are both 40.0% (single entry)
      expect(find.text('40.0%'), findsWidgets);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(history: [createEntry()]),
        brightness: Brightness.dark,
      );

      expect(find.byType(DayTradingSection), findsOneWidget);
    });
  });
}
