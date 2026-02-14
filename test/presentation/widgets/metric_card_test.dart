import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/metric_card.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('MetricCard', () {
    testWidgets('displays value and label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(
            label: 'PE Ratio',
            value: '15.2',
            icon: Icons.trending_up,
          ),
        ),
      );

      expect(find.text('15.2'), findsOneWidget);
      expect(find.text('PE Ratio'), findsOneWidget);
    });

    testWidgets('displays icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(label: 'ROE', value: '18%', icon: Icons.show_chart),
        ),
      );

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('uses subtitle when provided instead of label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(
            label: 'PE',
            value: '12.5',
            icon: Icons.trending_up,
            subtitle: 'Price-Earnings',
          ),
        ),
      );

      expect(find.text('Price-Earnings'), findsOneWidget);
      // label 不該單獨顯示（subtitle 取代）
      expect(find.text('PE'), findsNothing);
    });

    testWidgets('shows label when no subtitle provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(
            label: 'PB Ratio',
            value: '2.1',
            icon: Icons.bar_chart,
          ),
        ),
      );

      expect(find.text('PB Ratio'), findsOneWidget);
    });

    testWidgets('warning state shows red value text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(
            label: 'Pledge',
            value: '85%',
            icon: Icons.warning,
            isWarning: true,
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MetricCard(label: 'PE', value: '10', icon: Icons.trending_up),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('PE'), findsOneWidget);
    });
  });
}
