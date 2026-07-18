import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
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
      scoreShort: score,
      scoreLong: score,
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

  group('資料完整度提示（評分改進 #8）', () {
    testWidgets('有缺漏 domain → 顯示 dataMissing 提示（含缺漏項）', (tester) async {
      widenViewport(tester);
      final state = createHeaderData().copyWithMissing(const [
        'stockDetail.domain.revenue',
        'stockDetail.domain.eps',
      ]);

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      // 測試環境 .tr() 回 key：提示文字以 dataMissing key 呈現
      expect(
        find.textContaining('stockDetail.dataMissing'),
        findsOneWidget,
        reason: '缺漏時要提示使用者「分數偏低可能因資料缺漏、非真的弱」',
      );
    });

    test('fromState：ETF（00 開頭）豁免財報類 domain（ETF 無財報非缺漏）', () {
      final state = StockDetailState(
        price: StockPriceState(
          stock: StockMasterEntry(
            symbol: '0050',
            name: '元大台灣50',
            market: 'TWSE',
            isActive: true,
            updatedAt: defaultDate,
          ),
          priceHistory: [
            DailyPriceEntry(symbol: '0050', date: defaultDate, close: 180.0),
          ],
        ),
        // fundamentals 全空 —— 對 ETF 是常態、不是缺漏
      );

      final data = StockHeaderData.fromState(state);
      expect(
        data.missingDomains,
        isNot(contains('stockDetail.domain.revenue')),
      );
      expect(data.missingDomains, isNot(contains('stockDetail.domain.eps')));
      expect(
        data.missingDomains,
        isNot(contains('stockDetail.domain.valuation')),
      );
      // 非財報 domain 照常判定
      expect(data.missingDomains, contains('stockDetail.domain.institutional'));
    });

    testWidgets('資料齊全 → 不顯示提示（零噪音）', (tester) async {
      widenViewport(tester);
      final state = createHeaderData(); // missingDomains 預設空

      await tester.pumpWidget(
        buildTestApp(StockDetailHeader(data: state, symbol: '2330')),
      );

      expect(find.textContaining('stockDetail.dataMissing'), findsNothing);
    });
  });

  group('平盤/微負值：不得顯示上漲箭頭或漲色（flagship 色彩語意）', () {
    StockHeaderData headerWithChange(double pc) => StockHeaderData(
      stockName: '台積電',
      stockMarket: 'TWSE',
      stockIndustry: '半導體',
      latestClose: 600.0,
      priceChange: pc,
      trendState: 'BULLISH', // 讓趨勢 chip 用非 flat 圖示，避免與價格箭頭混淆
      dataDate: defaultDate,
    );

    testWidgets('平盤（priceChange==0）→ 中性色 0.00%、無北向(上漲)箭頭', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          StockDetailHeader(data: headerWithChange(0.0), symbol: '2330'),
        ),
      );

      expect(find.byIcon(Icons.north), findsNothing, reason: '平盤不得顯示上漲箭頭');
      expect(find.text('+0.00%'), findsNothing, reason: '平盤不得帶 + 號');
      expect(find.text('0.00%'), findsOneWidget);
      final pctText = tester.widget<Text>(find.text('0.00%'));
      expect(
        pctText.style?.color,
        AppTheme.neutralColor,
        reason: '平盤數字顯示中性色，箭頭/漸層須與之一致',
      );
    });

    testWidgets('微負值（-0.004）捨入歸零 → 0.00%（非 -0.00%）、無南向(下跌)箭頭', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          StockDetailHeader(data: headerWithChange(-0.004), symbol: '2330'),
        ),
      );

      expect(find.byIcon(Icons.south), findsNothing, reason: '捨入歸零不得顯示下跌箭頭');
      expect(
        find.textContaining('-0.00'),
        findsNothing,
        reason: '不得出現負零 -0.00%',
      );
      expect(find.text('0.00%'), findsOneWidget);
      final pctText = tester.widget<Text>(find.text('0.00%'));
      expect(pctText.style?.color, AppTheme.neutralColor);
    });
  });
}

extension on StockHeaderData {
  /// 測試用：帶缺漏 domain 的複本
  StockHeaderData copyWithMissing(List<String> missing) => StockHeaderData(
    stockName: stockName,
    stockMarket: stockMarket,
    stockIndustry: stockIndustry,
    latestClose: latestClose,
    priceChange: priceChange,
    trendState: trendState,
    support: support,
    resistance: resistance,
    reasons: reasons,
    dataDate: dataDate,
    hasDataMismatch: hasDataMismatch,
    missingDomains: missing,
  );
}
