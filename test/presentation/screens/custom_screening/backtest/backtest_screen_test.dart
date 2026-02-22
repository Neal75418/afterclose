import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/backtest_provider.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/backtest_screen.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/backtest_summary_card.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/return_distribution_chart.dart';

import '../../../../helpers/provider_test_helpers.dart';
import '../../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeBacktestNotifier extends BacktestNotifier {
  BacktestState initialState = const BacktestState();

  @override
  BacktestState build() => initialState;

  @override
  void updatePeriod(int months) {}

  @override
  void updateHoldingDays(int days) {}

  @override
  void updateSamplingInterval(int interval) {}

  @override
  Future<void> executeBacktest(List<ScreeningCondition> conditions) async {}

  @override
  void clearResults() {}
}

// =============================================================================
// Test Helpers
// =============================================================================

const _testConditions = [
  ScreeningCondition(
    field: ScreeningField.close,
    operator: ScreeningOperator.greaterThan,
    value: 100.0,
  ),
];

BacktestResult createTestResult({
  List<BacktestTrade>? trades,
  int tradingDaysScanned = 60,
  Duration executionTime = const Duration(seconds: 2),
  int skippedTrades = 0,
}) {
  final tradeList =
      trades ??
      [
        BacktestTrade(
          symbol: '2330',
          entryDate: _defaultDate,
          entryPrice: 500.0,
          exitDate: _defaultExitDate,
          exitPrice: 525.0,
          holdingDays: 5,
          returnPercent: 5.0,
        ),
        BacktestTrade(
          symbol: '2317',
          entryDate: _defaultDate,
          entryPrice: 100.0,
          exitDate: _defaultExitDate,
          exitPrice: 95.0,
          holdingDays: 5,
          returnPercent: -5.0,
        ),
      ];

  return BacktestResult(
    config: const BacktestConfig(periodMonths: 3, holdingDays: 5),
    trades: tradeList,
    summary: BacktestSummary.fromTrades(tradeList),
    executionTime: executionTime,
    tradingDaysScanned: tradingDaysScanned,
    skippedTrades: skippedTrades,
  );
}

final _defaultDate = DateTime(2026, 1, 15);
final _defaultExitDate = DateTime(2026, 1, 22);

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

  late BacktestState _backtestState;

  Widget buildTestWidget({
    BacktestState? backtestState,
    Brightness brightness = Brightness.light,
  }) {
    _backtestState = backtestState ?? const BacktestState();
    return buildProviderTestApp(
      const BacktestScreen(conditions: _testConditions),
      overrides: [
        backtestProvider.overrideWith(() {
          final n = FakeBacktestNotifier();
          n.initialState = _backtestState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('BacktestScreen', () {
    testWidgets('shows AppBar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows period segmented button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SegmentedButton<int>), findsNWidgets(2));
    });

    testWidgets('shows holding days slider', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows execute button with icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('shows progress when executing', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: const BacktestState(
            isExecuting: true,
            progress: 0.5,
            progressCurrent: 30,
            progressTotal: 60,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: const BacktestState(error: 'Test error'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test error'), findsOneWidget);
    });

    testWidgets('shows results with summary card', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: BacktestState(result: createTestResult()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BacktestSummaryCard), findsOneWidget);
    });

    testWidgets('shows results with distribution chart', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: BacktestState(result: createTestResult()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ReturnDistributionChart), findsOneWidget);
    });

    testWidgets('shows warning disclaimer when results present', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: BacktestState(result: createTestResult()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('shows no results message for empty trades', (tester) async {
      widenViewport(tester);
      final emptyResult = BacktestResult(
        config: const BacktestConfig(periodMonths: 3, holdingDays: 5),
        trades: const [],
        summary: BacktestSummary.fromTrades(const []),
        executionTime: const Duration(seconds: 1),
        tradingDaysScanned: 60,
      );
      await tester.pumpWidget(
        buildTestWidget(backtestState: BacktestState(result: emptyResult)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Empty result shows "no results" text, no summary card
      expect(find.byType(BacktestSummaryCard), findsNothing);
    });

    testWidgets('shows spinner instead of icon when executing', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(backtestState: const BacktestState(isExecuting: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      // When executing, the analytics icon is replaced by a spinner
      expect(find.byIcon(Icons.analytics_outlined), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          backtestState: BacktestState(result: createTestResult()),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BacktestScreen), findsOneWidget);
    });
  });
}
