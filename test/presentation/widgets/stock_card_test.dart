import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/stock_card.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('StockCard', () {
    testWidgets('displays symbol', (tester) async {
      await tester.pumpWidget(buildTestApp(const StockCard(symbol: '2330')));

      expect(find.text('2330'), findsOneWidget);
    });

    testWidgets('displays stock name when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', stockName: '台積電')),
      );

      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('hides stock name when null', (tester) async {
      await tester.pumpWidget(buildTestApp(const StockCard(symbol: '2330')));

      // Only symbol text should be present
      expect(find.text('2330'), findsOneWidget);
    });

    testWidgets('displays TPEx market label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(symbol: '6488', stockName: '環球晶', market: 'TPEx'),
        ),
      );

      expect(find.text('櫃'), findsOneWidget);
    });

    testWidgets('does not display market label for TWSE', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(symbol: '2330', stockName: '台積電', market: 'TWSE'),
        ),
      );

      expect(find.text('櫃'), findsNothing);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestApp(StockCard(symbol: '2330', onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, true);
    });

    testWidgets('calls onLongPress callback', (tester) async {
      var longPressed = false;
      await tester.pumpWidget(
        buildTestApp(
          StockCard(symbol: '2330', onLongPress: () => longPressed = true),
        ),
      );

      await tester.longPress(find.byType(InkWell));
      expect(longPressed, true);
    });

    testWidgets('shows watchlist button when onWatchlistTap provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(StockCard(symbol: '2330', onWatchlistTap: () {})),
      );

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('shows filled star when in watchlist', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          StockCard(symbol: '2330', isInWatchlist: true, onWatchlistTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('calls onWatchlistTap when star tapped', (tester) async {
      var watchlistTapped = false;
      await tester.pumpWidget(
        buildTestApp(
          StockCard(
            symbol: '2330',
            onWatchlistTap: () => watchlistTapped = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.star_outline_rounded));
      expect(watchlistTapped, true);
    });

    testWidgets('hides watchlist button when onWatchlistTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const StockCard(symbol: '2330')));

      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('shows trend icon for UP state', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', trendState: 'UP')),
      );

      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('shows trend icon for DOWN state', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', trendState: 'DOWN')),
      );

      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });

    testWidgets('shows flat trend icon for null state', (tester) async {
      await tester.pumpWidget(buildTestApp(const StockCard(symbol: '2330')));

      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            stockName: '台積電',
            latestClose: 850.0,
            priceChange: 2.5,
            score: 85,
            trendState: 'UP',
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(StockCard), findsOneWidget);
    });
  });
}
