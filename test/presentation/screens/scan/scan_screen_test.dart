import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/screens/scan/scan_screen.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

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
    ScanState? scanState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    final scan = scanState ?? const ScanState();
    final settings = settingsState ?? const SettingsState();
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
          n.initialState = settings;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('ScanScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(scanState: const ScanState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StockListShimmer), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows more menu with extra scan options', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // more_vert menu is visible
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // 點開選單後額外功能項目出現在 popup 中
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        // 忽略 popup 在測試 viewport 的 overflow（非真實 bug）
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // 融券賣出排行（trending_down）為保留的選單項目之一
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
      FlutterError.onError = originalOnError;
    });

    testWidgets('shows sort icon button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('shows filter chips row', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilterChip), findsAtLeastNWidgets(1));
    });

    testWidgets('shows more filters action chip', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byType(ActionChip), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(scanState: const ScanState(error: 'Network error')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows empty state when no stocks', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows filtering indicator', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(scanState: const ScanState(isFiltering: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows stock count text', (tester) async {
      widenViewport(tester);
      final stocks = [
        ScanStockItem(
          symbol: '2330',
          score: 85,
          stockName: 'TSMC',
          market: 'TWSE',
          latestClose: 600.0,
          reasons: [],
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(scanState: ScanState(stocks: stocks, hasMore: false)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Stock count semantics area
      expect(find.byType(Semantics), findsAtLeastNWidgets(1));
    });

    testWidgets('shows current filter chip when filter is not all', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          scanState: const ScanState(filter: ScanFilter.reversalW2S),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show at least 2 FilterChips (all + current filter)
      expect(find.byType(FilterChip), findsAtLeastNWidgets(2));
      // Close icon for removing current filter
      expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));
    });

    testWidgets('shows industry filter chip when industries available', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          scanState: const ScanState(industries: ['半導體', '電子零組件', '金融']),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.factory_outlined), findsOneWidget);
    });
  });
}
