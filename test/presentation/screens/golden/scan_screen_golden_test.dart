/// Golden test: ScanScreen
///
/// 驗證掃描結果列表在 light/dark 模式下的視覺一致性。
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/screens/scan/scan_screen.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// ==========================================
// Fake Notifiers
// ==========================================

class FakeScanNotifier extends ScanNotifier {
  ScanState initialState = const ScanState();

  @override
  ScanState build() => initialState;

  @override
  Future<void> loadData() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> setFilter(ScanFilter filter) async {}

  @override
  void setSort(ScanSort sort) {}

  @override
  Future<void> setIndustryFilter(String? industry) async {}

  @override
  Future<void> toggleWatchlist(String symbol) async {}
}

class FakeSettingsNotifier extends SettingsNotifier {
  SettingsState initialState = const SettingsState();

  @override
  SettingsState build() => initialState;

  @override
  void setThemeMode(ThemeMode mode) {}

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

// ==========================================
// Test Data
// ==========================================

final _testStocks = [
  ScanStockItem(
    symbol: '2330',
    score: 85,
    stockName: '台積電',
    market: 'TWSE',
    latestClose: 950.0,
    priceChange: 2.5,
    trendState: 'UP',
    recentPrices: [920, 925, 930, 940, 945, 950],
  ),
  ScanStockItem(
    symbol: '2454',
    score: 72,
    stockName: '聯發科',
    market: 'TWSE',
    latestClose: 1250.0,
    priceChange: 0.8,
    trendState: 'UP',
    recentPrices: [1230, 1240, 1245, 1250],
  ),
  ScanStockItem(
    symbol: '2317',
    score: 55,
    stockName: '鴻海',
    market: 'TWSE',
    latestClose: 185.0,
    priceChange: -1.2,
    trendState: 'DOWN',
    isInWatchlist: true,
    recentPrices: [190, 188, 186, 185],
  ),
];

// ==========================================
// Helpers
// ==========================================

void widenViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget buildTestWidget({
  ScanState? scanState,
  Brightness brightness = Brightness.light,
}) {
  final scan =
      scanState ??
      ScanState(
        stocks: _testStocks,
        hasMore: false,
        totalCount: 3,
        totalAnalyzedCount: 1500,
        dataDate: DateTime(2026, 3, 10),
      );
  return buildProviderTestApp(
    const ScanScreen(),
    overrides: [
      scanProvider.overrideWith(() {
        final n = FakeScanNotifier();
        n.initialState = scan;
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

// ==========================================
// Golden Tests
// ==========================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('ScanScreen Golden', () {
    testWidgets('light mode with stocks', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/scan_screen_light.png'),
      );
    });

    testWidgets('dark mode with stocks', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/scan_screen_dark.png'),
      );
    });
  });
}
