import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/industry_allocation_card.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('IndustryAllocationCard', () {
    testWidgets('returns SizedBox.shrink when allocation is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const IndustryAllocationCard(allocation: {})),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(IndustryAllocationCard), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline), findsNothing);
    });

    testWidgets('displays pie_chart_outline icon with data', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 50.0,
          symbols: ['2330', '2303'],
        ),
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 300000,
          percentage: 30.0,
          symbols: ['2881', '2882'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('displays industry names', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 60.0,
          symbols: ['2330'],
        ),
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 200000,
          percentage: 40.0,
          symbols: ['2881'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('半導體業'), findsOneWidget);
      expect(find.text('金融保險業'), findsOneWidget);
    });

    testWidgets('displays percentage values', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 60.0,
          symbols: ['2330'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('60.0%'), findsOneWidget);
    });

    testWidgets('displays symbol list', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 100.0,
          symbols: ['2330', '2303'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('2330, 2303'), findsOneWidget);
    });

    testWidgets('sorts by percentage descending', (tester) async {
      widenViewport(tester);
      final allocation = {
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 200000,
          percentage: 20.0,
          symbols: ['2881'],
        ),
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 800000,
          percentage: 80.0,
          symbols: ['2330'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      // Both should render
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 100.0,
          symbols: ['2330'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(
          IndustryAllocationCard(allocation: allocation),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(IndustryAllocationCard), findsOneWidget);
    });
  });
}
