import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/watchlist/watchlist_group_header.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('WatchlistGroupHeader', () {
    testWidgets('displays icon, title, and count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WatchlistGroupHeader(icon: '⭐', title: '自選股', count: 5),
        ),
      );

      expect(find.text('⭐'), findsOneWidget);
      expect(find.text('自選股'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('displays zero count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const WatchlistGroupHeader(icon: '📊', title: '觀察', count: 0),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });
}
