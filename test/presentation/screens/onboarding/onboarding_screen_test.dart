import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/presentation/screens/onboarding/onboarding_screen.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('OnboardingScreen', () {
    testWidgets('renders 3-page PageView', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('shows first page icons', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('shows page indicators', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      // 3 page indicators (AnimatedContainer)
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('has exactly 3 AnimatedContainer indicators', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      // 3 dot indicators
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('shows SafeArea', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('shows skip button', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('shows tonal next button on first page', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestApp(const OnboardingScreen()));
      await tester.pump();

      // On first page, button is FilledButton.tonal (not FilledButton)
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const OnboardingScreen(), brightness: Brightness.dark),
      );
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
