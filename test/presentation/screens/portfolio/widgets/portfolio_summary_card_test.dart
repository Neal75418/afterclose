import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/portfolio_summary_card.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  PortfolioSummary createSummary({
    double totalMarketValue = 1000000,
    double totalCostBasis = 900000,
    double totalUnrealizedPnl = 80000,
    double totalRealizedPnl = 10000,
    double totalDividends = 5000,
    int positionCount = 5,
  }) {
    return PortfolioSummary(
      totalMarketValue: totalMarketValue,
      totalCostBasis: totalCostBasis,
      totalUnrealizedPnl: totalUnrealizedPnl,
      totalRealizedPnl: totalRealizedPnl,
      totalDividends: totalDividends,
      positionCount: positionCount,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('PortfolioSummaryCard', () {
    testWidgets('displays market value with NT\$ prefix', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(PortfolioSummaryCard(summary: createSummary())),
      );

      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
      // Should contain NT$ somewhere in the text
      expect(find.textContaining('NT\$'), findsWidgets);
    });

    testWidgets('renders with positive PnL', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PortfolioSummaryCard(
            summary: createSummary(
              totalUnrealizedPnl: 50000,
              totalRealizedPnl: 10000,
              totalDividends: 5000,
            ),
          ),
        ),
      );

      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
      // totalPnl = 50000 + 10000 + 5000 = 65000 (positive → has +)
      expect(find.textContaining('+'), findsWidgets);
    });

    testWidgets('renders with negative PnL', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PortfolioSummaryCard(
            summary: createSummary(
              totalUnrealizedPnl: -100000,
              totalRealizedPnl: 0,
              totalDividends: 0,
            ),
          ),
        ),
      );

      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
    });

    testWidgets('renders with zero PnL', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(PortfolioSummaryCard(summary: PortfolioSummary.empty)),
      );

      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PortfolioSummaryCard(summary: createSummary()),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
    });
  });
}
