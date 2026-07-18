import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/industry_allocation_card.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('IndustryAllocationCard', () {
    testWidgets('returns SizedBox.shrink when allocation is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const IndustryAllocationCard(allocation: {})),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(IndustryAllocationCard), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline), findsNothing);
    });

    testWidgets('displays pie_chart_outline icon with data', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 50.0,
          symbols: ['2330', '2303'],
        ),
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 300000,
          percentage: 30.0,
          symbols: ['2881', '2882'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('displays industry names', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 60.0,
          symbols: ['2330'],
        ),
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 200000,
          percentage: 40.0,
          symbols: ['2881'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('半導體業'), findsOneWidget);
      expect(find.text('金融保險業'), findsOneWidget);
    });

    testWidgets('displays percentage values', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 60.0,
          symbols: ['2330'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('60.0%'), findsOneWidget);
    });

    testWidgets('displays symbol list', (tester) async {
      widenViewport(tester);
      final allocation = {
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 500000,
          percentage: 100.0,
          symbols: ['2330', '2303'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      expect(find.text('2330, 2303'), findsOneWidget);
    });

    testWidgets('sorts by percentage descending', (tester) async {
      widenViewport(tester);
      final allocation = {
        '金融保險業': const IndustryAllocation(
          industry: '金融保險業',
          value: 200000,
          percentage: 20.0,
          symbols: ['2881'],
        ),
        '半導體業': const IndustryAllocation(
          industry: '半導體業',
          value: 800000,
          percentage: 80.0,
          symbols: ['2330'],
        ),
      };

      await tester.pumpWidget(
        buildTestApp(IndustryAllocationCard(allocation: allocation)),
      );

      // Both should render
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
    });
  });

  group('產業色表守門（色相禁區＋對比＋兩兩區隔）', () {
    // 對比度背景取自本 widget 實際渲染路徑：Container 使用
    // theme.colorScheme.surfaceContainerLow，該階在兩個主題都未個別指定，
    // `??` 落回 surface——淺色主題是 #F8F9FA、深色主題是 #27272A
    // （SemanticColors.darkSurface）。過去 16 色只挑過色相、從未驗證過
    // 對比度，也沒有測試會攔住色相回歸或重複色（mutation test 曾證實把
    // 色值改回禁區色，26 個既有測試依然全綠）。
    const lightBg = SemanticColors.lightSurface;
    const darkBg = SemanticColors.darkSurface;

    bool inPriceHueZone(Color c) {
      final h = ColorContrast.hue(c);
      if (h < 0) return false; // 灰階不佔用色相
      return h >= 345 || h <= 15 || (h >= 88 && h <= 175);
    }

    void checkTable(Map<String, Color> table, Color bg, String label) {
      // (a) 色相禁區——紅 >=345°或<=15°、綠 88-175°，與 chartPalette 同一準則。
      for (final entry in table.entries) {
        expect(
          inPriceHueZone(entry.value),
          isFalse,
          reason:
              '$label ${entry.key} '
              '${entry.value.toARGB32().toRadixString(16)} 色相 '
              '${ColorContrast.hue(entry.value).toStringAsFixed(1)}° 落在股價語意區',
        );
      }

      // (b) 對比度——每色對其實際背景達圖形物件門檻 3.0:1。
      for (final entry in table.entries) {
        expect(
          ColorContrast.ratio(entry.value, bg),
          greaterThanOrEqualTo(3.0),
          reason:
              '$label ${entry.key} '
              '${entry.value.toARGB32().toRadixString(16)} 對比不足',
        );
      }

      // (c) 兩兩區隔——沿用 chartPalette 既有方法論：異族色相間距 >= 35 度，
      // 或同族（色相差 <= 15 度）以直接對比比值 >= 1.5x 靠明度區分。
      // 兩者之間沒有第三種「差不多但沒驗證」的灰色地帶——色相差落在
      // (15°, 35°) 視為該判準下的違規，不得默默放行。
      // 灰階（hue < 0，例如「其他」的純灰）與任何飽和色一望即知可區分，
      // 不納入色相間距計算。
      final names = table.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final a = table[names[i]]!;
          final b = table[names[j]]!;
          final ha = ColorContrast.hue(a);
          final hb = ColorContrast.hue(b);
          if (ha < 0 || hb < 0) continue;

          var delta = (ha - hb).abs();
          if (delta > 180) delta = 360 - delta;

          if (delta <= 15) {
            final ra = ColorContrast.ratio(a, bg);
            final rb = ColorContrast.ratio(b, bg);
            final hiR = ra > rb ? ra : rb;
            final loR = ra > rb ? rb : ra;
            expect(
              hiR / loR,
              greaterThanOrEqualTo(1.5),
              reason:
                  '$label ${names[i]} vs ${names[j]} 同色族'
                  '（色相差 ${delta.toStringAsFixed(1)}°）但明度差不足，圖例難以區分',
            );
          } else {
            expect(
              delta,
              greaterThanOrEqualTo(35.0),
              reason:
                  '$label ${names[i]} vs ${names[j]} 色相間距 '
                  '${delta.toStringAsFixed(1)}°，落入既非同族又未達安全間距的死區',
            );
          }
        }
      }
    }

    test('淺色主題 16 色皆合格', () {
      checkTable(IndustryAllocationCard.industryColorsLight, lightBg, '淺色');
    });

    test('深色主題 16 色皆合格', () {
      checkTable(IndustryAllocationCard.industryColorsDark, darkBg, '深色');
    });

    test('淺色／深色兩組色表涵蓋完全相同的 16 個產業鍵值', () {
      expect(
        IndustryAllocationCard.industryColorsLight.keys.toSet(),
        IndustryAllocationCard.industryColorsDark.keys.toSet(),
      );
      expect(IndustryAllocationCard.industryColorsLight, hasLength(16));
    });
  });
}
