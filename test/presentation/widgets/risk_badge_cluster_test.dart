import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/widgets/risk_badge_cluster.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('RiskBadgeCluster', () {
    testWidgets('空 warnings → 不顯示（SizedBox.shrink）', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const RiskBadgeCluster(warnings: [])),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('N == 1 → 只顯 icon、不顯數字', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RiskBadgeCluster(warnings: [ReasonType.tradingWarningDisposal]),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('N >= 2 → 顯示總數', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RiskBadgeCluster(
            warnings: [
              ReasonType.tradingWarningDisposal,
              ReasonType.dayTradingHigh,
            ],
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('含 severe → icon 用紅色 errorColor', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RiskBadgeCluster(
            warnings: [
              ReasonType.dayTradingHigh, // moderate
              ReasonType.tradingWarningDisposal, // severe → 主導顏色
            ],
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icon.color, AppTheme.errorColor);
    });

    testWidgets('只有 moderate → icon 用 warning 琥珀色', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RiskBadgeCluster(warnings: [ReasonType.dayTradingHigh]),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icon.color, DesignTokens.warningColor(AppTheme.lightTheme));
    });

    testWidgets('tap → 開啟風險明細 bottomSheet', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RiskBadgeCluster(
            warnings: [
              ReasonType.tradingWarningDisposal,
              ReasonType.dayTradingHigh,
            ],
          ),
        ),
      );

      await tester.tap(find.byType(RiskBadgeCluster));
      await tester.pumpAndSettle();

      // sheet 標題（無 EZ-loc context 時 .tr() 回 key）+ 兩條警訊 row
      expect(find.text('warning.risk.title'), findsOneWidget);
      // severe 與 moderate 各一個嚴重度標籤
      expect(find.text('warning.risk.severe'), findsOneWidget);
      expect(find.text('warning.risk.moderate'), findsOneWidget);
    });
  });
}
