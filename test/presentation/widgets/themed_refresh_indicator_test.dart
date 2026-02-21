import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('ThemedRefreshIndicator', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ThemedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('Item 1'), Text('Item 2')]),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('wraps child in RefreshIndicator', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ThemedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('content')]),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ThemedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('dark')]),
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ThemedRefreshIndicator), findsOneWidget);
    });
  });

  group('AnimatedRefreshIndicator', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AnimatedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('Animated child')]),
          ),
        ),
      );

      expect(find.text('Animated child'), findsOneWidget);
    });

    testWidgets('wraps child in RefreshIndicator', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AnimatedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('content')]),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AnimatedRefreshIndicator(
            onRefresh: () async {},
            child: ListView(children: const [Text('dark')]),
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(AnimatedRefreshIndicator), findsOneWidget);
    });
  });
}
