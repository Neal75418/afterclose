import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/today/today_screen.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/update_progress_banner.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// ==========================================
// Fake Notifiers
// ==========================================

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
  Future<bool> removeStock(String symbol) async => true;

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

// ==========================================
// Tests
// ==========================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestWidget({
    TodayState? todayState,
    WatchlistState? watchlistState,
    MarketOverviewState? marketState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    final today = todayState ?? const TodayState();
    final watchlist = watchlistState ?? WatchlistState();
    final market = marketState ?? const MarketOverviewState();
    final settings = settingsState ?? const SettingsState();
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
          n.initialState = watchlist;
          return n;
        }),
        marketOverviewProvider.overrideWith(() {
          final n = FakeMarketOverviewNotifier();
          n.initialState = market;
          return n;
        }),
        settingsProvider.overrideWith(() {
          final n = FakeSettingsNotifier();
          n.initialState = settings;
          return n;
        }),
        // 2026-06-19：3-tab Mode UI 加上。Today 篩選器改 FutureProvider.family，
        // 用 SynchronousFuture 同步 resolve、跳過 loading state、避開
        // CircularProgressIndicator 的 ticker 留下 pending timer 的 test infra bug。
        modeRecommendationsProvider.overrideWith(
          (ref, mode) => SynchronousFuture(const []),
        ),
      ],
      brightness: brightness,
    );
  }

  group('TodayScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(todayState: const TodayState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockListShimmer), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(todayState: const TodayState(error: 'Network error')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows refresh icon when not updating', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows progress indicator when updating', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(todayState: const TodayState(isUpdating: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows notifications icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('shows more menu with settings', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // Settings is now in the overflow menu
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows empty recommendations state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // EmptyState for no recommendations
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows SliverAppBar with app name', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows last update and data date', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          todayState: TodayState(
            lastUpdate: DateTime(2026, 2, 20, 18, 0),
            dataDate: DateTime(2026, 2, 20),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // 最後更新與資料日期兩個資訊區塊都應渲染
      // （測試環境未載入翻譯，.tr() 回傳 key）
      expect(find.text('today.lastUpdate'), findsOneWidget);
      expect(find.text('today.dataDate'), findsOneWidget);
    });

    testWidgets('shows update progress banner', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          todayState: const TodayState(
            isUpdating: true,
            updateProgress: UpdateProgress(
              currentStep: 3,
              totalSteps: 10,
              message: 'Updating...',
            ),
          ),
        ),
      );
      // Use multiple pumps to handle flutter_animate timers
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // banner 本體必須渲染（AppBar 在 isUpdating 時本來就有一顆 spinner，
      // 驗 CircularProgressIndicator 無法區分兩者）
      expect(find.byType(UpdateProgressBanner), findsOneWidget);
    });

    testWidgets('shows section header for recommendations', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // trending_up icon from SectionHeader
      expect(find.byIcon(Icons.trending_up), findsAtLeastNWidgets(1));
    });
  });
}
