/// Golden test: TodayScreen
///
/// 驗證首頁推薦股列表在 light/dark 模式下的視覺一致性。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/today/today_screen.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifiers
// =============================================================================

class FakeTodayNotifier extends TodayNotifier {
  TodayState initialState = const TodayState();

  @override
  TodayState build() => initialState;

  @override
  Future<void> loadData() async {}
}

class FakeWatchlistNotifier extends WatchlistNotifier {
  WatchlistState initialState = WatchlistState();

  @override
  WatchlistState build() => initialState;

  @override
  Future<void> loadData() async {}

  @override
  Future<void> loadMore() async {}

  @override
  void setSearchQuery(String query) {}

  @override
  void setSort(WatchlistSort sort) {}

  @override
  void setGroup(WatchlistGroup group) {}

  @override
  Future<bool> addStock(String symbol) async => true;

  @override
  Future<void> removeStock(String symbol) async {}

  @override
  Future<void> restoreStock(String symbol) async {}
}

class FakeMarketOverviewNotifier extends MarketOverviewNotifier {
  MarketOverviewState initialState = const MarketOverviewState();

  @override
  MarketOverviewState build() => initialState;

  @override
  Future<void> loadData() async {}
}

class FakeSettingsNotifier extends SettingsNotifier {
  SettingsState initialState = const SettingsState();

  @override
  SettingsState build() => initialState;

  @override
  void setThemeMode(ThemeMode mode) {}

  @override
  void toggleTheme() {}

  @override
  void setLocale(AppLocale locale) {}

  @override
  void setShowROCYear(bool value) {}

  @override
  void setShowWarningBadges(bool value) {}

  @override
  void setInsiderNotifications(bool value) {}

  @override
  void setDisposalUrgentAlerts(bool value) {}

  @override
  void setLimitAlerts(bool value) {}

  @override
  void setCacheDurationMinutes(int minutes) {}

  @override
  void setAutoUpdateEnabled(bool value) {}
}

// =============================================================================
// Test Data
// =============================================================================

final _testDate = DateTime(2026, 3, 10);

final _testRecommendations = [
  RecommendationWithDetails(
    symbol: '2330',
    score: 85.0,
    rank: 1,
    stockName: '台積電',
    market: 'TWSE',
    latestClose: 950.0,
    priceChange: 2.5,
    trendState: 'UP',
    recentPrices: [920, 925, 930, 940, 945, 950],
  ),
  RecommendationWithDetails(
    symbol: '2317',
    score: 72.0,
    rank: 2,
    stockName: '鴻海',
    market: 'TWSE',
    latestClose: 185.0,
    priceChange: -1.2,
    trendState: 'DOWN',
    recentPrices: [190, 188, 186, 185],
  ),
  RecommendationWithDetails(
    symbol: '2454',
    score: 68.0,
    rank: 3,
    stockName: '聯發科',
    market: 'TWSE',
    latestClose: 1250.0,
    priceChange: 0.8,
    trendState: 'UP',
    recentPrices: [1230, 1240, 1245, 1250],
  ),
];

// =============================================================================
// Helpers
// =============================================================================

void widenViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget buildTestWidget({
  TodayState? todayState,
  Brightness brightness = Brightness.light,
}) {
  final today =
      todayState ??
      TodayState(
        recommendations: _testRecommendations,
        lastUpdate: _testDate,
        dataDate: _testDate,
      );
  return buildProviderTestApp(
    const TodayScreen(),
    overrides: [
      todayProvider.overrideWith(() {
        final n = FakeTodayNotifier();
        n.initialState = today;
        return n;
      }),
      watchlistProvider.overrideWith(() {
        final n = FakeWatchlistNotifier();
        return n;
      }),
      marketOverviewProvider.overrideWith(() {
        final n = FakeMarketOverviewNotifier();
        return n;
      }),
      settingsProvider.overrideWith(() {
        final n = FakeSettingsNotifier();
        return n;
      }),
    ],
    brightness: brightness,
  );
}

// =============================================================================
// Golden Tests
// =============================================================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('TodayScreen Golden', () {
    testWidgets('light mode with recommendations', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/today_screen_light.png'),
      );
    });

    testWidgets('dark mode with recommendations', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/today_screen_dark.png'),
      );
    });
  });
}
