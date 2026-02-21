import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sub_indices_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  TwseMarketIndex createIndex({
    String name = '電子類指數',
    double close = 800.0,
    double change = 5.0,
    double changePercent = 0.63,
  }) {
    return TwseMarketIndex(
      date: DateTime(2026, 2, 14),
      name: name,
      close: close,
      change: change,
      changePercent: changePercent,
    );
  }

  group('SubIndicesRow', () {
    testWidgets('returns SizedBox.shrink when empty', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const SubIndicesRow(subIndices: [])),
      );

      expect(find.byType(SubIndicesRow), findsOneWidget);
    });

    testWidgets('displays index cards', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SubIndicesRow(
            subIndices: [
              createIndex(name: '電子類指數', close: 800, change: 5),
              createIndex(name: '金融保險類指數', close: 1500, change: -10),
            ],
          ),
        ),
      );

      expect(find.text('800.00'), findsOneWidget);
      expect(find.text('1500.00'), findsOneWidget);
    });

    testWidgets('shows up arrow for positive change', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SubIndicesRow(
            subIndices: [createIndex(change: 5, changePercent: 0.63)],
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('+0.63%'), findsOneWidget);
    });

    testWidgets('shows down arrow for negative change', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SubIndicesRow(
            subIndices: [createIndex(change: -5, changePercent: -0.63)],
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text('-0.63%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SubIndicesRow(subIndices: [createIndex()]),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(SubIndicesRow), findsOneWidget);
    });
  });
}
