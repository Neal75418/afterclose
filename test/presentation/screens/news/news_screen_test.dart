import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/news_provider.dart';
import 'package:afterclose/presentation/screens/news/news_screen.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeNewsNotifier extends NewsNotifier {
  NewsState initialState = NewsState();

  @override
  NewsState build() => initialState;

  @override
  Future<void> loadData({int days = 7}) async {}

  @override
  void setSourceFilter(NewsSource source) {}
}

// =============================================================================
// Test Helpers
// =============================================================================

NewsItemEntry createNewsItem({
  String id = 'news_1',
  String title = 'TSMC Q1 Revenue Hits Record',
  String source = 'MoneyDJ',
  String url = 'https://example.com/news/1',
  DateTime? publishedAt,
}) {
  return NewsItemEntry(
    id: id,
    title: title,
    source: source,
    url: url,
    category: 'market',
    publishedAt: publishedAt ?? DateTime.now(),
    fetchedAt: DateTime.now(),
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
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  late NewsState _newsState;

  Widget buildTestWidget({
    NewsState? newsState,
    Brightness brightness = Brightness.light,
  }) {
    _newsState = newsState ?? NewsState();
    return buildProviderTestApp(
      const NewsScreen(),
      overrides: [
        newsProvider.overrideWith(() {
          final n = FakeNewsNotifier();
          n.initialState = _newsState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('NewsScreen', () {
    testWidgets('shows AppBar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows refresh icon button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NewsListShimmer), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(error: 'Network error')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows empty state when no news', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows news items', (tester) async {
      widenViewport(tester);
      final now = DateTime.now();
      final newsItems = [
        createNewsItem(
          id: 'n1',
          title: 'Breaking: TSMC Earnings',
          source: 'MoneyDJ',
          publishedAt: now,
        ),
        createNewsItem(
          id: 'n2',
          title: 'Market Update Today',
          source: 'Yahoo財經',
          publishedAt: now,
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(allNews: newsItems)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Breaking: TSMC Earnings'), findsOneWidget);
      expect(find.text('Market Update Today'), findsOneWidget);
    });

    testWidgets('shows source badges', (tester) async {
      widenViewport(tester);
      final newsItems = [
        createNewsItem(source: 'MoneyDJ', publishedAt: DateTime.now()),
      ];
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(allNews: newsItems)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('MoneyDJ'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows source filter chips when has news', (tester) async {
      widenViewport(tester);
      final newsItems = [
        createNewsItem(source: 'MoneyDJ', publishedAt: DateTime.now()),
      ];
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(allNews: newsItems)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilterChip), findsAtLeastNWidgets(1));
    });

    testWidgets('hides source chips when loading', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('shows related stock chips', (tester) async {
      widenViewport(tester);
      final newsItems = [
        createNewsItem(
          id: 'n1',
          title: 'TSMC News',
          publishedAt: DateTime.now(),
        ),
      ];
      final newsStockMap = <String, List<String>>{
        'n1': ['2330', '2317'],
      };
      await tester.pumpWidget(
        buildTestWidget(
          newsState: NewsState(allNews: newsItems, newsStockMap: newsStockMap),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2330'), findsOneWidget);
      expect(find.text('2317'), findsOneWidget);
    });

    testWidgets('shows overflow chip for many related stocks', (tester) async {
      widenViewport(tester);
      final newsItems = [
        createNewsItem(
          id: 'n1',
          title: 'Sector Report',
          publishedAt: DateTime.now(),
        ),
      ];
      final newsStockMap = <String, List<String>>{
        'n1': ['2330', '2317', '2454', '2412', '3711'],
      };
      await tester.pumpWidget(
        buildTestWidget(
          newsState: NewsState(allNews: newsItems, newsStockMap: newsStockMap),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Shows +2 overflow chip (5 stocks - 3 visible = 2 overflow)
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('shows arrow forward icon on news items', (tester) async {
      widenViewport(tester);
      final newsItems = [createNewsItem(publishedAt: DateTime.now())];
      await tester.pumpWidget(
        buildTestWidget(newsState: NewsState(allNews: newsItems)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final newsItems = [createNewsItem(publishedAt: DateTime.now())];
      await tester.pumpWidget(
        buildTestWidget(
          newsState: NewsState(allNews: newsItems),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NewsScreen), findsOneWidget);
    });
  });
}
