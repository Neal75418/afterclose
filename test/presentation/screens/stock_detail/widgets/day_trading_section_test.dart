import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/chip_scoring_params.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/day_trading_section.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  DayTradingEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? dayTradingRatio = 20.0,
  }) {
    return DayTradingEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      dayTradingRatio: dayTradingRatio,
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

  group('DayTradingSection', () {
    testWidgets('displays flash_on icon', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(
          history: List.generate(
            5,
            (i) => createEntry(date: DateTime(2026, 2, 10 + i)),
          ),
        ),
      );

      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const DayTradingSection(history: []));

      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('displays latest day trading ratio', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(
          history: [
            createEntry(date: DateTime(2026, 2, 13), dayTradingRatio: 15.0),
            createEntry(date: DateTime(2026, 2, 14), dayTradingRatio: 22.5),
          ],
        ),
      );

      expect(find.text('22.5%'), findsOneWidget);
    });

    // 門檻取自 ChipScoringParams，跟著常數走，避免像舊版寫死 40.0 那樣
    // 在門檻由 35 → 60 之後靜默失效（40% 已不再是「高」，但只斷言文字
    // 有渲染 → 測試照樣綠，實際上已不再覆蓋 high 分支）。
    const threshold = ChipScoringParams.dayTradingHighThresholdPct;

    Color? ratioTextColor(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text).first).style?.color;

    testWidgets('高當沖率（>= 門檻）比率文字標示為下跌色', (tester) async {
      widenViewport(tester);
      const high = threshold + 5; // 65.0
      await pumpSection(
        tester,
        DayTradingSection(history: [createEntry(dayTradingRatio: high)]),
      );

      expect(find.text('${high.toStringAsFixed(1)}%'), findsWidgets);
      expect(
        ratioTextColor(tester, '${high.toStringAsFixed(1)}%'),
        AppTheme.downColor,
      );
    });

    testWidgets('門檻以下不標示為高（40% 在新門檻下屬正常區間）', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        DayTradingSection(history: [createEntry(dayTradingRatio: 40.0)]),
      );

      expect(find.text('40.0%'), findsWidgets);
      expect(ratioTextColor(tester, '40.0%'), isNot(AppTheme.downColor));
    });
  });
}
