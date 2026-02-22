import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/stock_detail_screen.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifiers
// =============================================================================

class FakeStockDetailNotifier extends StockDetailNotifier {
  FakeStockDetailNotifier(super.symbol);

  StockDetailState initialState = const StockDetailState();

  @override
  StockDetailState build() => initialState;

  @override
  Future<void> loadData() async {}

  @override
  Future<void> loadFundamentals() async {}

  @override
  Future<void> loadInsiderData() async {}

  @override
  Future<void> loadChipData() async {}

  @override
  Future<void> loadMarginData() async {}

  @override
  Future<void> toggleWatchlist() async {}
}

class FakePriceAlertNotifier extends PriceAlertNotifier {
  PriceAlertState initialState = const PriceAlertState();

  @override
  PriceAlertState build() => initialState;

  @override
  Future<void> loadAlerts() async {}

  @override
  Future<void> deleteAlert(int id) async {}

  @override
  Future<void> toggleAlert(int id, bool isActive) async {}

  @override
  Future<bool> createAlert({
    required String symbol,
    required AlertType alertType,
    required double targetValue,
    String? note,
  }) async {
    return true;
  }
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

  late StockDetailState _stockState;

  Widget buildTestWidget({
    StockDetailState? stockState,
    PriceAlertState? alertState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    _stockState = stockState ?? const StockDetailState();
    return buildProviderTestApp(
      const StockDetailScreen(symbol: '2330'),
      overrides: [
        stockDetailProvider.overrideWith(() {
          final n = FakeStockDetailNotifier('2330');
          n.initialState = _stockState;
          return n;
        }),
        priceAlertProvider.overrideWith(() {
          final n = FakePriceAlertNotifier();
          n.initialState = alertState ?? const PriceAlertState();
          return n;
        }),
        settingsProvider.overrideWith(() {
          final n = FakeSettingsNotifier();
          n.initialState = settingsState ?? const SettingsState();
          return n;
        }),
        primaryRuleAccuracySummaryProvider.overrideWith(
          (ref, symbol) async => null,
        ),
      ],
      brightness: brightness,
    );
  }

  group('StockDetailScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          stockState: const StockDetailState(
            loading: LoadingState(isLoading: true),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockDetailShimmer), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          stockState: const StockDetailState(error: 'Network error'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows SliverAppBar with symbol', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('2330'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows share button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('shows compare button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('shows watchlist star button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // Not in watchlist → star_border
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('shows filled star when in watchlist', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          stockState: const StockDetailState(isInWatchlist: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('shows TabBar with 5 tabs', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(5));
    });

    testWidgets('shows NestedScrollView when loaded', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NestedScrollView), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockDetailScreen), findsOneWidget);
    });
  });
}
