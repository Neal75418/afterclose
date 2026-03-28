import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/stock_detail_state.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/stock_detail_header.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  final defaultDate = DateTime(2026, 2, 13);

  StockMasterEntry createStock({
    String symbol = '2330',
    String name = '台積電',
    String market = 'TWSE',
    String? industry,
  }) {
    return StockMasterEntry(
      symbol: symbol,
      name: name,
      market: market,
      industry: industry ?? '半導體',
      isActive: true,
      updatedAt: defaultDate,
    );
  }

  DailyPriceEntry createPrice({
    String symbol = '2330',
    double close = 600.0,
    DateTime? date,
  }) {
    final d = date ?? defaultDate;
    return DailyPriceEntry(
      symbol: symbol,
      date: d,
      open: close * 0.99,
      high: close * 1.02,
      low: close * 0.98,
      close: close,
      volume: 50000,
    );
  }

  DailyAnalysisEntry createAnalysis({
    String symbol = '2330',
    double score = 75.0,
    String trend = 'BULLISH',
    String reversal = '',
    double? supportLevel,
    double? resistanceLevel,
  }) {
    return DailyAnalysisEntry(
      symbol: symbol,
      date: defaultDate,
      score: score,
      trendState: trend,
      reversalState: reversal,
      supportLevel: supportLevel,
      resistanceLevel: resistanceLevel,
      computedAt: defaultDate,
    );
  }

  StockHeaderData createHeaderData({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyAnalysisEntry? analysis,
    List<String>? reasons,
    DateTime? dataDate,
  }) {
    final s = stock ?? createStock();
    final lp = latestPrice ?? createPrice();
    final a = analysis ?? createAnalysis();

    return StockHeaderData(
      stockName: s.name,
      stockMarket: s.market,
      stockIndustry: s.industry,
      latestClose: lp.close,
      priceChange: lp.close != null
          ? ((lp.close! - 594.0) / 594.0 * 100) // vs yesterday 594.0
          : null,
      trendState: a.trendState,
      support: a.supportLevel,
      resistance: a.resistanceLevel,
      reasons: reasons ?? const [],
      dataDate: dataDate ?? defaultDate,
    );
  }

  group('StockDetailHeader', () {
    testWidgets('displays stock name', (tester) async {
      widenViewport(tester);
      final state = createHeaderData();

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('displays close price', (tester) async {
      widenViewport(tester);
      final state = createHeaderData();

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      expect(find.text('600.00'), findsOneWidget);
    });

    testWidgets('shows TPEx badge for OTC stocks', (tester) async {
      widenViewport(tester);
      final state = createHeaderData(stock: createStock(market: 'TPEx'));

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      // Should find the OTC badge text
      expect(find.textContaining('stockDetail.otcBadge'), findsOneWidget);
    });

    testWidgets('shows industry badge', (tester) async {
      widenViewport(tester);
      final state = createHeaderData(stock: createStock(industry: '半導體'));

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      expect(find.text('半導體'), findsOneWidget);
    });

    testWidgets('shows support and resistance levels', (tester) async {
      widenViewport(tester);
      final state = createHeaderData(
        analysis: createAnalysis(supportLevel: 580.0, resistanceLevel: 620.0),
      );

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      expect(find.textContaining('580.0'), findsOneWidget);
      expect(find.textContaining('620.0'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createHeaderData();

      await tester.pumpWidget(
        buildTestApp(
          StockDetailHeader(data: state, symbol: '2330'),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('台積電'), findsOneWidget);
      expect(find.text('600.00'), findsOneWidget);
    });
  });
}
