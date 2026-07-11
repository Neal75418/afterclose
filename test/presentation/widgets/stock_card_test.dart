import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/indicator_colors.dart';
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

    testWidgets('displays close price and positive change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(symbol: '2330', latestClose: 580.0, priceChange: 3.5),
        ),
      );

      expect(find.text('580.00'), findsOneWidget);
      // 格式包含絕對漲跌金額："+19.61 (+3.50%)"
      expect(find.textContaining('+3.50%'), findsOneWidget);
    });

    testWidgets('displays negative change', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            latestClose: 580.0,
            priceChange: -2.5,
          ),
        ),
      );

      expect(find.textContaining('-2.50%'), findsOneWidget);
    });

    testWidgets('displays reasons as tags', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            reasons: ['REVERSAL_W2S', 'VOLUME_SPIKE'],
          ),
        ),
      );

      // 測試環境未載入翻譯資源，.tr() 回傳原始 key
      expect(find.text('reasons.reversalW2S'), findsOneWidget);
      expect(find.text('reasons.volumeSpike'), findsOneWidget);
    });

    testWidgets('limits displayed reasons to 2', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            reasons: ['REVERSAL_W2S', 'VOLUME_SPIKE', 'TECH_BREAKOUT'],
          ),
        ),
      );

      expect(find.text('reasons.reversalW2S'), findsOneWidget);
      expect(find.text('reasons.volumeSpike'), findsOneWidget);
      expect(find.text('reasons.breakout'), findsNothing);
    });

    group('score tier badge（評分改進 #5：分級為主視覺、數字退小字）', () {
      /// 取徽章標籤文字（.tr() 在測試環境回傳 i18n key）的實際顏色
      Color? tierLabelColor(WidgetTester tester, String key) {
        return tester.widget<Text>(find.text(key)).style?.color;
      }

      testWidgets('score >= 45 → 「強」徽章（ratingStrong 色）', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 55.0)),
        );
        expect(
          tierLabelColor(tester, 'score.tier.strong'),
          IndicatorColors.ratingStrong,
        );
        // 確切分數退為小字、中性色（不再暗示假精確度）
        expect(find.text('55'), findsOneWidget);
      });

      testWidgets('score [25,45) → 「中」徽章', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 40.0)),
        );
        expect(
          tierLabelColor(tester, 'score.tier.medium'),
          IndicatorColors.ratingBullish,
        );
      });

      testWidgets('score [12,25) → 「弱」徽章', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 15.0)),
        );
        expect(
          tierLabelColor(tester, 'score.tier.weak'),
          IndicatorColors.ratingNeutral,
        );
      });

      testWidgets('score < 12 → 「觀察」徽章（觀察區列）', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 9.0)),
        );
        expect(find.text('score.tier.observation'), findsOneWidget);
      });
    });
  });
}
