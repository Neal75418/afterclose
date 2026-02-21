import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/dividend_table.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  FinMindDividend createDividend({
    String stockId = '2330',
    int year = 2025,
    double cashDividend = 3.0,
    double stockDividend = 0.0,
  }) {
    return FinMindDividend(
      stockId: stockId,
      year: year,
      cashDividend: cashDividend,
      stockDividend: stockDividend,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('DividendTable', () {
    testWidgets('renders with dividend data', (tester) async {
      widenViewport(tester);
      final dividends = [
        createDividend(year: 2025, cashDividend: 3.5),
        createDividend(year: 2024, cashDividend: 3.0),
        createDividend(year: 2023, cashDividend: 2.75),
      ];

      await tester.pumpWidget(
        buildTestApp(DividendTable(dividends: dividends, showROCYear: false)),
      );

      expect(find.byType(DividendTable), findsOneWidget);
      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('renders with empty dividends', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const DividendTable(dividends: [], showROCYear: false)),
      );

      expect(find.byType(DividendTable), findsOneWidget);
      expect(find.byIcon(Icons.payments), findsNothing);
    });

    testWidgets('limits display to 5 years', (tester) async {
      widenViewport(tester);
      final dividends = List.generate(
        8,
        (i) => createDividend(year: 2025 - i, cashDividend: 3.0 + i * 0.1),
      );

      await tester.pumpWidget(
        buildTestApp(DividendTable(dividends: dividends, showROCYear: false)),
      );

      expect(find.byType(DividendTable), findsOneWidget);
    });

    testWidgets('renders with ROC year format', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          DividendTable(
            dividends: [createDividend(year: 2025)],
            showROCYear: true,
          ),
        ),
      );

      expect(find.byType(DividendTable), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          DividendTable(dividends: [createDividend()], showROCYear: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(DividendTable), findsOneWidget);
    });
  });
}
