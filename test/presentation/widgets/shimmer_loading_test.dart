import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('ShimmerContainer', () {
    testWidgets('renders with specified dimensions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ShimmerContainer(width: 100, height: 50)),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders with semantic label when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ShimmerContainer(
            width: 80,
            height: 40,
            semanticLabel: 'Loading content',
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Loading content',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders without Semantics when label is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ShimmerContainer(width: 80, height: 40)),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.isNotEmpty,
        ),
        findsNothing,
      );
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ShimmerContainer(width: 100, height: 50),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('StockListShimmer', () {
    testWidgets('renders with default item count', (tester) async {
      await tester.pumpWidget(buildTestApp(const StockListShimmer()));

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders with custom item count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const StockListShimmer(itemCount: 3)),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('StockDetailShimmer', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(const StockDetailShimmer()));

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('NewsListShimmer', () {
    testWidgets('renders with default item count', (tester) async {
      await tester.pumpWidget(buildTestApp(const NewsListShimmer()));

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders with custom item count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const NewsListShimmer(itemCount: 2)),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('ShimmerColors', () {
    test('light mode colors are grey-based', () {
      expect(ShimmerColors.baseColor(false), Colors.grey[300]);
      expect(ShimmerColors.highlightColor(false), Colors.grey[100]);
      expect(ShimmerColors.skeletonColor(false), Colors.white);
    });

    test('dark mode colors are slate-based', () {
      expect(ShimmerColors.baseColor(true), const Color(0xFF1E293B));
      expect(ShimmerColors.highlightColor(true), const Color(0xFF334155));
      expect(ShimmerColors.skeletonColor(true), const Color(0xFF0F172A));
    });
  });

  group('ShimmerDimensions', () {
    test('card dimensions are positive', () {
      expect(ShimmerDimensions.cardMarginH, greaterThan(0));
      expect(ShimmerDimensions.cardPadding, greaterThan(0));
      expect(ShimmerDimensions.cardRadius, greaterThan(0));
    });

    test('icon dimensions are consistent', () {
      expect(ShimmerDimensions.iconSize, 48.0);
      expect(ShimmerDimensions.iconRadius, 12.0);
    });
  });
}
