import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/stock_card_price.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('StockCardPriceSection', () {
    testWidgets('displays closing price', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 150.50,
            priceColor: Colors.green,
          ),
        ),
      );

      expect(find.text('150.50'), findsOneWidget);
    });

    testWidgets('displays positive price change with sign', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 150.00,
            priceChange: 2.50,
            priceColor: Colors.green,
          ),
        ),
      );

      // Should show formatted change text
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    });

    testWidgets('displays negative price change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 100.00,
            priceChange: -3.00,
            priceColor: Colors.red,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('does not show arrow icons for zero change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 100.00,
            priceChange: 0,
            priceColor: Colors.grey,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('hides price text when latestClose is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const StockCardPriceSection(priceColor: Colors.grey)),
      );

      // Column should have no Text children with price format
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders in compact mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 50.00,
            priceChange: 1.50,
            priceColor: Colors.green,
            compact: true,
          ),
        ),
      );

      expect(find.text('50.00'), findsOneWidget);
    });

    testWidgets('shows limit-up marker for 10% change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 110.00,
            priceChange: 10.0,
            priceColor: Colors.red,
            showLimitMarkers: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('shows limit-down marker for -10% change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 90.00,
            priceChange: -10.0,
            priceColor: Colors.green,
            showLimitMarkers: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('hides limit markers when showLimitMarkers is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 110.00,
            priceChange: 10.0,
            priceColor: Colors.red,
            showLimitMarkers: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCardPriceSection(
            latestClose: 100.00,
            priceChange: 1.5,
            priceColor: Colors.green,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('100.00'), findsOneWidget);
    });
  });
}
