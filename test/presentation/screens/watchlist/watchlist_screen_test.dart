import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_screen.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifiers
// =============================================================================

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

class FakePortfolioNotifier extends PortfolioNotifier {
  PortfolioState initialState = const PortfolioState();

  @override
  PortfolioState build() => initialState;

  @override
  Future<void> loadPositions() async {}

  @override
  Future<void> deleteTransaction(int id, String symbol) async {}

  @override
  Future<void> addBuy({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    String? note,
  }) async {}

  @override
  Future<void> addSell({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    double? tax,
    String? note,
  }) async {}

  @override
  Future<void> addDividend({
    required String symbol,
    required DateTime date,
    required double amount,
    required bool isCash,
    String? note,
  }) async {}
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

  late WatchlistState _watchlistState;
  late PortfolioState _portfolioState;
  late SettingsState _settingsState;

  Widget buildTestWidget({
    WatchlistState? watchlistState,
    PortfolioState? portfolioState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    _watchlistState = watchlistState ?? WatchlistState();
    _portfolioState = portfolioState ?? const PortfolioState();
    _settingsState = settingsState ?? const SettingsState();
    return buildProviderTestApp(
      const WatchlistScreen(),
      overrides: [
        watchlistProvider.overrideWith(() {
          final n = FakeWatchlistNotifier();
          n.initialState = _watchlistState;
          return n;
        }),
        portfolioProvider.overrideWith(() {
          final n = FakePortfolioNotifier();
          n.initialState = _portfolioState;
          return n;
        }),
        settingsProvider.overrideWith(() {
          final n = FakeSettingsNotifier();
          n.initialState = _settingsState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  WatchlistItemData createItem({
    required String symbol,
    String? stockName,
    double? latestClose,
    double? priceChange,
    double? score,
  }) {
    return WatchlistItemData(
      symbol: symbol,
      stockName: stockName ?? 'Stock $symbol',
      market: 'TWSE',
      latestClose: latestClose ?? 100.0,
      priceChange: priceChange ?? 1.5,
      score: score ?? 80,
      hasSignal: true,
      addedAt: DateTime(2026, 1, 1),
    );
  }

  group('WatchlistScreen', () {
    testWidgets('shows AppBar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(watchlistState: WatchlistState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockListShimmer), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(watchlistState: WatchlistState(error: 'Network error')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows empty watchlist state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows search icon button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows sort icon button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('shows add icon button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows more_vert menu', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows watchlist and portfolio tab segments', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // ButtonSegment renders as part of SegmentedButton
      // Check for segment content: the wallet icon for portfolio tab
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
    });

    testWidgets('shows stock count when items exist', (tester) async {
      widenViewport(tester);
      final items = [createItem(symbol: '2330'), createItem(symbol: '2317')];
      await tester.pumpWidget(
        buildTestWidget(watchlistState: WatchlistState(items: items)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Stock list should be rendered (not empty state)
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('shows compare button when 2+ stocks', (tester) async {
      widenViewport(tester);
      final items = [createItem(symbol: '2330'), createItem(symbol: '2317')];
      await tester.pumpWidget(
        buildTestWidget(watchlistState: WatchlistState(items: items)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('hides compare button with fewer than 2 stocks', (
      tester,
    ) async {
      widenViewport(tester);
      final items = [createItem(symbol: '2330')];
      await tester.pumpWidget(
        buildTestWidget(watchlistState: WatchlistState(items: items)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.compare_arrows), findsNothing);
    });

    testWidgets('tapping search shows TextField', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      // Search icon changes to close
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(WatchlistScreen), findsOneWidget);
    });
  });
}
