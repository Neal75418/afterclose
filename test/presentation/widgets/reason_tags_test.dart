import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('ReasonTags', () {
    testWidgets('displays all reason labels', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ReasonTags(reasons: ['Alpha', 'Beta', 'Gamma'])),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('limits displayed tags with maxTags', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ReasonTags(reasons: ['A', 'B', 'C', 'D', 'E'], maxTags: 3),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(find.text('E'), findsNothing);
    });

    testWidgets('shows all tags when maxTags is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ReasonTags(reasons: ['X', 'Y', 'Z'])),
      );

      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('renders empty when reasons list is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const ReasonTags(reasons: [])));

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('renders with compact size', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ReasonTags(reasons: ['Tag1'], size: ReasonTagSize.compact),
        ),
      );

      expect(find.text('Tag1'), findsOneWidget);
    });

    testWidgets('renders with normal size', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ReasonTags(reasons: ['Tag1'], size: ReasonTagSize.normal),
        ),
      );

      expect(find.text('Tag1'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ReasonTags(reasons: ['DarkTag']),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('DarkTag'), findsOneWidget);
    });

    testWidgets('深色模式實際渲染的底色疊加文字色，對比達 AA 4.5:1（守住接線，非只守常數）', (tester) async {
      // 這裡刻意從 render tree 讀取實際的 decoration 底色、alpha 與文字
      // 色——而非重複斷言 QualityColors 常數彼此的數值——否則若有人把
      // 文字色改回未經校準的顏色，或改了 DesignTokens.opacity25，
      // 只驗證常數值的守門測試不會發現任何異常（常數本身沒變）。
      await tester.pumpWidget(
        buildTestApp(
          const ReasonTags(reasons: ['DarkTag']),
          brightness: Brightness.dark,
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('DarkTag'),
              matching: find.byType(Container),
            )
            .first,
      );
      final tint = (container.decoration! as BoxDecoration).color!;
      final textColor = tester.widget<Text>(find.text('DarkTag')).style!.color!;

      // ReasonTags 兩個真實使用點的卡片底色：stock_preview_sheet.dart 是
      // colorScheme.surface；stock_card.dart 走 AppTheme.cardDecoration，
      // 高分卡片（score >= 80）在深色主題另外套用 premiumGradient
      // （darkSurface → darkElevated@50%），實測該情境下合成色略深，
      // brandOnDecorative 仍達 5.76:1（低於平面 surface 的 6.08:1，但
      // 仍遠高於 4.5 門檻）。此處以 colorScheme.surface（較保守、較常見
      // 的情境）為準。
      final composite = ColorContrast.compositeOver(
        Color.from(alpha: 1.0, red: tint.r, green: tint.g, blue: tint.b),
        AppTheme.darkTheme.colorScheme.surface,
        tint.a,
      );
      expect(
        ColorContrast.ratio(textColor, composite),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('ReasonTags.translateReasonCode', () {
    test('returns original code for unknown codes', () {
      expect(ReasonTags.translateReasonCode('UNKNOWN_CODE'), isNotEmpty);
    });

    test('tooltipForReasonCode returns null for unknown codes', () {
      expect(ReasonTags.tooltipForReasonCode('UNKNOWN_CODE'), isNull);
    });
  });
}
