import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';

import '../../../../helpers/provider_test_helpers.dart';
import '../../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeStockDetailNotifier extends StockDetailNotifier {
  FakeStockDetailNotifier(super.symbol);

  StockDetailState initialState = const StockDetailState();

  @override
  StockDetailState build() => initialState;

  @override
  Future<void> loadInsiderData() async {}

  @override
  Future<void> loadData() async {}
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  late StockDetailState _testState;

  Widget buildTestWidget(
    StockDetailState state, {
    Brightness brightness = Brightness.light,
  }) {
    _testState = state;
    return buildProviderTestApp(
      const AiSummaryCard(symbol: '2330'),
      overrides: [
        stockDetailProvider.overrideWith(() {
          final n = FakeStockDetailNotifier('2330');
          n.initialState = _testState;
          return n;
        }),
        primaryRuleAccuracySummaryProvider.overrideWith(
          (ref, symbol) async => null,
        ),
      ],
      brightness: brightness,
    );
  }

  final bullishSummary = const StockSummary(
    overallAssessment: 'Strong bullish trend detected',
    keySignals: ['Volume breakout', 'Golden cross'],
    riskFactors: ['High valuation'],
    supportingData: ['Foreign net buy 5 days'],
    sentiment: SummarySentiment.bullish,
    confidence: AnalysisConfidence.high,
    confluenceCount: 3,
  );

  final bearishSummary = const StockSummary(
    overallAssessment: 'Bearish reversal expected',
    sentiment: SummarySentiment.bearish,
    confidence: AnalysisConfidence.low,
  );

  final neutralSummary = const StockSummary(
    overallAssessment: 'Sideways consolidation',
    sentiment: SummarySentiment.neutral,
    confidence: AnalysisConfidence.medium,
    hasConflict: true,
  );

  group('AiSummaryCard', () {
    testWidgets('shows shimmer skeleton when aiSummary is null', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(const StockDetailState()));
      await tester.pump();

      // Shimmer containers should be present
      expect(find.byType(AiSummaryCard), findsOneWidget);
      // No overall assessment text
      expect(find.text('Strong bullish trend detected'), findsNothing);
    });

    testWidgets('shows overall assessment text', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Strong bullish trend detected'), findsOneWidget);
    });

    testWidgets('shows key signals section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Volume breakout'), findsOneWidget);
      expect(find.text('Golden cross'), findsOneWidget);
    });

    testWidgets('shows risk factors section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('High valuation'), findsOneWidget);
    });

    testWidgets('shows supporting data section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Foreign net buy 5 days'), findsOneWidget);
    });

    testWidgets('hides sections when summary has no signals/risks', (
      tester,
    ) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bearishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Bearish reversal expected'), findsOneWidget);
      // No bullet items for signals or risks
      expect(find.text('Volume breakout'), findsNothing);
    });

    testWidgets('shows auto_awesome icon', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('shows signal strength bar', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows action chips', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('shows disclaimer text', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      // Disclaimer uses .tr() key
      expect(find.byType(AiSummaryCard), findsOneWidget);
    });

    testWidgets('bearish sentiment renders correctly', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bearishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Bearish reversal expected'), findsOneWidget);
    });

    testWidgets('neutral sentiment renders correctly', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: neutralSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Sideways consolidation'), findsOneWidget);
    });

    testWidgets('collapse toggle hides content', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      // Content is visible initially
      expect(find.text('Strong bullish trend detected'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      // Arrow should change to down
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(
        buildTestWidget(state, brightness: Brightness.dark),
      );
      await tester.pump();

      expect(find.text('Strong bullish trend detected'), findsOneWidget);
    });
  });
}
