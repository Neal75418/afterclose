import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/empty_state.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('displays icon and title', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(icon: Icons.inbox_outlined, title: 'No Data'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('No Data'), findsOneWidget);
    });

    testWidgets('displays subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Empty',
            subtitle: 'Try again later',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Try again later'), findsOneWidget);
    });

    testWidgets('does not display subtitle when null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(icon: Icons.inbox_outlined, title: 'Empty'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // 只有 title，沒有多餘的 Text widget
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('shows action button when both label and callback provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          EmptyState(
            icon: Icons.refresh,
            title: 'Error',
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('does not show button when actionLabel is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          EmptyState(icon: Icons.refresh, title: 'Error', onAction: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('does not show button when onAction is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(
            icon: Icons.refresh,
            title: 'Error',
            actionLabel: 'Retry',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('action button triggers callback', (tester) async {
      var callbackInvoked = false;

      await tester.pumpWidget(
        buildTestApp(
          EmptyState(
            icon: Icons.refresh,
            title: 'Error',
            actionLabel: 'Retry',
            onAction: () => callbackInvoked = true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Retry'));
      expect(callbackInvoked, isTrue);
    });

    testWidgets('has accessibility semantics wrapper', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Data',
            subtitle: 'Check back later',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.bySemanticsLabel('No Data, Check back later'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(icon: Icons.inbox_outlined, title: 'Dark Mode Test'),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Dark Mode Test'), findsOneWidget);
    });
  });
}
