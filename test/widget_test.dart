import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AfterCloseApp()));

    expect(find.text('AfterClose'), findsWidgets);
    expect(find.text('Local-First 盤後台股掃描'), findsOneWidget);
  });
}
