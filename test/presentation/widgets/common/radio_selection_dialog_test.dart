import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/common/radio_selection_dialog.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('RadioSelectionDialog', () {
    testWidgets('displays title and all options', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<String>(
            title: 'Pick Color',
            options: const ['Red', 'Blue', 'Green'],
            currentValue: 'Red',
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Pick Color'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);
    });

    testWidgets('shows checked icon for current value', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<String>(
            title: 'Pick',
            options: const ['A', 'B'],
            currentValue: 'A',
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off), findsOneWidget);
    });

    testWidgets('calls onSelected with tapped option', (tester) async {
      String? selected;
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<String>(
            title: 'Pick',
            options: const ['A', 'B'],
            currentValue: 'A',
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      expect(selected, 'B');
    });

    testWidgets('uses labelBuilder for display text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<int>(
            title: 'Number',
            options: const [1, 2, 3],
            currentValue: 1,
            onSelected: (_) {},
            labelBuilder: (n) => 'Item $n',
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('renders trailingBuilder widgets', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<String>(
            title: 'Color',
            options: const ['Red'],
            currentValue: 'Red',
            onSelected: (_) {},
            trailingBuilder: (_) => const Icon(Icons.star),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('falls back to toString when no labelBuilder', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          RadioSelectionDialog<int>(
            title: 'Number',
            options: const [42],
            currentValue: 42,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });
  });
}
