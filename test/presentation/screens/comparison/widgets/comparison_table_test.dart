import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_table.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget scrollable(Widget child) {
    return SingleChildScrollView(child: child);
  }

  final defaultDate = DateTime(2026, 2, 13);

  DailyPriceEntry createPrice(String symbol, double close, {DateTime? date}) {
    final d = date ?? defaultDate;
    return DailyPriceEntry(
      symbol: symbol,
      date: d,
      open: close * 0.99,
      high: close * 1.02,
      low: close * 0.98,
      close: close,
      volume: 50000,
    );
  }

  DailyAnalysisEntry createAnalysis(
    String symbol, {
    double score = 75.0,
    String trend = 'BULLISH',
  }) {
    return DailyAnalysisEntry(
      symbol: symbol,
      date: defaultDate,
      score: score,
      trendState: trend,
      reversalState: '',
      computedAt: defaultDate,
    );
  }

  StockValuationEntry createValuation(
    String symbol, {
    double? per,
    double? pbr,
    double? dividendYield,
  }) {
    return StockValuationEntry(
      symbol: symbol,
      date: defaultDate,
      per: per,
      pbr: pbr,
      dividendYield: dividendYield,
    );
  }

  ComparisonState createTwoStockState({
    double score1 = 80,
    double score2 = 60,
  }) {
    return ComparisonState(
      symbols: const ['2330', '2317'],
      analysesMap: {
        '2330': createAnalysis('2330', score: score1),
        '2317': createAnalysis('2317', score: score2),
      },
      latestPricesMap: {
        '2330': createPrice('2330', 600),
        '2317': createPrice('2317', 100),
      },
      priceHistoriesMap: {
        '2330': [
          createPrice(
            '2330',
            580,
            date: defaultDate.subtract(const Duration(days: 1)),
          ),
          createPrice('2330', 600),
        ],
        '2317': [
          createPrice(
            '2317',
            105,
            date: defaultDate.subtract(const Duration(days: 1)),
          ),
          createPrice('2317', 100),
        ],
      },
      valuationsMap: {
        '2330': createValuation(
          '2330',
          per: 15.0,
          pbr: 3.0,
          dividendYield: 2.5,
        ),
        '2317': createValuation(
          '2317',
          per: 10.0,
          pbr: 1.5,
          dividendYield: 4.0,
        ),
      },
      summariesMap: {
        '2330': const StockSummary(
          overallAssessment: 'Bullish',
          sentiment: SummarySentiment.bullish,
        ),
        '2317': const StockSummary(
          overallAssessment: 'Neutral',
          sentiment: SummarySentiment.neutral,
        ),
      },
    );
  }

  group('ComparisonTable', () {
    testWidgets('returns SizedBox.shrink when less than 2 symbols', (
      tester,
    ) async {
      widenViewport(tester);
      const state = ComparisonState(symbols: ['2330']);

      await tester.pumpWidget(
        buildTestApp(const ComparisonTable(state: state)),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
    });

    testWidgets('renders 6 section headers with valid comparison state', (
      tester,
    ) async {
      widenViewport(tester);
      final state = createTwoStockState();

      await tester.pumpWidget(
        buildTestApp(scrollable(ComparisonTable(state: state))),
      );

      // 6 section icons
      expect(find.byIcon(Icons.trending_up), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.candlestick_chart), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('displays verdict banner with trophy icon', (tester) async {
      widenViewport(tester);
      final state = createTwoStockState();

      await tester.pumpWidget(
        buildTestApp(scrollable(ComparisonTable(state: state))),
      );

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('shows score values in metric rows', (tester) async {
      widenViewport(tester);
      final state = createTwoStockState(score1: 85, score2: 45);

      await tester.pumpWidget(
        buildTestApp(scrollable(ComparisonTable(state: state))),
      );

      expect(find.text('85'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('shows valuation metrics', (tester) async {
      widenViewport(tester);
      final state = createTwoStockState();

      await tester.pumpWidget(
        buildTestApp(scrollable(ComparisonTable(state: state))),
      );

      expect(find.text('15.0'), findsOneWidget);
      expect(find.text('10.0'), findsOneWidget);
      expect(find.text('2.5%'), findsOneWidget);
      expect(find.text('4.0%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createTwoStockState();

      await tester.pumpWidget(
        buildTestApp(
          scrollable(ComparisonTable(state: state)),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });
  });
}
