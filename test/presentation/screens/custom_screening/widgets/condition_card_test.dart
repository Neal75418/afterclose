import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/condition_card.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  ScreeningCondition createCondition({
    ScreeningField field = ScreeningField.close,
    ScreeningOperator operator = ScreeningOperator.greaterOrEqual,
    double? value,
    double? valueTo,
    String? stringValue,
  }) {
    return ScreeningCondition(
      field: field,
      operator: operator,
      value: value,
      valueTo: valueTo,
      stringValue: stringValue,
    );
  }

  group('ConditionCard', () {
    testWidgets('displays category icon for price field', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(field: ScreeningField.close, value: 100),
            index: 0,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );

      // price category -> Icons.trending_up
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('displays category icon for volume field', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(
              field: ScreeningField.volume,
              value: 5000,
            ),
            index: 0,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );

      // volume category -> Icons.bar_chart
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('displays category icon for technical field', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(field: ScreeningField.rsi14, value: 70),
            index: 0,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );

      // technical category -> Icons.show_chart
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('displays category icon for fundamental field', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(field: ScreeningField.pe, value: 15),
            index: 0,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );

      // fundamental category -> Icons.account_balance
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
    });

    testWidgets('has close button that calls onDelete', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(value: 100),
            index: 0,
            onEdit: () {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(deleted, isTrue);
    });

    testWidgets('tapping tile calls onEdit', (tester) async {
      bool edited = false;
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(value: 100),
            index: 0,
            onEdit: () => edited = true,
            onDelete: () {},
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(edited, isTrue);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ConditionCard(
            condition: createCondition(value: 50),
            index: 0,
            onEdit: () {},
            onDelete: () {},
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ConditionCard), findsOneWidget);
    });
  });
}
