import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/watchlist_types.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_stock_item.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';

import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Test Helpers
// =============================================================================

WatchlistItemData createItem({
  String symbol = '2330',
  String? stockName = '台積電',
  String? market = 'TWSE',
  double? latestClose = 600.0,
  double? priceChange = 10.0,
  double? score = 80.0,
  String? trendState = 'UP',
  List<double> recentPrices = const [590.0, 595.0, 600.0],
  List<String> reasons = const [],
  WarningBadgeType? warningType,
  bool hasSignal = false,
}) {
  return WatchlistItemData(
    symbol: symbol,
    stockName: stockName,
    market: market,
    latestClose: latestClose,
    priceChange: priceChange,
    score: score,
    trendState: trendState,
    recentPrices: recentPrices,
    reasons: reasons,
    warningType: warningType,
    hasSignal: hasSignal,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('WatchlistStockItem', () {
    testWidgets('renders StockCard with item data', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockItem(
            item: item,
            index: 0,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });

    testWidgets('renders without animation for index >= 10', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockItem(
            item: item,
            index: 15,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });

    testWidgets('calls onView callback on tap', (tester) async {
      widenViewport(tester);
      var viewCalled = false;
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockItem(
            item: item,
            index: 15,
            showLimitMarkers: false,
            onView: () => viewCalled = true,
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(StockCard));
      await tester.pump();
      expect(viewCalled, isTrue);
    });

    testWidgets('renders with warning badge type', (tester) async {
      widenViewport(tester);
      final item = createItem(warningType: WarningBadgeType.attention);

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockItem(
            item: item,
            index: 15,
            showLimitMarkers: true,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockItem(
            item: item,
            index: 15,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });
  });

  group('WatchlistStockGridItem', () {
    testWidgets('renders StockCard', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockGridItem(
            item: item,
            index: 0,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });

    testWidgets('renders without animation for index >= 20', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockGridItem(
            item: item,
            index: 25,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });

    testWidgets('calls onView on tap', (tester) async {
      widenViewport(tester);
      var viewCalled = false;
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockGridItem(
            item: item,
            index: 25,
            showLimitMarkers: false,
            onView: () => viewCalled = true,
            onRemove: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(StockCard));
      await tester.pump();
      expect(viewCalled, isTrue);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final item = createItem();

      await tester.pumpWidget(
        buildTestApp(
          WatchlistStockGridItem(
            item: item,
            index: 25,
            showLimitMarkers: false,
            onView: () {},
            onRemove: () {},
            onLongPress: () {},
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockCard), findsOneWidget);
    });
  });
}
