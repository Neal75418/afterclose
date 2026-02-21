import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/margin_compact_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('MarginCompactRow', () {
    testWidgets('returns empty when both changes are 0', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const MarginCompactRow(data: MarginTradingTotals())),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('displays when marginChange is non-zero', (tester) async {
      const data = MarginTradingTotals(marginChange: 500, marginBalance: 50000);
      await tester.pumpWidget(buildTestApp(const MarginCompactRow(data: data)));

      expect(find.byType(MarginCompactRow), findsOneWidget);
      // Up arrow for positive change
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('shows down arrow for negative change', (tester) async {
      const data = MarginTradingTotals(
        marginChange: -200,
        marginBalance: 30000,
        shortChange: 100,
        shortBalance: 5000,
      );
      await tester.pumpWidget(buildTestApp(const MarginCompactRow(data: data)));

      // Both arrows should show: down for margin, up for short
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      const data = MarginTradingTotals(marginChange: 100);
      await tester.pumpWidget(
        buildTestApp(
          const MarginCompactRow(data: data),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(MarginCompactRow), findsOneWidget);
    });
  });
}
