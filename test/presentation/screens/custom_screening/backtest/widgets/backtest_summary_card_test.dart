import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/backtest_summary_card.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  BacktestSummary createSummary({
    int totalTrades = 100,
    int winningTrades = 60,
    int losingTrades = 40,
    double avgReturn = 1.5,
    double medianReturn = 1.2,
    double maxReturn = 15.0,
    double minReturn = -8.0,
    double stdDeviation = 3.5,
    double winRate = 0.6,
    double? sharpeRatio = 0.43,
  }) {
    return BacktestSummary(
      totalTrades: totalTrades,
      winningTrades: winningTrades,
      losingTrades: losingTrades,
      avgReturn: avgReturn,
      medianReturn: medianReturn,
      maxReturn: maxReturn,
      minReturn: minReturn,
      stdDeviation: stdDeviation,
      winRate: winRate,
      sharpeRatio: sharpeRatio,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('BacktestSummaryCard', () {
    testWidgets('displays total trades count', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(totalTrades: 100),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('displays win rate with color', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(winRate: 0.65),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('65.0%'), findsOneWidget);
    });

    testWidgets('displays formatted avg return with sign', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(avgReturn: 1.5),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('+1.50%'), findsOneWidget);
    });

    testWidgets('displays sharpe ratio', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(sharpeRatio: 0.43),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('0.43'), findsOneWidget);
    });

    testWidgets('shows dash when sharpe ratio is null', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(sharpeRatio: null),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('displays negative returns', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(
              avgReturn: -2.0,
              minReturn: -15.0,
              maxReturn: 5.0,
              medianReturn: -1.5,
            ),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
        ),
      );

      expect(find.text('-2.00%'), findsOneWidget);
      expect(find.text('-15.00%'), findsOneWidget);
    });

    testWidgets('shows skipped trades when > 0', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
            skippedTrades: 5,
          ),
        ),
      );

      expect(find.byType(BacktestSummaryCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          BacktestSummaryCard(
            summary: createSummary(),
            tradingDaysScanned: 250,
            executionTime: const Duration(milliseconds: 1500),
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(BacktestSummaryCard), findsOneWidget);
    });
  });
}
