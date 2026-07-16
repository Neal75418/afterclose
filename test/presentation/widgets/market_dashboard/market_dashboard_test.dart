import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/data/models/twse/twse_market_index.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_dashboard.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sentiment_gauge_section.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  TwseMarketIndex createIndex(String name, double close, double change) {
    return TwseMarketIndex(
      date: DateTime(2026, 2, 13),
      name: name,
      close: close,
      change: change,
      changePercent: change / close * 100,
    );
  }

  /// TWSE + TPEx 皆有足夠資料觸發 `_computeSentiment` 的 state（兩側情緒儀表
  /// 都會渲染），供「parallel 檢視」情緒配對相關測試共用。
  MarketOverviewState parallelSentimentState() {
    return MarketOverviewState(
      indices: [createIndex(MarketIndexNames.taiex, 22000, 150)],
      advanceDeclineByMarket: {
        'TWSE': const AdvanceDecline(advance: 600, decline: 200),
        'TPEx': const AdvanceDecline(advance: 100, decline: 300),
      },
      historyTrends: HistoryTrends(
        turnover: {
          'TWSE': [
            (date: DateTime(2026, 2, 11), value: 1000.0),
            (date: DateTime(2026, 2, 12), value: 1200.0),
          ],
          'TPEx': [
            (date: DateTime(2026, 2, 11), value: 100.0),
            (date: DateTime(2026, 2, 12), value: 90.0),
          ],
        },
      ),
      dataDate: DateTime(2026, 2, 13),
    );
  }

  MarketOverviewState createLoadedState() {
    return MarketOverviewState(
      indices: [
        createIndex(MarketIndexNames.taiex, 22000, 150),
        createIndex(MarketIndexNames.electronics, 1200, 10),
      ],
      indexHistory: {
        MarketIndexNames.taiex: [21800, 21900, 22000],
      },
      advanceDeclineByMarket: {
        'TWSE': const AdvanceDecline(advance: 500, decline: 300, unchanged: 50),
        'TPEx': const AdvanceDecline(advance: 200, decline: 150, unchanged: 30),
      },
      institutionalByMarket: {
        'TWSE': const InstitutionalTotals(
          foreignNet: 5000000000,
          trustNet: 1000000000,
          dealerNet: -500000000,
          totalNet: 5500000000,
        ),
      },
      dataDate: DateTime(2026, 2, 13),
    );
  }

  group('MarketDashboard', () {
    testWidgets('shows loading indicator when isLoading', (tester) async {
      widenViewport(tester);
      const state = MarketOverviewState(isLoading: true);

      await tester.pumpWidget(
        buildTestApp(const MarketDashboard(state: state)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when no data', (tester) async {
      widenViewport(tester);
      const state = MarketOverviewState();

      await tester.pumpWidget(
        buildTestApp(const MarketDashboard(state: state)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byIcon(Icons.show_chart), findsNothing);
    });

    testWidgets('shows show_chart icon with valid data', (tester) async {
      widenViewport(tester);
      final state = createLoadedState();

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('displays date info from dataDate', (tester) async {
      widenViewport(tester);
      final state = createLoadedState();

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      // 02/13 date should appear
      expect(find.textContaining('02/13'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = createLoadedState();

      await tester.pumpWidget(
        buildTestApp(
          MarketDashboard(state: state),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('指數平盤 + 廣度明顯偏向下跌時，市場欄位頂部顯示綜合判讀 weightSupport', (tester) async {
      widenViewport(tester);
      final state = MarketOverviewState(
        indices: [
          createIndex(MarketIndexNames.taiex, 22000, 10), // ~0.045%，平盤
        ],
        advanceDeclineByMarket: {
          'TWSE': const AdvanceDecline(advance: 200, decline: 800),
        },
        institutionalByMarket: {
          'TWSE': const InstitutionalTotals(totalNet: 100000000),
        },
        dataDate: DateTime(2026, 2, 13),
      );

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('marketOverview.reading.synthesis.weightSupport'),
        findsOneWidget,
      );
    });

    testWidgets('綜合判讀僅在該市場有指數資料時顯示；TPEx 無指數時該欄不渲染', (tester) async {
      widenViewport(tester);
      // createLoadedState()：TWSE 有指數（漲 0.68%，非平盤）+ 法人合計同向買超
      // → neutral；TPEx 有漲跌家數但 indices 中無櫃買指數 → 綜合判讀不顯示。
      final state = createLoadedState();

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('marketOverview.reading.synthesis.neutral'),
        findsOneWidget,
      );
    });

    testWidgets('parallel 檢視在 TWSE + TPEx 皆有足夠資料時，同時渲染兩個市場情緒儀表', (
      tester,
    ) async {
      widenViewport(tester);
      final state = parallelSentimentState();

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      final gauges = tester
          .widgetList<SentimentGaugeSection>(find.byType(SentimentGaugeSection))
          .toList();
      expect(gauges, hasLength(2));
      // TWSE 上漲占比 0.75、TPEx 上漲占比 0.25 → 分數應明顯不同，證明兩側
      // 各自獨立計算（非共用或硬編碼同一值）。
      expect(
        gauges[0].sentiment.score,
        isNot(equals(gauges[1].sentiment.score)),
      );
      // 各自傳入正確且不同的 market，內建標題才能標示「上市/上櫃 市場情緒」
      // 而非兩側顯示相同、無法區分的「市場情緒」（見 SentimentGaugeSection
      // 市場標示測試驗證實際渲染文字）。
      expect(gauges[0].market, MarketCode.twse);
      expect(gauges[1].market, MarketCode.tpex);
    });

    testWidgets(
      'parallel 檢視情緒配對列在 unbounded 高度環境（今日頁 CustomScrollView 情境）下分隔線仍可見',
      (tester) async {
        widenViewport(tester);
        final state = parallelSentimentState();

        // 今日頁實際將 MarketDashboard 放在 CustomScrollView 的
        // SliverToBoxAdapter 內，對 Column 子孫的垂直方向給 unbounded
        // 高度；用 SingleChildScrollView 在測試中複現同一條件
        // （VerticalDivider 唯有在此條件下才會塌陷為 0 高度、隱形）。
        await tester.pumpWidget(
          buildTestApp(
            SingleChildScrollView(child: MarketDashboard(state: state)),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        final sentimentRow = find
            .ancestor(
              of: find.byType(SentimentGaugeSection).first,
              matching: find.byType(Row),
            )
            .first;
        final divider = find.descendant(
          of: sentimentRow,
          matching: find.byType(VerticalDivider),
        );
        expect(divider, findsOneWidget);
        expect(tester.getSize(divider).height, greaterThan(0));
      },
    );

    testWidgets('TPEx 情緒資料不足時，parallel 檢視僅渲染 TWSE 情緒儀表（優雅降級）', (tester) async {
      widenViewport(tester);
      final state = MarketOverviewState(
        indices: [createIndex(MarketIndexNames.taiex, 22000, 150)],
        advanceDeclineByMarket: {
          'TWSE': const AdvanceDecline(advance: 600, decline: 200),
          'TPEx': const AdvanceDecline(advance: 100, decline: 300),
        },
        historyTrends: HistoryTrends(
          turnover: {
            'TWSE': [
              (date: DateTime(2026, 2, 11), value: 1000.0),
              (date: DateTime(2026, 2, 12), value: 1200.0),
            ],
            // 'TPEx' 缺席 → 資料不足，_computeSentiment 應回傳 null
          },
        ),
        dataDate: DateTime(2026, 2, 13),
      );

      await tester.pumpWidget(buildTestApp(MarketDashboard(state: state)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SentimentGaugeSection), findsOneWidget);
    });
  });
}
