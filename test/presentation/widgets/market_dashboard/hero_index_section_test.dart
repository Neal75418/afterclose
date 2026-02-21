import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  TwseMarketIndex createIndex({
    double close = 22000.50,
    double change = 150.25,
    double changePercent = 0.69,
  }) {
    return TwseMarketIndex(
      date: DateTime(2026, 2, 15),
      name: '發行量加權股價指數',
      close: close,
      change: change,
      changePercent: changePercent,
    );
  }

  group('HeroIndexSection', () {
    testWidgets('displays formatted close price', (tester) async {
      await tester.pumpWidget(
        buildTestApp(HeroIndexSection(taiex: createIndex())),
      );

      // 22,000.50 should be displayed
      expect(find.text('22,000.50'), findsOneWidget);
    });

    testWidgets('shows positive sign for up market', (tester) async {
      await tester.pumpWidget(
        buildTestApp(HeroIndexSection(taiex: createIndex(change: 150.25))),
      );

      // +150.25 formatted
      expect(find.text('+150.25'), findsOneWidget);
    });

    testWidgets('shows no sign for down market', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          HeroIndexSection(
            taiex: createIndex(change: -80.10, changePercent: -0.36),
          ),
        ),
      );

      expect(find.text('-80.10'), findsOneWidget);
    });

    testWidgets('hides sparkline when history has < 2 points', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          HeroIndexSection(taiex: createIndex(), historyData: const [22000]),
        ),
      );

      // MiniTrendChart should not be rendered
      expect(find.byType(HeroIndexSection), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          HeroIndexSection(taiex: createIndex()),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(HeroIndexSection), findsOneWidget);
    });
  });
}
