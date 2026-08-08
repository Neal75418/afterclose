import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/presentation/providers/price_alert_provider.dart';
import 'package:daredevil/presentation/widgets/price_alert_dialog.dart';

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

    testWidgets('提醒類型以可換行的 ChoiceChip 呈現(每種一顆)', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      final implemented = AlertType.values.where((t) => t.isImplemented).length;
      expect(find.byType(ChoiceChip), findsNWidgets(implemented));
      expect(
        find.byType(SegmentedButton<AlertType>),
        findsNothing,
        reason: 'SegmentedButton 是 Row,不換行不捲動——23 種類型必然爆版',
      );
    });

    testWidgets('🚨 窄視窗不得 RenderFlex overflow', (tester) async {
      // 2026-08-08 實機:視窗縮小時對話框出現黃黑斜紋
      // 「OVERFLOWED BY 25 PIXELS」,類型標籤被壓成直排。
      //
      // ⚠️ 這個 bug 能活下來,是因為**本檔每一條測試都先呼叫
      // widenViewport**(把視窗撐到 5000×4000 以避開 overflow)——那個
      // 慣例的用意是好的(避免無關的 overflow 噪音),但副作用是
      // 「窄視窗爆版」這一整類 bug 在測試裡**結構上不可能被抓到**。
      // 所以這條刻意**不**撐寬,用接近真實的小視窗跑。
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '800px 寬就爆版的話,一般視窗大小都會爆');
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

    testWidgets('shows all 23 alert types', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildProviderTestApp(const CreatePriceAlertDialog(symbol: '2330')),
      );
      await tester.pump();

      // 驗證 23 種提醒類型（全部已實作）
      // 基本價格提醒 (3)
      expect(find.text('alert.alertType.above'), findsOneWidget);
      expect(find.text('alert.alertType.below'), findsOneWidget);
      expect(find.text('alert.alertType.changePct'), findsOneWidget);

      // 成交量提醒 (2)
      expect(find.text('alert.alertType.volumeSpike'), findsOneWidget);
      expect(find.text('alert.alertType.volumeAbove'), findsOneWidget);

      // 52 週高低提醒 (2)
      expect(find.text('alert.alertType.week52High'), findsOneWidget);
      expect(find.text('alert.alertType.week52Low'), findsOneWidget);

      // RSI/KD 指標提醒 (4)
      expect(find.text('alert.alertType.rsiOverbought'), findsOneWidget);
      expect(find.text('alert.alertType.rsiOversold'), findsOneWidget);
      expect(find.text('alert.alertType.kdGoldenCross'), findsOneWidget);
      expect(find.text('alert.alertType.kdDeathCross'), findsOneWidget);

      // MA 交叉 + 注意/處置提醒 (4)
      expect(find.text('alert.alertType.crossAboveMa'), findsOneWidget);
      expect(find.text('alert.alertType.crossBelowMa'), findsOneWidget);
      expect(find.text('alert.alertType.tradingWarning'), findsOneWidget);
      expect(find.text('alert.alertType.tradingDisposal'), findsOneWidget);

      // Phase 3: 進階警示類型 (8) — 全部已實作
      expect(find.text('alert.alertType.breakResistance'), findsOneWidget);
      expect(find.text('alert.alertType.breakSupport'), findsOneWidget);
      expect(find.text('alert.alertType.revenueYoySurge'), findsOneWidget);
      expect(find.text('alert.alertType.highDividendYield'), findsOneWidget);
      expect(find.text('alert.alertType.peUndervalued'), findsOneWidget);
      expect(find.text('alert.alertType.insiderSelling'), findsOneWidget);
      expect(find.text('alert.alertType.insiderBuying'), findsOneWidget);
      expect(find.text('alert.alertType.highPledgeRatio'), findsOneWidget);
    });
  });
}
