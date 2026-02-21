import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/share_options_sheet.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('ShareOptionsSheet', () {
    testWidgets('displays both options by default', (tester) async {
      await tester.pumpWidget(buildTestApp(const ShareOptionsSheet()));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
    });

    testWidgets('hides PNG option when showPng is false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ShareOptionsSheet(showPng: false)),
      );

      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
    });

    testWidgets('hides CSV option when showCsv is false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ShareOptionsSheet(showCsv: false)),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsNothing);
    });

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(buildTestApp(const ShareOptionsSheet()));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ShareOptionsSheet(), brightness: Brightness.dark),
      );

      expect(find.byType(ShareOptionsSheet), findsOneWidget);
    });

    testWidgets('tapping PNG option pops with ShareFormat.png', (tester) async {
      ShareFormat? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ShareFormat>(
                    context: context,
                    builder: (_) => const ShareOptionsSheet(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pumpAndSettle();

      expect(result, ShareFormat.png);
    });

    testWidgets('tapping CSV option pops with ShareFormat.csv', (tester) async {
      ShareFormat? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ShareFormat>(
                    context: context,
                    builder: (_) => const ShareOptionsSheet(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.table_chart_outlined));
      await tester.pumpAndSettle();

      expect(result, ShareFormat.csv);
    });

    testWidgets('tapping close button pops with null', (tester) async {
      ShareFormat? result = ShareFormat.png; // sentinel
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ShareFormat>(
                    context: context,
                    builder: (_) => const ShareOptionsSheet(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('ShareFormat', () {
    test('has png and csv values', () {
      expect(ShareFormat.values, hasLength(2));
      expect(ShareFormat.values, contains(ShareFormat.png));
      expect(ShareFormat.values, contains(ShareFormat.csv));
    });
  });
}
