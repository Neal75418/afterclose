// PinnedThesisSection widget 測試 — 追蹤區與警示模式（真 in-memory DB）
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/exit_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/widgets/pinned_thesis_section.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
    await db.insertPrices([
      DailyPriceCompanion.insert(
        symbol: '2330',
        date: DateTime(2026, 7, 10),
        close: const Value(1005.0),
        volume: const Value(30000000),
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: buildTestApp(SingleChildScrollView(child: child)),
  );

  Future<int> pin() => db.pinThesis(
    symbol: '2330',
    pinnedDate: DateTime(2026, 7, 1),
    referencePrice: 1000.0,
    mode: 'strength',
    triggeredRules: '[]',
    scoreShort: 20,
    scoreLong: 30,
  );

  testWidgets('空狀態 → 零渲染（無標題）', (tester) async {
    await tester.pumpWidget(wrap(const PinnedThesisSection()));
    await tester.pumpAndSettle();
    expect(find.textContaining('thesis.sectionTitle'), findsNothing);
  });

  testWidgets('僅 ACTIVE → 預設收合成一行 strip、點擊展開後可取消', (tester) async {
    await pin();
    await tester.pumpWidget(wrap(const PinnedThesisSection()));
    await tester.pumpAndSettle();

    // 摘要 strip（無失效 → 預設收合、卡片不渲染）
    expect(find.textContaining('thesis.summaryActive'), findsOneWidget);
    expect(find.text('2330'), findsNothing, reason: '平日收合、不佔推薦版面');

    // 點 strip 展開
    await tester.tap(find.textContaining('thesis.summaryActive'));
    await tester.pumpAndSettle();
    expect(find.text('2330'), findsOneWidget);
    expect(find.text('thesis.statusActive'), findsOneWidget);
    expect(find.textContaining('thesis.refVsCurrent'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('2330'), findsNothing, reason: '取消 = 物理刪除、離開追蹤區');
  });

  testWidgets('有失效 → strip 自動展開（事件驅動顯眼度）', (tester) async {
    final id = await pin();
    await db.invalidateThesis(
      id,
      invalidatedDate: DateTime(2026, 7, 10),
      reason: ExitReason.timeStop.name,
    );
    await tester.pumpWidget(wrap(const PinnedThesisSection()));
    await tester.pumpAndSettle();

    expect(find.textContaining('thesis.summaryInvalidated'), findsOneWidget);
    expect(find.text('2330'), findsOneWidget, reason: '失效 = 稀有關鍵事件、無需點擊即可見');
  });

  testWidgets('invalidatedOnly：只列 INVALIDATED、封存後離開', (tester) async {
    final id = await pin();
    await db.invalidateThesis(
      id,
      invalidatedDate: DateTime(2026, 7, 10),
      reason: ExitReason.timeStop.name,
    );

    await tester.pumpWidget(
      wrap(const PinnedThesisSection(invalidatedOnly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('thesis.alertSectionTitle'), findsOneWidget);
    expect(find.textContaining('thesis.statusInvalidated'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();
    expect(find.text('2330'), findsNothing, reason: '封存後離開警示 section');
  });
}
