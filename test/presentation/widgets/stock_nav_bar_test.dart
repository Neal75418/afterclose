import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/stock_nav_bar.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('StockNavBar', () {
    testWidgets('中間位置：顯示前後代碼與 n/N、點擊觸發回呼', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        buildTestApp(
          StockNavBar(
            prev: '2330',
            next: '8046',
            position: 12,
            total: 42,
            onNavigate: (s) => tapped = s,
          ),
        ),
      );

      expect(find.text('2330'), findsOneWidget);
      expect(find.text('8046'), findsOneWidget);
      expect(find.text('12/42'), findsOneWidget);

      await tester.tap(find.text('8046'));
      expect(tapped, '8046');
      await tester.tap(find.text('2330'));
      expect(tapped, '2330');
    });

    testWidgets('首檔：上一檔按鈕不顯示', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          StockNavBar(
            prev: null,
            next: '3231',
            position: 1,
            total: 42,
            onNavigate: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('1/42'), findsOneWidget);
    });
  });
}
