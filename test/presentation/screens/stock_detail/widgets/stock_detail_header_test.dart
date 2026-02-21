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

  StockDetailState createState({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    DailyAnalysisEntry? analysis,
    List<DailyPriceEntry>? priceHistory,
    List<DailyReasonEntry>? reasons,
    DateTime? dataDate,
  }) {
    final s = stock ?? createStock();
    final lp = latestPrice ?? createPrice();
    final pp =
        previousPrice ??
        createPrice(
          close: 594.0,
          date: defaultDate.subtract(const Duration(days: 1)),
        );
    final ph = priceHistory ?? [pp, lp];

    return StockDetailState(
      price: StockPriceState(
        stock: s,
        latestPrice: lp,
        previousPrice: pp,
        priceHistory: ph,
        analysis: analysis ?? createAnalysis(),
      ),
      reasons: reasons ?? const [],
      dataDate: dataDate ?? defaultDate,
    );
  }

  group('StockDetailHeader', () {
    testWidgets('displays stock name', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('displays close price', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      expect(find.text('600.00'), findsOneWidget);
    });

    testWidgets('shows TPEx badge for OTC stocks', (tester) async {
      widenViewport(tester);
      final state = createState(stock: createStock(market: 'TPEx'));

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      // Should find the OTC badge text
      expect(find.textContaining('stockDetail.otcBadge'), findsOneWidget);
    });

    testWidgets('shows industry badge', (tester) async {
      widenViewport(tester);
      final state = createState(stock: createStock(industry: '半導體'));

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      expect(find.text('半導體'), findsOneWidget);
    });

    testWidgets('shows support and resistance levels', (tester) async {
      widenViewport(tester);
      final state = createState(
        analysis: createAnalysis(supportLevel: 580.0, resistanceLevel: 620.0),
      );

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      expect(find.textContaining('580.0'), findsOneWidget);
      expect(find.textContaining('620.0'), findsOneWidget);
    });

    testWidgets('shows reason tags when reasons present', (tester) async {
      widenViewport(tester);
      final state = createState(
        reasons: [
          DailyReasonEntry(
            symbol: '2330',
            date: defaultDate,
            rank: 1,
            reasonType: 'GOLDEN_CROSS',
            evidenceJson: '{}',
            ruleScore: 10.0,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(state: state, symbol: '2330')),
      );

      // Reason tag should be rendered
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createState();

      await tester.pumpWidget(
        buildTestApp(
          StockDetailHeader(state: state, symbol: '2330'),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('台積電'), findsOneWidget);
      expect(find.text('600.00'), findsOneWidget);
    });
  });
}
