import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/common/drag_handle.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('DragHandle', () {
    testWidgets('renders a centered container', (tester) async {
      await tester.pumpWidget(buildTestApp(const DragHandle()));

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 4);
    });

    testWidgets('uses default top margin of 12', (tester) async {
      await tester.pumpWidget(buildTestApp(const DragHandle()));

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.margin, const EdgeInsets.only(top: 12));
    });

    testWidgets('accepts custom margin', (tester) async {
      const customMargin = EdgeInsets.symmetric(vertical: 8);
      await tester.pumpWidget(
        buildTestApp(const DragHandle(margin: customMargin)),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.margin, customMargin);
    });

    testWidgets('renders in dark mode without error', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const DragHandle(), brightness: Brightness.dark),
      );

      expect(find.byType(DragHandle), findsOneWidget);
    });
  });
}
