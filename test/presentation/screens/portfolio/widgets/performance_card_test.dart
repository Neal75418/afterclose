import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/performance_card.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  PortfolioPerformance createPerformance({
    double totalReturn = 12.5,
    double maxDrawdown = 3.2,
    PeriodReturns? periodReturns,
  }) {
    return PortfolioPerformance(
      totalReturn: totalReturn,
      totalMarketValue: 1000000,
      totalCostBasis: 900000,
      totalDividends: 5000,
      totalRealizedPnl: 10000,
      periodReturns:
          periodReturns ??
          const PeriodReturns(
            daily: 0.5,
            weekly: 2.1,
            monthly: 8.3,
            yearly: 15.0,
          ),
      maxDrawdown: maxDrawdown,
      industryAllocation: const {},
    );
  }

  group('PerformanceCard', () {
    // Widen viewport: untranslated i18n keys are long strings that overflow
    // the default 800px test surface.
    void widenViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('displays analytics icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(PerformanceCard(performance: createPerformance())),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('displays period return values', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PerformanceCard(
            performance: createPerformance(
              periodReturns: const PeriodReturns(
                daily: 0.5,
                weekly: 2.1,
                monthly: 8.3,
                yearly: 15.0,
              ),
            ),
          ),
        ),
      );

      // daily: +0.50%
      expect(find.text('+0.50%'), findsOneWidget);
      // weekly: +2.10%
      expect(find.text('+2.10%'), findsOneWidget);
      // monthly: +8.30%
      expect(find.text('+8.30%'), findsOneWidget);
      // yearly: +15.00%
      expect(find.text('+15.00%'), findsOneWidget);
    });

    testWidgets('displays negative returns without + prefix', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PerformanceCard(
            performance: createPerformance(
              periodReturns: const PeriodReturns(
                daily: -0.8,
                weekly: -3.5,
                monthly: -10.2,
                yearly: -25.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('-0.80%'), findsOneWidget);
      expect(find.text('-3.50%'), findsOneWidget);
    });

    testWidgets('displays total return', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PerformanceCard(performance: createPerformance(totalReturn: 12.5)),
        ),
      );

      expect(find.text('+12.50%'), findsOneWidget);
    });

    testWidgets('shows info icon for annualized yearly return', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(PerformanceCard(performance: createPerformance())),
      );

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders with empty performance', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const PerformanceCard(performance: PortfolioPerformance.empty),
        ),
      );

      expect(find.byType(PerformanceCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          PerformanceCard(performance: createPerformance()),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(PerformanceCard), findsOneWidget);
    });
  });
}
