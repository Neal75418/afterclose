import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/warning_badge.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('WarningBadgeType', () {
    test('disposal has correct icon', () {
      expect(WarningBadgeType.disposal.icon, Icons.dangerous_rounded);
    });

    test('attention has correct icon', () {
      expect(WarningBadgeType.attention.icon, Icons.warning_amber_rounded);
    });

    test('highPledge has correct icon', () {
      expect(WarningBadgeType.highPledge.icon, Icons.account_balance_rounded);
    });
  });

  group('WarningBadge', () {
    testWidgets('renders disposal badge with icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(type: WarningBadgeType.disposal, animate: false),
        ),
      );

      expect(find.byIcon(Icons.dangerous_rounded), findsOneWidget);
    });

    testWidgets('renders attention badge with icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(type: WarningBadgeType.attention, animate: false),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders highPledge badge with icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(type: WarningBadgeType.highPledge, animate: false),
        ),
      );

      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    });

    testWidgets('hides icon when showIcon is false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(
            type: WarningBadgeType.disposal,
            animate: false,
            showIcon: false,
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders with animation and settles', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(type: WarningBadgeType.disposal, animate: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dangerous_rounded), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WarningBadge(type: WarningBadgeType.attention, animate: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('WarningBadgeOverlay positions correctly', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Stack(
            children: [
              SizedBox(width: 200, height: 200),
              WarningBadgeOverlay(
                type: WarningBadgeType.disposal,
                animate: false,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(Positioned), findsOneWidget);
      expect(find.byType(WarningBadge), findsOneWidget);
    });
  });
}
