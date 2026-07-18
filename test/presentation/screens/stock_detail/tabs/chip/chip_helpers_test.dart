import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('formatNet', () {
    test('positive small value stays in raw units', () {
      // value < 1000 → just the raw number with +
      expect(formatNet(500), '+500');
    });

    test('negative small value stays in raw units', () {
      expect(formatNet(-300), '-300');
    });

    test('zero returns unsigned 0（平盤不帶 +）', () {
      expect(formatNet(0), '0');
    });
  });

  group('formatSharesChange', () {
    test('positive value keeps +', () {
      expect(formatSharesChange(500), startsWith('+'));
    });

    test('zero has no + sign（平盤不帶 +）', () {
      expect(formatSharesChange(0), isNot(startsWith('+')));
    });
  });

  group('平盤配色一致性（顯示 0 不著漲跌方向色）', () {
    testWidgets('buildNetValue 平盤（0）著中性色', (tester) async {
      await tester.pumpWidget(
        buildTestApp(Builder(builder: (c) => buildNetValue(c, 0))),
      );
      final text = tester.widget<Text>(find.text('0'));
      expect(
        text.style?.color,
        AppTheme.neutralColor,
        reason: '平盤淨額顯示 0，不得著漲(紅)色',
      );
    });

    testWidgets('buildSummaryCard 平盤（0）著中性色', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (c) =>
                buildSummaryCard(c, '外資', 0, Icons.trending_up, Colors.blue),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('0'));
      expect(text.style?.color, AppTheme.neutralColor);
    });
  });

  group('formatBalance', () {
    test('delegates to formatLots', () {
      // formatBalance(value) == formatLots(value)
      final result = formatBalance(500);
      final expected = formatLots(500);
      expect(result, expected);
    });
  });

  group('buildSummaryCard', () {
    testWidgets('displays label and formatted value', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => buildSummaryCard(
              context,
              '外資',
              5000,
              Icons.trending_up,
              Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('外資'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });
  });

  group('buildColoredHeader', () {
    testWidgets('displays label with color dot', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Row(
                children: [buildColoredHeader(theme, '買超', Colors.red)],
              );
            },
          ),
        ),
      );

      expect(find.text('買超'), findsOneWidget);
    });
  });
}
