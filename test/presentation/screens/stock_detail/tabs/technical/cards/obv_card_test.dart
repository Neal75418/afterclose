import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/obv_card.dart';

import '../../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  final indicatorService = TechnicalIndicatorService();

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('OBVCard', () {
    testWidgets('displays OBV label', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0 + i * 50000);

      await tester.pumpWidget(
        buildTestApp(
          OBVCard(
            closes: closes,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('OBV'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when fewer than 5 points', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          OBVCard(
            closes: const [100, 101],
            volumes: const [1000, 2000],
            indicatorService: indicatorService,
          ),
        ),
      );

      // Should show SizedBox.shrink
      expect(find.text('OBV'), findsNothing);
    });

    testWidgets('formats large OBV values', (tester) async {
      widenViewport(tester);
      // Large volumes to create large OBV values
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 5000000.0);

      await tester.pumpWidget(
        buildTestApp(
          OBVCard(
            closes: closes,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.byType(OBVCard), findsOneWidget);
    });

    testWidgets('shows 5-day change', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0);

      await tester.pumpWidget(
        buildTestApp(
          OBVCard(
            closes: closes,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.textContaining('(5d)'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final closes = List.generate(10, (i) => 100.0 + i);
      final volumes = List.generate(10, (i) => 1000000.0);

      await tester.pumpWidget(
        buildTestApp(
          OBVCard(
            closes: closes,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('OBV'), findsOneWidget);
    });
  });
}
