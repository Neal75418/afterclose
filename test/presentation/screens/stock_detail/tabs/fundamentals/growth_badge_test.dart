import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  group('buildGrowthBadge', () {
    testWidgets('shows dash when growth is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, null)),
        ),
      );

      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('shows positive growth with plus sign', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, 5.3)),
        ),
      );

      expect(find.text('+5.3%'), findsOneWidget);
    });

    testWidgets('shows negative growth with minus sign', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, -2.7)),
        ),
      );

      expect(find.text('-2.7%'), findsOneWidget);
    });

    testWidgets('shows zero growth with plus sign', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, 0.0)),
        ),
      );

      expect(find.text('+0.0%'), findsOneWidget);
    });

    testWidgets('significant positive growth (>=10%) has bold text', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, 15.0)),
        ),
      );

      final text = tester.widget<Text>(find.text('+15.0%'));
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('non-significant growth (<10%) has w500 weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, 5.0)),
        ),
      );

      final text = tester.widget<Text>(find.text('+5.0%'));
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('significant negative growth has bold text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, -12.5)),
        ),
      );

      final text = tester.widget<Text>(find.text('-12.5%'));
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildGrowthBadge(context, 8.5)),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('+8.5%'), findsOneWidget);
    });
  });
}
