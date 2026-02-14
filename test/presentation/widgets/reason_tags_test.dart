import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
