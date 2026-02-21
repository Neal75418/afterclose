import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_state.dart';
import 'package:afterclose/presentation/widgets/shareable/shareable_analysis_card.dart';

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

  StockDetailState createState({
    String symbol = '2330',
    String name = '台積電',
    double close = 600.0,
    double score = 75.0,
    String trend = 'BULLISH',
    String reversal = 'NONE',
    StockSummary? summary,
    List<DailyReasonEntry>? reasons,
  }) {
    return StockDetailState(
      price: StockPriceState(
        stock: StockMasterEntry(
          symbol: symbol,
          name: name,
          market: 'TWSE',
          isActive: true,
          updatedAt: defaultDate,
        ),
        latestPrice: DailyPriceEntry(
          symbol: symbol,
          date: defaultDate,
          open: close * 0.99,
          high: close * 1.02,
          low: close * 0.98,
          close: close,
          volume: 50000,
        ),
        analysis: DailyAnalysisEntry(
          symbol: symbol,
          date: defaultDate,
          score: score,
          trendState: trend,
          reversalState: reversal,
          computedAt: defaultDate,
        ),
      ),
      aiSummary: summary,
      reasons: reasons ?? const [],
    );
  }

  group('ShareableAnalysisCard', () {
    testWidgets('displays AfterClose brand', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.text('AfterClose'), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('displays stock name and symbol', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.textContaining('2330'), findsOneWidget);
      expect(find.textContaining('台積電'), findsOneWidget);
    });

    testWidgets('displays close price', (tester) async {
      widenViewport(tester);
      final state = createState(close: 600.0);

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.text('600.00'), findsOneWidget);
    });

    testWidgets('displays score badge', (tester) async {
      widenViewport(tester);
      final state = createState(score: 82.0);

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.textContaining('82'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows AI summary when available', (tester) async {
      widenViewport(tester);
      final state = createState(
        summary: const StockSummary(
          overallAssessment: '多頭趨勢明顯，建議持有',
          keySignals: ['黃金交叉', '外資連續買超'],
          riskFactors: ['RSI 偏高'],
          sentiment: SummarySentiment.bullish,
        ),
      );

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.text('多頭趨勢明顯，建議持有'), findsOneWidget);
      expect(find.text('黃金交叉'), findsOneWidget);
    });

    testWidgets('shows reason tags when no AI summary', (tester) async {
      widenViewport(tester);
      final state = createState(
        reasons: [
          DailyReasonEntry(
            symbol: '2330',
            date: defaultDate,
            rank: 1,
            reasonType: 'GOLDEN_CROSS',
            evidenceJson: '{}',
            ruleScore: 10.0,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      // Should show key signals section
      expect(find.byIcon(Icons.trending_up), findsAtLeastNWidgets(1));
    });

    testWidgets('shows reversal chip when not NONE', (tester) async {
      widenViewport(tester);
      final state = createState(reversal: 'W2S');

      await tester.pumpWidget(
        buildTestApp(ShareableAnalysisCard(state: state)),
      );

      expect(find.text('W2S'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(
          ShareableAnalysisCard(state: state),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('AfterClose'), findsOneWidget);
    });
  });
}
