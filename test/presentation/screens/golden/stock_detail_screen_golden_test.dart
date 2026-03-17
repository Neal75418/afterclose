@Tags(['golden'])
/// Golden test: StockDetailScreen
///
/// 驗證個股詳情頁在 light/dark 模式下的視覺一致性。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/stock_detail_screen.dart';

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
  StockDetailState? stockState,
  Brightness brightness = Brightness.light,
}) {
  final stock = stockState ?? const StockDetailState();
  return buildProviderTestApp(
    const StockDetailScreen(symbol: '2330'),
    overrides: [
      stockDetailProvider.overrideWith2((symbol) {
        final n = FakeStockDetailNotifier(symbol);
        n.initialState = stock;
        return n;
      }),
      priceAlertProvider.overrideWith(() {
        final n = FakePriceAlertNotifier();
        return n;
      }),
      settingsProvider.overrideWith(() {
        final n = FakeSettingsNotifier();
        return n;
      }),
      primaryRuleAccuracySummaryProvider.overrideWith(
        (ref, symbol) async => null,
      ),
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

  group('StockDetailScreen Golden', () {
    testWidgets('light mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/stock_detail_screen_light.png'),
      );
    });

    testWidgets('dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/stock_detail_screen_dark.png'),
      );
    });
  });
}
