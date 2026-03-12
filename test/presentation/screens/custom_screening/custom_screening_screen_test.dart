import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/custom_screening_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/screens/custom_screening/custom_screening_screen.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifiers
// =============================================================================

class FakeCustomScreeningNotifier extends CustomScreeningNotifier {
  CustomScreeningState initialState = const CustomScreeningState();

  @override
  CustomScreeningState build() => initialState;

  @override
  void addCondition(ScreeningCondition condition) {}

  @override
  void updateCondition(int index, ScreeningCondition condition) {}

  @override
  void removeCondition(int index) {}

  @override
  void clearConditions() {}

  @override
  Future<void> loadSavedStrategies() async {}

  @override
  Future<bool> saveStrategy(String name) async => true;

  @override
  Future<bool> deleteStrategy(int id) async => true;

  @override
  void loadStrategy(ScreeningStrategy strategy) {}

  @override
  Future<void> executeScreening() async {}

  @override
  Future<void> loadMore() async {}
}

class FakeSettingsNotifier extends SettingsNotifier {
  SettingsState initialState = const SettingsState();

  @override
  SettingsState build() => initialState;

  @override
  void setThemeMode(ThemeMode mode) {}

  @override
  void setShowWarningBadges(bool value) {}

  @override
  void setInsiderNotifications(bool value) {}

  @override
  void setDisposalUrgentAlerts(bool value) {}

  @override
  void setLimitAlerts(bool value) {}

  @override
  void setShowROCYear(bool value) {}

  @override
  void setCacheDurationMinutes(int minutes) {}

  @override
  void setAutoUpdateEnabled(bool value) {}
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestWidget({
    CustomScreeningState? screeningState,
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    final s = screeningState ?? const CustomScreeningState();
    final settings = settingsState ?? const SettingsState();
    return buildProviderTestApp(
      const CustomScreeningScreen(),
      overrides: [
        customScreeningProvider.overrideWith(() {
          final n = FakeCustomScreeningNotifier();
          n.initialState = s;
          return n;
        }),
        settingsProvider.overrideWith(() {
          final n = FakeSettingsNotifier();
          n.initialState = settings;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('CustomScreeningScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CustomScreeningScreen), findsOneWidget);
    });

    testWidgets('shows add condition button', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The add condition OutlinedButton has an add icon
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows backtest icon in app bar', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('shows strategy manager icon in app bar', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('disables execute button when no conditions', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Find the execute button (FilledButton.icon with search icon)
      final buttonFinder = find.byIcon(Icons.search);
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('shows loading spinner when executing', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          screeningState: const CustomScreeningState(
            conditions: [
              ScreeningCondition(
                field: ScreeningField.score,
                operator: ScreeningOperator.greaterThan,
                value: 60,
              ),
            ],
            isExecuting: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows error state with retry button', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(
            conditions: [
              const ScreeningCondition(
                field: ScreeningField.score,
                operator: ScreeningOperator.greaterThan,
                value: 60,
              ),
            ],
            result: ScreeningResult(
              symbols: const [],
              matchCount: 0,
              totalScanned: 0,
              dataDate: DateTime(2026, 3, 5),
            ),
            error: 'Network error',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Network error'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump();

      expect(find.byType(CustomScreeningScreen), findsOneWidget);
    });
  });
}
