import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('ChipStrengthIndicator', () {
    testWidgets('displays battery icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const ChipStrengthIndicator(
            strength: ChipStrengthResult(
              score: 75,
              rating: ChipRating.strong,
              attitude: InstitutionalAttitude.aggressiveBuy,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.battery_charging_full), findsOneWidget);
    });

    testWidgets('displays score value', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const ChipStrengthIndicator(
            strength: ChipStrengthResult(
              score: 85,
              rating: ChipRating.strong,
              attitude: InstitutionalAttitude.aggressiveBuy,
            ),
          ),
        ),
      );

      expect(find.text('85'), findsOneWidget);
      expect(find.text(' / 100'), findsOneWidget);
    });

    testWidgets('renders with weak rating', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const ChipStrengthIndicator(
            strength: ChipStrengthResult(
              score: 5,
              rating: ChipRating.weak,
              attitude: InstitutionalAttitude.aggressiveSell,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders with neutral rating', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const ChipStrengthIndicator(
            strength: ChipStrengthResult(
              score: 40,
              rating: ChipRating.neutral,
              attitude: InstitutionalAttitude.neutral,
            ),
          ),
        ),
      );

      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const ChipStrengthIndicator(
            strength: ChipStrengthResult(
              score: 60,
              rating: ChipRating.bullish,
              attitude: InstitutionalAttitude.moderateBuy,
            ),
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ChipStrengthIndicator), findsOneWidget);
    });
  });
}
