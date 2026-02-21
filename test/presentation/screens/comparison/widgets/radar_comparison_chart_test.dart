import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/radar_comparison_chart.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  final defaultDate = DateTime(2026, 2, 13);

  ComparisonState createState({int symbolCount = 2}) {
    final symbols = ['2330', '2317', '2454', '2412'].take(symbolCount).toList();
    final analysesMap = <String, DailyAnalysisEntry>{};
    final summariesMap = <String, StockSummary>{};

    for (final s in symbols) {
      analysesMap[s] = DailyAnalysisEntry(
        symbol: s,
        date: defaultDate,
        score: 70.0,
        trendState: 'BULLISH',
        reversalState: '',
        computedAt: defaultDate,
      );
      summariesMap[s] = const StockSummary(
        overallAssessment: 'Test',
        sentiment: SummarySentiment.bullish,
      );
    }

    return ComparisonState(
      symbols: symbols,
      analysesMap: analysesMap,
      summariesMap: summariesMap,
    );
  }

  group('RadarComparisonChart', () {
    testWidgets('returns SizedBox.shrink when less than 2 symbols', (
      tester,
    ) async {
      widenViewport(tester);
      final state = createState(symbolCount: 1);

      await tester.pumpWidget(buildTestApp(RadarComparisonChart(state: state)));

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders radar chart with 2 stocks', (tester) async {
      widenViewport(tester);
      final state = createState(symbolCount: 2);

      await tester.pumpWidget(buildTestApp(RadarComparisonChart(state: state)));

      // Should show the radar title
      expect(find.textContaining('comparison.radarTitle'), findsOneWidget);
    });

    testWidgets('renders with 4 stocks', (tester) async {
      widenViewport(tester);
      final state = createState(symbolCount: 4);

      await tester.pumpWidget(buildTestApp(RadarComparisonChart(state: state)));

      expect(find.textContaining('comparison.radarTitle'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(
          RadarComparisonChart(state: state),
          brightness: Brightness.dark,
        ),
      );

      expect(find.textContaining('comparison.radarTitle'), findsOneWidget);
    });
  });
}
