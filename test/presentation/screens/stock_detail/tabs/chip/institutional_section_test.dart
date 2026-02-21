import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/institutional_section.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  DailyInstitutionalEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? foreignNet = 500,
    double? investmentTrustNet = 200,
    double? dealerNet = -100,
  }) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      foreignNet: foreignNet,
      investmentTrustNet: investmentTrustNet,
      dealerNet: dealerNet,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpSection(
    WidgetTester tester,
    Widget widget, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(buildTestApp(widget, brightness: brightness));
    await tester.pump(const Duration(seconds: 1));
  }

  group('InstitutionalSection', () {
    testWidgets('displays business icon', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, InstitutionalSection(history: [createEntry()]));

      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const InstitutionalSection(history: []));

      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('displays summary cards with data', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InstitutionalSection(
          history: [
            createEntry(
              foreignNet: 1000,
              investmentTrustNet: 500,
              dealerNet: -200,
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.store), findsOneWidget);
    });

    testWidgets('renders table with multiple entries', (tester) async {
      widenViewport(tester);
      final entries = List.generate(
        5,
        (i) => createEntry(
          date: DateTime(2026, 2, 10 + i),
          foreignNet: (100 + i * 50).toDouble(),
        ),
      );

      await pumpSection(tester, InstitutionalSection(history: entries));

      expect(find.byType(InstitutionalSection), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InstitutionalSection(history: [createEntry()]),
        brightness: Brightness.dark,
      );

      expect(find.byType(InstitutionalSection), findsOneWidget);
    });
  });
}
