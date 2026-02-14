import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/score_ring.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('ScoreRing', () {
    testWidgets('displays integer score text', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScoreRing(score: 45.7)));

      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('displays zero score', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScoreRing(score: 0)));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('displays max score of 100', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScoreRing(score: 100)));

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('renders two CircularProgressIndicators', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScoreRing(score: 50)));

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });

    testWidgets('has accessibility semantics label', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScoreRing(score: 75)));

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '評分 75 分',
        ),
        findsOneWidget,
      );
    });

    testWidgets('respects custom maxScore', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ScoreRing(score: 30, maxScore: 50)),
      );

      expect(find.text('30'), findsOneWidget);
    });

    group('size variants', () {
      testWidgets('small size renders correctly', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ScoreRing(score: 50, size: ScoreRingSize.small)),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 28.0);
        expect(sizedBox.height, 28.0);
      });

      testWidgets('medium size renders correctly', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ScoreRing(score: 50, size: ScoreRingSize.medium)),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 32.0);
        expect(sizedBox.height, 32.0);
      });

      testWidgets('large size renders correctly', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ScoreRing(score: 50, size: ScoreRingSize.large)),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 40.0);
        expect(sizedBox.height, 40.0);
      });

      testWidgets('extraLarge size renders correctly', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const ScoreRing(score: 50, size: ScoreRingSize.extraLarge),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 48.0);
        expect(sizedBox.height, 48.0);
      });
    });
  });

  group('ScoreRingSize', () {
    test('small has correct properties', () {
      expect(ScoreRingSize.small.dimension, 28.0);
      expect(ScoreRingSize.small.strokeWidth, 2.5);
      expect(ScoreRingSize.small.fontSize, 9.0);
    });

    test('medium has correct properties', () {
      expect(ScoreRingSize.medium.dimension, 32.0);
      expect(ScoreRingSize.medium.strokeWidth, 3.0);
      expect(ScoreRingSize.medium.fontSize, 10.0);
    });

    test('large has correct properties', () {
      expect(ScoreRingSize.large.dimension, 40.0);
      expect(ScoreRingSize.large.strokeWidth, 3.5);
      expect(ScoreRingSize.large.fontSize, 12.0);
    });

    test('extraLarge has correct properties', () {
      expect(ScoreRingSize.extraLarge.dimension, 48.0);
      expect(ScoreRingSize.extraLarge.strokeWidth, 4.0);
      expect(ScoreRingSize.extraLarge.fontSize, 14.0);
    });
  });
}
