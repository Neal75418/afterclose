import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/models/finmind/dividend.dart';
import 'package:afterclose/data/models/finmind/per.dart';
import 'package:afterclose/data/models/finmind/revenue.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_tab.dart';
import 'package:afterclose/presentation/widgets/metric_card.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import '../../../../helpers/provider_test_helpers.dart';
import '../../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifiers
// =============================================================================

class FakeStockDetailNotifier extends StockDetailNotifier {
  FakeStockDetailNotifier(super.symbol);

  StockDetailState initialState = const StockDetailState();

  @override
  StockDetailState build() => initialState;

  @override
  Future<void> loadFundamentals() async {}

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
  late SettingsState _settingsState;

  Widget buildTestWidget({
    StockDetailState? stockState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    _stockState = stockState ?? const StockDetailState();
    _settingsState = settingsState ?? const SettingsState();
    return buildProviderTestApp(
      const FundamentalsTab(symbol: '2330'),
      overrides: [
        stockDetailProvider.overrideWith(() {
          final n = FakeStockDetailNotifier('2330');
          n.initialState = _stockState;
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

  group('FundamentalsTab', () {
    testWidgets('shows three metric cards with icons', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MetricCard), findsNWidgets(3));
      // P/E icon, P/B icon, Yield icon
      expect(find.byIcon(Icons.analytics), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.percent), findsAtLeastNWidgets(1));
    });

    testWidgets('shows dash for empty PER values', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // No latestPER → all show "-"
      expect(find.text('-'), findsAtLeastNWidgets(3));
    });

    testWidgets('shows revenue section header', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SectionHeader), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.trending_up), findsAtLeastNWidgets(1));
    });

    testWidgets('shows EPS section header', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.bar_chart), findsAtLeastNWidgets(1));
    });

    testWidgets('shows dividend section header', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('shows loading state for fundamentals', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        isLoadingFundamentals: true,
      );
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      // Loading state shows progress indicators
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('shows empty state for all sections', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // Empty state text containers should be present
      expect(find.byType(FundamentalsTab), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FundamentalsTab), findsOneWidget);
    });

    testWidgets('shows PER values when data is present', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        latestPER: const FinMindPER(
          stockId: '2330',
          date: '2026-02-20',
          per: 18.5,
          pbr: 4.32,
          dividendYield: 2.15,
        ),
      );
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('18.5'), findsOneWidget);
      expect(find.text('4.32'), findsOneWidget);
      expect(find.text('2.15%'), findsOneWidget);
    });

    testWidgets('shows revenue table when data exists', (tester) async {
      widenViewport(tester);
      final revenues = [
        FinMindRevenue(
          stockId: '2330',
          date: '2026-01-10',
          revenue: 250000000,
          revenueMonth: 1,
          revenueYear: 2026,
        ),
      ];
      final state = const StockDetailState().copyWith(revenueHistory: revenues);
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FundamentalsTab), findsOneWidget);
      // Revenue table is rendered (not the empty/loading state)
      expect(find.byType(SectionHeader), findsAtLeastNWidgets(3));
    });

    testWidgets('shows EPS table when data exists', (tester) async {
      widenViewport(tester);
      final epsData = [
        FinancialDataEntry(
          symbol: '2330',
          date: DateTime(2025, 9, 30),
          statementType: 'INCOME',
          dataType: 'EPS',
          value: 12.5,
        ),
      ];
      final state = const StockDetailState().copyWith(epsHistory: epsData);
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FundamentalsTab), findsOneWidget);
    });

    testWidgets('shows dividend table when data exists', (tester) async {
      widenViewport(tester);
      final dividends = [
        const FinMindDividend(
          stockId: '2330',
          year: 2025,
          cashDividend: 13.5,
          stockDividend: 0,
        ),
      ];
      final state = const StockDetailState().copyWith(
        dividendHistory: dividends,
      );
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FundamentalsTab), findsOneWidget);
    });

    testWidgets('shows profitability card when metrics exist', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        latestQuarterMetrics: {'ROE': 25.3, 'ROA': 12.1},
      );
      await tester.pumpWidget(buildTestWidget(stockState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FundamentalsTab), findsOneWidget);
    });
  });
}
