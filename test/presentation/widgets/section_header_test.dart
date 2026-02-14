import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/section_header.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('displays title text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SectionHeader(title: 'Test Section', animate: false),
        ),
      );

      expect(find.text('Test Section'), findsOneWidget);
    });

    testWidgets('displays icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SectionHeader(
            title: 'With Icon',
            icon: Icons.star,
            animate: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('does not display icon when not provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SectionHeader(title: 'No Icon', animate: false)),
      );

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('displays subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SectionHeader(
            title: 'Title',
            subtitle: 'Subtitle text',
            animate: false,
          ),
        ),
      );

      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('does not display subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SectionHeader(title: 'Only Title', animate: false)),
      );

      // 只有標題文字
      expect(find.text('Only Title'), findsOneWidget);
    });

    testWidgets('displays trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SectionHeader(
            title: 'With Action',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
            animate: false,
          ),
        ),
      );

      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('trailing action button is tappable', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          SectionHeader(
            title: 'Action',
            trailing: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Tap me'),
            ),
            animate: false,
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('renders with animation when animate is true', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SectionHeader(title: 'Animated', animate: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Animated'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SectionHeader(title: 'Dark Mode', animate: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
    });
  });
}
