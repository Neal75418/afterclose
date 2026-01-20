import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/main.dart';

void main() {
  testWidgets('App renders with navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AfterCloseApp()));

    // Check app title
    expect(find.text('AfterClose'), findsOneWidget);

    // Check bottom navigation destinations
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('掃描'), findsOneWidget);
    expect(find.text('自選'), findsOneWidget);
    expect(find.text('新聞'), findsOneWidget);
  });
}
