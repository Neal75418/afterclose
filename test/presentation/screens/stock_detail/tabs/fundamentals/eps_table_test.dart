import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/eps_table.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  FinancialDataEntry createEps({
    String symbol = '2330',
    int year = 2025,
    int month = 9,
    double? value = 9.56,
  }) {
    return FinancialDataEntry(
      symbol: symbol,
      date: DateTime(year, month),
      statementType: 'quarterly',
      dataType: 'eps',
      value: value,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('EpsTable', () {
    testWidgets('renders with EPS data', (tester) async {
      widenViewport(tester);
      final epsData = [
        createEps(year: 2025, month: 9, value: 9.56),
        createEps(year: 2025, month: 6, value: 8.43),
        createEps(year: 2025, month: 3, value: 7.21),
      ];

      await tester.pumpWidget(
        buildTestApp(EpsTable(epsHistory: epsData, showROCYear: false)),
      );

      expect(find.byType(EpsTable), findsOneWidget);
      expect(find.text('9.56'), findsOneWidget);
    });

    testWidgets('renders with empty data', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const EpsTable(epsHistory: [], showROCYear: false)),
      );

      expect(find.byType(EpsTable), findsOneWidget);
    });

    testWidgets('displays null EPS as dash', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EpsTable(epsHistory: [createEps(value: null)], showROCYear: false),
        ),
      );

      expect(find.text('-'), findsWidgets);
    });

    testWidgets('renders with ROC year format', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EpsTable(
            epsHistory: [createEps(year: 2025, month: 9)],
            showROCYear: true,
          ),
        ),
      );

      expect(find.byType(EpsTable), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EpsTable(epsHistory: [createEps()], showROCYear: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(EpsTable), findsOneWidget);
    });
  });
}
