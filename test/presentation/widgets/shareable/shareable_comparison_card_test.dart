import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/widgets/shareable/shareable_comparison_card.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  final defaultDate = DateTime(2026, 2, 13);

  ComparisonState createState() {
    return ComparisonState(
      symbols: const ['2330', '2317'],
      stocksMap: {
        '2330': StockMasterEntry(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
          isActive: true,
          updatedAt: defaultDate,
        ),
        '2317': StockMasterEntry(
          symbol: '2317',
          name: '鴻海',
          market: 'TWSE',
          isActive: true,
          updatedAt: defaultDate,
        ),
      },
      latestPricesMap: {
        '2330': DailyPriceEntry(
          symbol: '2330',
          date: defaultDate,
          close: 600.0,
          volume: 50000,
        ),
        '2317': DailyPriceEntry(
          symbol: '2317',
          date: defaultDate,
          close: 100.0,
          volume: 30000,
        ),
      },
      analysesMap: {
        '2330': DailyAnalysisEntry(
          symbol: '2330',
          date: defaultDate,
          score: 80.0,
          trendState: 'UP',
          reversalState: '',
          computedAt: defaultDate,
        ),
        '2317': DailyAnalysisEntry(
          symbol: '2317',
          date: defaultDate,
          score: 55.0,
          trendState: 'DOWN',
          reversalState: '',
          computedAt: defaultDate,
        ),
      },
      valuationsMap: {
        '2330': StockValuationEntry(
          symbol: '2330',
          date: defaultDate,
          per: 15.0,
          dividendYield: 2.5,
        ),
      },
      summariesMap: {
        '2330': const StockSummary(
          overallAssessment: 'Bullish',
          sentiment: SummarySentiment.bullish,
        ),
        '2317': const StockSummary(
          overallAssessment: 'Bearish',
          sentiment: SummarySentiment.bearish,
        ),
      },
    );
  }

  group('ShareableComparisonCard', () {
    testWidgets('displays AfterClose brand', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableComparisonCard(state: state)),
      );

      expect(find.text('AfterClose'), findsOneWidget);
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('shows stock rows with symbol and name', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableComparisonCard(state: state)),
      );

      expect(find.textContaining('2330'), findsAtLeastNWidgets(1));
      expect(find.textContaining('台積電'), findsAtLeastNWidgets(1));
      expect(find.textContaining('2317'), findsAtLeastNWidgets(1));
      expect(find.textContaining('鴻海'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows close prices', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableComparisonCard(state: state)),
      );

      expect(find.text('600.00'), findsOneWidget);
      expect(find.text('100.00'), findsOneWidget);
    });

    testWidgets('shows score and trend tags', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableComparisonCard(state: state)),
      );

      expect(find.textContaining('80'), findsAtLeastNWidgets(1));
      expect(find.text('UP'), findsOneWidget);
      expect(find.text('DOWN'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(
          ShareableComparisonCard(state: state),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('AfterClose'), findsOneWidget);
    });
  });
}
