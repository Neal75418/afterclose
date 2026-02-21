import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/condition_editor_sheet.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('ConditionEditorSheet', () {
    testWidgets('shows add title when no initial condition', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestApp(const ConditionEditorSheet()));

      // Should display add condition title (i18n key as text)
      expect(
        find.textContaining('customScreening.addCondition'),
        findsOneWidget,
      );
    });

    testWidgets('shows edit title when initial condition provided', (
      tester,
    ) async {
      widenViewport(tester);

      const condition = ScreeningCondition(
        field: ScreeningField.close,
        operator: ScreeningOperator.greaterOrEqual,
        value: 100,
      );

      await tester.pumpWidget(
        buildTestApp(const ConditionEditorSheet(initial: condition)),
      );

      expect(
        find.textContaining('customScreening.editCondition'),
        findsOneWidget,
      );
    });

    testWidgets('displays category chips', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestApp(const ConditionEditorSheet()));

      // Should show category step label
      expect(
        find.textContaining('customScreening.stepCategory'),
        findsOneWidget,
      );
      // Should show ChoiceChips for each ScreeningCategory
      expect(find.byType(ChoiceChip), findsAtLeastNWidgets(5));
    });

    testWidgets('shows field chips after selecting category', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestApp(const ConditionEditorSheet()));

      // Tap the first category chip (price)
      final chips = find.byType(ChoiceChip);
      await tester.tap(chips.first);
      await tester.pumpAndSettle();

      // Should now show field step label
      expect(find.textContaining('customScreening.stepField'), findsOneWidget);
    });

    testWidgets('pre-populates fields from initial condition', (tester) async {
      widenViewport(tester);

      const condition = ScreeningCondition(
        field: ScreeningField.close,
        operator: ScreeningOperator.greaterOrEqual,
        value: 100,
      );

      await tester.pumpWidget(
        buildTestApp(const ConditionEditorSheet(initial: condition)),
      );

      // Should show value step (field is pre-selected)
      expect(find.textContaining('customScreening.stepValue'), findsOneWidget);
      // FilledButton should be present for confirm
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestApp(const ConditionEditorSheet(), brightness: Brightness.dark),
      );

      expect(
        find.textContaining('customScreening.addCondition'),
        findsOneWidget,
      );
    });
  });
}
