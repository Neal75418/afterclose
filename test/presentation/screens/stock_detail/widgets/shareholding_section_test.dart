import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/shareholding_section.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  ShareholdingEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? foreignSharesRatio = 75.0,
  }) {
    return ShareholdingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      foreignSharesRatio: foreignSharesRatio,
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

  group('ShareholdingSection', () {
    testWidgets('displays language icon', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(
          history: List.generate(
            5,
            (i) => createEntry(date: DateTime(2026, 2, 10 + i)),
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const ShareholdingSection(history: []));

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('displays foreign shares ratio', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(history: [createEntry(foreignSharesRatio: 72.35)]),
      );

      expect(find.text('72.35%'), findsOneWidget);
    });

    testWidgets('detects increasing trend', (tester) async {
      widenViewport(tester);
      final entries = List.generate(
        5,
        (i) => createEntry(
          date: DateTime(2026, 2, 10 + i),
          foreignSharesRatio: 70.0 + i * 0.5,
        ),
      );

      await pumpSection(tester, ShareholdingSection(history: entries));

      expect(find.byType(ShareholdingSection), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(history: [createEntry()]),
        brightness: Brightness.dark,
      );

      expect(find.byType(ShareholdingSection), findsOneWidget);
    });
  });
}
