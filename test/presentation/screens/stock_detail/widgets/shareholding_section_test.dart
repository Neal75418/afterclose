import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/shareholding_section.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  ShareholdingEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? foreignSharesRatio = 75.0,
  }) {
    return ShareholdingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      foreignSharesRatio: foreignSharesRatio,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpSection(
    WidgetTester tester,
    Widget widget, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(buildTestApp(widget, brightness: brightness));
    await tester.pump(const Duration(seconds: 1));
  }

  group('ShareholdingSection', () {
    testWidgets('displays language icon', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(
          history: List.generate(
            5,
            (i) => createEntry(date: DateTime(2026, 2, 10 + i)),
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const ShareholdingSection(history: []));

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('displays foreign shares ratio', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(history: [createEntry(foreignSharesRatio: 72.35)]),
      );

      expect(find.text('72.35%'), findsOneWidget);
    });

    testWidgets('detects increasing trend', (tester) async {
      widenViewport(tester);
      final entries = List.generate(
        5,
        (i) => createEntry(
          date: DateTime(2026, 2, 10 + i),
          foreignSharesRatio: 70.0 + i * 0.5,
        ),
      );

      await pumpSection(tester, ShareholdingSection(history: entries));

      expect(find.byType(ShareholdingSection), findsOneWidget);
    });
  });

  group('外資持股趨勢方向色（C2：方向相反）', () {
    // 外資持股增加＝籌碼偏多、減少＝偏空，與漲跌同一多空語意軸，
    // 套台股慣例：增加＝紅、減少＝綠。原實作寫死 #4CAF50（增加→綠）與
    // #F44336（減少→紅），方向完全相反，也與 insider_tab 的增持→紅矛盾。
    //
    // 斷言「渲染出來的文字色色相落在哪一半邊」而非等於某個常數：色相
    // 判斷抓得到紅綠對調（對比度抓不到——兩色互換後對比度完全不變），
    // 常數等式則會隨常數一起改、恆為真。
    List<ShareholdingEntry> ramp(double from, double to) => [
      for (var i = 0; i < 5; i++)
        createEntry(
          date: DateTime(2026, 2, 10 + i),
          foreignSharesRatio: from + (to - from) * i / 4,
        ),
    ];

    Future<Color> badgeColor(
      WidgetTester tester,
      List<ShareholdingEntry> history,
      Brightness brightness,
      String labelKey,
    ) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        ShareholdingSection(history: history),
        brightness: brightness,
      );
      final text = tester.widget<Text>(find.text(labelKey));
      return text.style!.color!;
    }

    for (final brightness in Brightness.values) {
      testWidgets('持股增加 → 紅區色相（$brightness）', (tester) async {
        // 5 日內 +1.0%（>= 0.1 門檻）→ trendIncreasing
        final c = await badgeColor(
          tester,
          ramp(70.0, 71.0),
          brightness,
          'chip.trendIncreasing',
        );
        final h = ColorContrast.hue(c);
        expect(
          h >= 345 || h <= 15,
          isTrue,
          reason: '持股增加＝偏多，台股慣例應為紅；實得色相 ${h.toStringAsFixed(1)}°',
        );
      });

      testWidgets('持股減少 → 綠區色相（$brightness）', (tester) async {
        final c = await badgeColor(
          tester,
          ramp(71.0, 70.0),
          brightness,
          'chip.trendDecreasing',
        );
        final h = ColorContrast.hue(c);
        expect(
          h >= 88 && h <= 175,
          isTrue,
          reason: '持股減少＝偏空，台股慣例應為綠；實得色相 ${h.toStringAsFixed(1)}°',
        );
      });

      testWidgets('持股持平 → 灰階（$brightness）', (tester) async {
        final c = await badgeColor(
          tester,
          ramp(70.0, 70.0),
          brightness,
          'chip.trendStable',
        );
        expect(ColorContrast.hue(c), lessThan(0), reason: '持平不得佔用任何色相');
      });
    }

    testWidgets('趨勢色與 getPriceColor 解析同一組色（不得再現獨立字面值）', (tester) async {
      final up = await badgeColor(
        tester,
        ramp(70.0, 71.0),
        Brightness.light,
        'chip.trendIncreasing',
      );
      expect(
        up,
        AppTheme.getPriceColor(1, Brightness.light),
        reason: '外資持股趨勢與漲跌屬同一語意軸，必須共用同一組色',
      );
    });
  });
}
