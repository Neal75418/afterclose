import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_header.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  StockMasterEntry createStock(String symbol, String name) {
    return StockMasterEntry(
      symbol: symbol,
      name: name,
      market: 'TWSE',
      isActive: true,
      updatedAt: DateTime(2026, 2, 15),
    );
  }

  group('ComparisonHeader', () {
    testWidgets('displays stock chips for each symbol', (tester) async {
      final stocksMap = {
        '2330': createStock('2330', '台積電'),
        '2317': createStock('2317', '鴻海'),
      };
      await tester.pumpWidget(
        buildTestApp(
          ComparisonHeader(
            symbols: const ['2330', '2317'],
            stocksMap: stocksMap,
            canAddMore: false,
            onRemove: (_) {},
            onAdd: () {},
          ),
        ),
      );

      expect(find.textContaining('2330'), findsOneWidget);
      expect(find.textContaining('2317'), findsOneWidget);
    });

    testWidgets('shows add button when canAddMore is true', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ComparisonHeader(
            symbols: const ['2330'],
            stocksMap: {'2330': createStock('2330', '台積電')},
            canAddMore: true,
            onRemove: (_) {},
            onAdd: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('hides add button when canAddMore is false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ComparisonHeader(
            symbols: const ['2330'],
            stocksMap: {'2330': createStock('2330', '台積電')},
            canAddMore: false,
            onRemove: (_) {},
            onAdd: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('calls onRemove when delete icon tapped', (tester) async {
      String? removedSymbol;
      await tester.pumpWidget(
        buildTestApp(
          ComparisonHeader(
            symbols: const ['2330'],
            stocksMap: {'2330': createStock('2330', '台積電')},
            canAddMore: false,
            onRemove: (s) => removedSymbol = s,
            onAdd: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(removedSymbol, '2330');
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ComparisonHeader(
            symbols: const ['2330'],
            stocksMap: {'2330': createStock('2330', '台積電')},
            canAddMore: true,
            onRemove: (_) {},
            onAdd: () {},
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ComparisonHeader), findsOneWidget);
    });
  });
}
