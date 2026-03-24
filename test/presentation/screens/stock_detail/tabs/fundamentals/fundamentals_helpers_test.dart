import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  group('buildLoadingState', () {
    testWidgets('contains CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        buildTestApp(Builder(builder: (context) => buildLoadingState(context))),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('buildEmptyState', () {
    testWidgets('displays message text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(builder: (context) => buildEmptyState(context, '無資料')),
        ),
      );

      expect(find.text('無資料'), findsOneWidget);
    });
  });

  group('getRowColor', () {
    testWidgets('index 0 returns primaryContainer tint', (tester) async {
      late Color? color;
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              color = getRowColor(context, 0);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(color, isNotNull);
    });

    testWidgets('odd index returns transparent', (tester) async {
      late Color? color;
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              color = getRowColor(context, 1);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(color, Colors.transparent);
    });
  });

  group('buildTableHeader', () {
    testWidgets('renders columns in a Row', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => buildTableHeader(context, [
              const Text('Col A'),
              const Text('Col B'),
            ]),
          ),
        ),
      );

      expect(find.text('Col A'), findsOneWidget);
      expect(find.text('Col B'), findsOneWidget);
    });
  });
}
