import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/custom_screening_provider.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/strategy_manager_sheet.dart';

import '../../../../helpers/provider_test_helpers.dart';
import '../../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeCustomScreeningNotifier extends CustomScreeningNotifier {
  CustomScreeningState initialState = const CustomScreeningState();

  @override
  CustomScreeningState build() => initialState;

  @override
  Future<void> loadSavedStrategies() async {}

  @override
  void addCondition(ScreeningCondition condition) {}

  @override
  void updateCondition(int index, ScreeningCondition condition) {}

  @override
  void removeCondition(int index) {}

  @override
  void clearConditions() {}

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

  late CustomScreeningState _screeningState;

  Widget buildTestWidget({
    CustomScreeningState? screeningState,
    Brightness brightness = Brightness.light,
  }) {
    _screeningState = screeningState ?? const CustomScreeningState();
    return buildProviderTestApp(
      const StrategyManagerSheet(),
      overrides: [
        customScreeningProvider.overrideWith(() {
          final n = FakeCustomScreeningNotifier();
          n.initialState = _screeningState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('StrategyManagerSheet', () {
    testWidgets('shows title text', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StrategyManagerSheet), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: const CustomScreeningState(isLoadingStrategies: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no strategies', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // No ListTile (strategies) expected
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('shows strategy list with names', (tester) async {
      widenViewport(tester);
      final strategies = [
        ScreeningStrategy(
          id: 1,
          name: 'Growth Picks',
          conditions: [
            const ScreeningCondition(
              field: ScreeningField.pe,
              operator: ScreeningOperator.lessThan,
              value: 20,
            ),
          ],
        ),
        ScreeningStrategy(
          id: 2,
          name: 'Value Stocks',
          conditions: [
            const ScreeningCondition(
              field: ScreeningField.pbr,
              operator: ScreeningOperator.lessThan,
              value: 1.5,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(savedStrategies: strategies),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('Growth Picks'), findsOneWidget);
      expect(find.text('Value Stocks'), findsOneWidget);
    });

    testWidgets('shows delete icon on strategy tiles', (tester) async {
      widenViewport(tester);
      final strategies = [
        ScreeningStrategy(
          id: 1,
          name: 'My Strategy',
          conditions: [
            const ScreeningCondition(
              field: ScreeningField.score,
              operator: ScreeningOperator.greaterOrEqual,
              value: 80,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(savedStrategies: strategies),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows save button when conditions exist', (tester) async {
      widenViewport(tester);
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.pe,
          operator: ScreeningOperator.lessThan,
          value: 15,
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(conditions: conditions),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('hides save button when no conditions', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.save), findsNothing);
    });

    testWidgets('tapping save shows text field', (tester) async {
      widenViewport(tester);
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.pe,
          operator: ScreeningOperator.lessThan,
          value: 15,
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(conditions: conditions),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap save icon button
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // TextField for strategy name should appear
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows divider separator', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Divider), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping delete icon shows confirmation dialog', (
      tester,
    ) async {
      widenViewport(tester);
      final strategies = [
        ScreeningStrategy(
          id: 1,
          name: 'Delete Me',
          conditions: [
            const ScreeningCondition(
              field: ScreeningField.close,
              operator: ScreeningOperator.greaterThan,
              value: 100,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(savedStrategies: strategies),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final strategies = [
        ScreeningStrategy(
          id: 1,
          name: 'Dark Strategy',
          conditions: [
            const ScreeningCondition(
              field: ScreeningField.pe,
              operator: ScreeningOperator.lessThan,
              value: 20,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        buildTestWidget(
          screeningState: CustomScreeningState(savedStrategies: strategies),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StrategyManagerSheet), findsOneWidget);
      expect(find.text('Dark Strategy'), findsOneWidget);
    });
  });
}
