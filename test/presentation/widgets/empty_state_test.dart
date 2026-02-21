import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

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

    testWidgets('applies custom iconColor', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EmptyState(
            icon: Icons.star,
            title: 'Custom Color',
            iconColor: Colors.amber,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('EmptyStates factory methods', () {
    testWidgets('noRecommendations shows correct icon and title', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(EmptyStates.noRecommendations()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text(S.emptyNoRecommendations), findsOneWidget);
    });

    testWidgets('noRecommendations with onRefresh shows button', (
      tester,
    ) async {
      var refreshed = false;
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noRecommendations(onRefresh: () => refreshed = true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(S.refresh), findsOneWidget);
      await tester.tap(find.text(S.refresh));
      expect(refreshed, isTrue);
    });

    testWidgets('noFilterResults shows search_off icon', (tester) async {
      await tester.pumpWidget(buildTestApp(EmptyStates.noFilterResults()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
      expect(find.text(S.emptyNoFilterResults), findsOneWidget);
    });

    testWidgets('emptyWatchlist shows star icon', (tester) async {
      await tester.pumpWidget(buildTestApp(EmptyStates.emptyWatchlist()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.text(S.emptyNoWatchlist), findsOneWidget);
    });

    testWidgets('noNews shows article icon', (tester) async {
      await tester.pumpWidget(buildTestApp(EmptyStates.noNews()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      expect(find.text(S.emptyNoNews), findsOneWidget);
    });

    testWidgets('error shows error icon and message', (tester) async {
      await tester.pumpWidget(
        buildTestApp(EmptyStates.error(message: 'Something went wrong')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text(S.emptyError), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('error with onRetry shows retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.error(message: 'Oops', onRetry: () => retried = true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(S.retry), findsOneWidget);
      await tester.tap(find.text(S.retry));
      expect(retried, isTrue);
    });

    testWidgets('networkError shows wifi_off icon', (tester) async {
      await tester.pumpWidget(buildTestApp(EmptyStates.networkError()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text(S.emptyNetworkError), findsOneWidget);
    });
  });

  group('EmptyStateWithMeta', () {
    testWidgets('shows filter icon and condition description', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test Filter',
            conditionDescription: 'Score > 80',
            dataRequirements: ['收盤價'],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
      expect(find.text('Score > 80'), findsOneWidget);
    });

    testWidgets('shows threshold info when provided', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Volume',
            conditionDescription: 'Volume > average',
            dataRequirements: [],
            thresholdInfo: '> 1,000,000',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('> 1,000,000'), findsOneWidget);
    });

    testWidgets('hides threshold info when null', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Score',
            conditionDescription: 'High score',
            dataRequirements: [],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('High score'), findsOneWidget);
    });

    testWidgets('shows expand button when hasDetails', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test',
            conditionDescription: 'Test condition',
            dataRequirements: ['Price data'],
            totalScanned: 1500,
            dataDate: DateTime(2026, 2, 13),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('expand reveals diagnostic icons', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test',
            conditionDescription: 'Test',
            dataRequirements: ['Price'],
            totalScanned: 1500,
            dataDate: DateTime(2026, 2, 13),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('expand reveals data requirements chips', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test',
            conditionDescription: 'Test',
            dataRequirements: ['收盤價', '成交量'],
            totalScanned: 1000,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
      expect(find.text('收盤價'), findsOneWidget);
      expect(find.text('成交量'), findsOneWidget);
    });

    testWidgets('shows clear filter button when callback provided', (
      tester,
    ) async {
      widenViewport(tester);
      var cleared = false;
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test',
            conditionDescription: 'Test',
            dataRequirements: [],
            onClearFilter: () => cleared = true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(cleared, isTrue);
    });

    testWidgets('hides clear filter button when no callback', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Test',
            conditionDescription: 'Test',
            dataRequirements: [],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          EmptyStates.noFilterResultsWithMeta(
            filterName: 'Dark Filter',
            conditionDescription: 'Dark condition',
            dataRequirements: ['Data'],
            thresholdInfo: '> 100',
            totalScanned: 500,
            dataDate: DateTime(2026, 2, 13),
            onClearFilter: () {},
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    });
  });
}
