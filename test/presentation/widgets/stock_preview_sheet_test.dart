import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  StockPreviewData createData({
    String symbol = '2330',
    String? stockName = '台積電',
    double? latestClose = 850.00,
    double? priceChange = 2.50,
    double? score,
    String? trendState = 'UP',
    List<String> reasons = const [],
    bool isInWatchlist = false,
  }) {
    return StockPreviewData(
      symbol: symbol,
      stockName: stockName,
      latestClose: latestClose,
      priceChange: priceChange,
      score: score,
      trendState: trendState,
      reasons: reasons,
      isInWatchlist: isInWatchlist,
    );
  }

  group('StockPreviewSheet', () {
    testWidgets('displays symbol', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData())),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2330'), findsOneWidget);
    });

    testWidgets('displays stock name', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData())),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('displays formatted price', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(latestClose: 850.00))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('850.00'), findsOneWidget);
    });

    testWidgets('shows positive change with + prefix', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(priceChange: 2.50))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('+2.50%'), findsOneWidget);
    });

    testWidgets('shows negative change without + prefix', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(priceChange: -1.80))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('-1.80%'), findsOneWidget);
    });

    testWidgets('shows up arrow for positive change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(priceChange: 2.50))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    });

    testWidgets('shows down arrow for negative change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(priceChange: -1.80))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('shows watchlist star when in watchlist', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(isInWatchlist: true))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('shows outline star when not in watchlist', (tester) async {
      await tester.pumpWidget(
        buildTestApp(StockPreviewSheet(data: createData(isInWatchlist: false))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          StockPreviewSheet(data: createData()),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockPreviewSheet), findsOneWidget);
    });
  });

  group('StockPreviewData', () {
    test('defaults isInWatchlist to false', () {
      const data = StockPreviewData(symbol: '2330');
      expect(data.isInWatchlist, false);
    });

    test('defaults reasons to empty list', () {
      const data = StockPreviewData(symbol: '2330');
      expect(data.reasons, isEmpty);
    });
  });
}
