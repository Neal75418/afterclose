import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/margin_trading_section.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  MarginTradingEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? marginBalance = 50000,
    double? shortBalance = 3000,
  }) {
    return MarginTradingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      marginBalance: marginBalance,
      shortBalance: shortBalance,
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

  group('MarginTradingSection', () {
    testWidgets('displays swap_horiz icon', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, MarginTradingSection(history: [createEntry()]));

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const MarginTradingSection(history: []));

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('displays margin balance summary', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        MarginTradingSection(
          history: [createEntry(marginBalance: 50000, shortBalance: 3000)],
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.byIcon(Icons.percent), findsOneWidget);
    });

    testWidgets('shows high ratio warning when > 10%', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        MarginTradingSection(
          history: [createEntry(marginBalance: 10000, shortBalance: 2000)],
        ),
      );

      // ratio = 2000/10000*100 = 20% > 10%
      expect(find.textContaining('20.0%'), findsWidgets);
    });

    testWidgets('renders table with multiple entries', (tester) async {
      widenViewport(tester);
      final entries = List.generate(
        5,
        (i) => createEntry(
          date: DateTime(2026, 2, 10 + i),
          marginBalance: (50000 + i * 1000).toDouble(),
        ),
      );

      await pumpSection(tester, MarginTradingSection(history: entries));

      expect(find.byType(MarginTradingSection), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        MarginTradingSection(history: [createEntry()]),
        brightness: Brightness.dark,
      );

      expect(find.byType(MarginTradingSection), findsOneWidget);
    });
  });
}
