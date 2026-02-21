import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/screens/alerts/alerts_screen.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

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
  }) async => true;
}

// =============================================================================
// Test Helpers
// =============================================================================

PriceAlertEntry createAlert({
  int id = 1,
  String symbol = '2330',
  String alertType = 'ABOVE',
  double targetValue = 900.0,
  bool isActive = true,
  DateTime? triggeredAt,
  String? note,
}) {
  return PriceAlertEntry(
    id: id,
    symbol: symbol,
    alertType: alertType,
    targetValue: targetValue,
    isActive: isActive,
    triggeredAt: triggeredAt,
    note: note,
    createdAt: DateTime(2026, 2, 13),
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

  late PriceAlertState _alertState;

  Widget buildTestWidget({
    PriceAlertState? alertState,
    Brightness brightness = Brightness.light,
  }) {
    _alertState = alertState ?? const PriceAlertState();
    return buildProviderTestApp(
      const AlertsScreen(),
      overrides: [
        priceAlertProvider.overrideWith(() {
          final n = FakePriceAlertNotifier();
          n.initialState = _alertState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('AlertsScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(alertState: const PriceAlertState(isLoading: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GenericListShimmer), findsOneWidget);
    });

    testWidgets('shows empty state when no alerts', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          alertState: const PriceAlertState(error: 'Network error'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows app bar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows FAB with add icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows grouped alert cards', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, symbol: '2330', alertType: 'ABOVE'),
        createAlert(id: 2, symbol: '2330', alertType: 'BELOW'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      // One Card group for symbol 2330
      expect(find.byType(Card), findsOneWidget);
      // Two alert tiles
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('shows symbol badge in group header', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(symbol: '2330')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2330'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows switch for active alert', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(isActive: true)];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows note text', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(note: 'My note')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('My note'), findsOneWidget);
    });

    testWidgets('shows triggered alert with special styling', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(
          isActive: false,
          triggeredAt: DateTime(2026, 2, 14, 10, 30),
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Triggered alert shows time: "2/14 10:30"
      expect(find.textContaining('2/14'), findsAtLeastNWidgets(1));
    });

    testWidgets('multiple symbol groups', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, symbol: '2330'),
        createAlert(id: 2, symbol: '2317'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Two Card groups
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('shows trending_up icon for ABOVE alert', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'ABOVE')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('shows trending_down icon for BELOW alert', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'BELOW')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('shows show_chart icon for CHANGE_PCT alert', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'CHANGE_PCT')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('shows bar_chart icon for VOLUME_SPIKE alert', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'VOLUME_SPIKE')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('shows arrow icons for RSI alerts', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, alertType: 'RSI_OVERBOUGHT'),
        createAlert(id: 2, alertType: 'RSI_OVERSOLD', symbol: '2317'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('shows circle icons for KD alerts', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, alertType: 'KD_GOLDEN_CROSS'),
        createAlert(id: 2, alertType: 'KD_DEATH_CROSS', symbol: '2317'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('shows directional icons for support/resistance', (
      tester,
    ) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, alertType: 'BREAK_RESISTANCE'),
        createAlert(id: 2, alertType: 'BREAK_SUPPORT', symbol: '2317'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.north_east), findsOneWidget);
      expect(find.byIcon(Icons.south_east), findsOneWidget);
    });

    testWidgets('shows emoji_events icon for 52-week high', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'WEEK_52_HIGH')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('shows timeline icon for MA cross alerts', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'CROSS_ABOVE_MA')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('shows analytics icon for fundamental alerts', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'REVENUE_YOY_SURGE')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.analytics), findsOneWidget);
    });

    testWidgets('shows warning icon for trading warning', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'TRADING_WARNING')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('shows person icons for insider alerts', (tester) async {
      widenViewport(tester);
      final alerts = [
        createAlert(id: 1, alertType: 'INSIDER_SELLING'),
        createAlert(id: 2, alertType: 'INSIDER_BUYING', symbol: '2317'),
      ];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.person_remove), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('shows lock icon for high pledge ratio', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(alertType: 'HIGH_PLEDGE_RATIO')];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows inactive alert without triggered state', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert(isActive: false)];
      await tester.pumpWidget(
        buildTestWidget(alertState: PriceAlertState(alerts: alerts)),
      );
      await tester.pump(const Duration(seconds: 1));

      // Inactive non-triggered alert has a switch
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final alerts = [createAlert()];
      await tester.pumpWidget(
        buildTestWidget(
          alertState: PriceAlertState(alerts: alerts),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AlertsScreen), findsOneWidget);
    });
  });
}
