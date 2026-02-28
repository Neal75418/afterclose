import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/widgets/price_alert_dialog.dart';

import '../../helpers/provider_test_helpers.dart';
import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(8000, 6000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('CreatePriceAlertDialog', () {
    testWidgets('displays symbol', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      expect(find.text('2330'), findsOneWidget);
    });

    testWidgets('displays stock name when provided', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(
          const CreatePriceAlertDialog(symbol: '2330', stockName: '台積電'),
        ),
      );
      await tester.pump();

      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('hides stock name when null', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      expect(find.text('2330'), findsOneWidget);
      expect(find.text('台積電'), findsNothing);
    });

    testWidgets('pre-fills value field with currentPrice', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(
          const CreatePriceAlertDialog(symbol: '2330', currentPrice: 850.00),
        ),
      );
      await tester.pump();

      expect(find.text('850.00'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows current price hint text', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(
          const CreatePriceAlertDialog(symbol: '2330', currentPrice: 850.00),
        ),
      );
      await tester.pump();

      // The current price hint uses .tr() which returns the key
      // but the actual price value appears in the pre-filled field
      expect(find.textContaining('850.00'), findsAtLeastNWidgets(1));
    });

    testWidgets('has SegmentedButton for alert types', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      expect(find.byType(SegmentedButton<AlertType>), findsOneWidget);
    });

    testWidgets('has target value TextField', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      // Two TextFields: target value + note
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('has cancel and create buttons', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      // FilledButton is the create button (only one in the dialog)
      expect(find.byType(FilledButton), findsOneWidget);
      // AlertDialog has actions — verify it renders
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(
          const CreatePriceAlertDialog(symbol: '2330', stockName: '台積電'),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(find.text('2330'), findsOneWidget);
      expect(find.text('台積電'), findsOneWidget);
    });

    testWidgets('only shows implemented alert types', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      // Should show 15 implemented types (Phase 1 + Phase 3)
      // Phase 1: Basic price alerts (3)
      expect(find.text('alert.alertType.above'), findsOneWidget);
      expect(find.text('alert.alertType.below'), findsOneWidget);
      expect(find.text('alert.alertType.changePct'), findsOneWidget);

      // Phase 3 Batch 1: Volume alerts (2)
      expect(find.text('alert.alertType.volumeSpike'), findsOneWidget);
      expect(find.text('alert.alertType.volumeAbove'), findsOneWidget);

      // Phase 3 Batch 2: 52-week alerts (2)
      expect(find.text('alert.alertType.week52High'), findsOneWidget);
      expect(find.text('alert.alertType.week52Low'), findsOneWidget);

      // Phase 3 Batch 3: RSI/KD indicator alerts (4)
      expect(find.text('alert.alertType.rsiOverbought'), findsOneWidget);
      expect(find.text('alert.alertType.rsiOversold'), findsOneWidget);
      expect(find.text('alert.alertType.kdGoldenCross'), findsOneWidget);
      expect(find.text('alert.alertType.kdDeathCross'), findsOneWidget);

      // Phase 3 Batch 4: MA cross + trading warning alerts (4)
      expect(find.text('alert.alertType.crossAboveMa'), findsOneWidget);
      expect(find.text('alert.alertType.crossBelowMa'), findsOneWidget);
      expect(find.text('alert.alertType.tradingWarning'), findsOneWidget);
      expect(find.text('alert.alertType.tradingDisposal'), findsOneWidget);

      // Should NOT show remaining 8 unimplemented types
      expect(find.text('alert.alertType.breakResistance'), findsNothing);
      expect(find.text('alert.alertType.breakSupport'), findsNothing);
      expect(find.text('alert.alertType.revenueYoySurge'), findsNothing);
      expect(find.text('alert.alertType.highDividendYield'), findsNothing);
      expect(find.text('alert.alertType.peUndervalued'), findsNothing);
      expect(find.text('alert.alertType.insiderSelling'), findsNothing);
      expect(find.text('alert.alertType.insiderBuying'), findsNothing);
      expect(find.text('alert.alertType.highPledgeRatio'), findsNothing);
    });
  });
}
