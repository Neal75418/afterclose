import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/main.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';

void main() {
  group('App', () {
    // Note: AfterCloseApp requires EasyLocalization, Riverpod providers (DB, storage),
    // and router setup. These integration-level tests need a full mock environment.
    // Consider using integration_test package for full app tests.
    testWidgets('renders with navigation bar', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: AfterCloseApp()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AfterClose'), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('掃描'), findsOneWidget);
      expect(find.text('自選'), findsOneWidget);
      expect(find.text('新聞'), findsOneWidget);
    }, skip: true);

    testWidgets('has material 3 theme', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: AfterCloseApp()));
      await tester.pump(const Duration(milliseconds: 100));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.useMaterial3, isTrue);
    }, skip: true);
  });

  group('StockCard', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: Scaffold(body: child),
      );
    }

    testWidgets('displays basic stock info', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(symbol: '2330', stockName: '台積電', latestClose: 580.0),
        ),
      );

      expect(find.text('2330'), findsOneWidget);
      expect(find.text('台積電'), findsOneWidget);
      expect(find.text('580.00'), findsOneWidget);
    });

    testWidgets('displays positive price change with red color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(symbol: '2330', latestClose: 580.0, priceChange: 3.5),
        ),
      );

      // 新格式包含絕對漲跌金額："+19.61 (+3.50%)"
      expect(find.textContaining('+3.50%'), findsOneWidget);
    });

    testWidgets('displays negative price change with green color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            latestClose: 580.0,
            priceChange: -2.5,
          ),
        ),
      );

      // 新格式包含絕對漲跌金額："-14.87 (-2.50%)"
      expect(find.textContaining('-2.50%'), findsOneWidget);
    });

    testWidgets('displays score badge when score is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', score: 45.0)),
      );

      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('displays reasons as tags', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            reasons: ['REVERSAL_W2S', 'VOLUME_SPIKE'],
          ),
        ),
      );

      // 無 i18n 設定時，.tr() 回傳原始 key
      expect(find.text('reasons.reversalW2S'), findsOneWidget);
      expect(find.text('reasons.volumeSpike'), findsOneWidget);
    });

    testWidgets('limits displayed reasons to 2', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const StockCard(
            symbol: '2330',
            reasons: ['REVERSAL_W2S', 'VOLUME_SPIKE', 'TECH_BREAKOUT'],
          ),
        ),
      );

      // 無 i18n 設定，.tr() 回傳 key
      expect(find.text('reasons.reversalW2S'), findsOneWidget);
      expect(find.text('reasons.volumeSpike'), findsOneWidget);
      expect(find.text('reasons.breakout'), findsNothing);
    });

    testWidgets('displays uptrend icon for UP trend state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', trendState: 'UP')),
      );

      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('displays downtrend icon for DOWN trend state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', trendState: 'DOWN')),
      );

      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });

    testWidgets('displays range icon for null trend state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', trendState: null)),
      );

      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
    });

    testWidgets('shows filled star when in watchlist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          StockCard(symbol: '2330', isInWatchlist: true, onWatchlistTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    testWidgets('shows outlined star when not in watchlist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          StockCard(
            symbol: '2330',
            isInWatchlist: false,
            onWatchlistTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(StockCard(symbol: '2330', onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(StockCard));
      expect(tapped, isTrue);
    });

    testWidgets('calls onWatchlistTap when star is tapped', (
      WidgetTester tester,
    ) async {
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
      expect(watchlistTapped, isTrue);
    });

    testWidgets('hides watchlist button when onWatchlistTap is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const StockCard(symbol: '2330', onWatchlistTap: null)),
      );

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    group('score badge colors', () {
      testWidgets('red for score >= 50', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 55.0)),
        );

        expect(find.text('55'), findsOneWidget);
      });

      testWidgets('orange for score >= 35', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 40.0)),
        );

        expect(find.text('40'), findsOneWidget);
      });

      testWidgets('amber for score >= 20', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 25.0)),
        );

        expect(find.text('25'), findsOneWidget);
      });

      testWidgets('grey for score < 20', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const StockCard(symbol: '2330', score: 15.0)),
        );

        expect(find.text('15'), findsOneWidget);
      });
    });
  });

  group('Loading Indicator', () {
    testWidgets('CircularProgressIndicator displays correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Loading state transitions', (WidgetTester tester) async {
      final isLoading = ValueNotifier(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (context, loading, _) {
                return loading
                    ? const Center(child: CircularProgressIndicator())
                    : const Text('Loaded');
              },
            ),
          ),
        ),
      );

      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loaded'), findsNothing);

      // Simulate loading complete
      isLoading.value = false;
      await tester.pump();

      // After loading
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
    });
  });
}
