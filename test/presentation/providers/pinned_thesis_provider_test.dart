// PinnedThesisNotifier 測試 — 釘選快照與生命週期（真 in-memory DB）
//
// 驗證：
//   1. pin() 快照：pinnedDate = 該股最新分析資料日、referencePrice = 當日
//      收盤、mode 未指定時取觸發規則的 dominant scoringMode
//   2. 重複釘選 → 拋 StateError（UI 層擋、DB 層兜底）
//   3. cancel = 物理刪除；archive = INVALIDATED → ARCHIVED
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/pinned_thesis_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  final dataDate = DateTime(2026, 7, 10);

  setUp(() async {
    db = AppDatabase.forTesting();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
    await db.insertPrices([
      DailyPriceCompanion.insert(
        symbol: '2330',
        date: dataDate,
        close: const Value(1005.0),
        volume: const Value(30000000),
      ),
    ]);
    await db.insertAnalysis(
      DailyAnalysisCompanion.insert(
        symbol: '2330',
        date: dataDate,
        trendState: 'UP',
        reversalState: const Value('NONE'),
        scoreShort: const Value(20.0),
        scoreLong: const Value(35.0),
        computedAt: Value(dataDate),
      ),
    );
    // 觸發規則：pullback 主訊號（weaknessObserve）分數最高 → dominant mode
    await db.insertReasons([
      DailyReasonCompanion.insert(
        symbol: '2330',
        date: dataDate,
        rank: 1,
        reasonType: 'PULLBACK_TO_MA20',
        evidenceJson: '{}',
        ruleScoreShort: const Value(15.0),
        ruleScoreLong: const Value(15.0),
      ),
      DailyReasonCompanion.insert(
        symbol: '2330',
        date: dataDate,
        rank: 2,
        reasonType: 'REVENUE_YOY_SURGE',
        evidenceJson: '{}',
        ruleScoreShort: const Value(10.0),
        ruleScoreLong: const Value(10.0),
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('pin()：快照最新分析日/收盤/分數，mode 取 dominant scoringMode', () async {
    final notifier = container.read(pinnedThesisProvider.notifier);
    await notifier.pin('2330');

    final state = await container.read(pinnedThesisProvider.future);
    final thesis = state.active.single;
    expect(thesis.symbol, '2330');
    expect(thesis.pinnedDate, dataDate);
    expect(thesis.referencePrice, 1005.0);
    expect(thesis.scoreShort, 20.0);
    expect(thesis.scoreLong, 35.0);
    expect(thesis.mode, 'pullback'); // PULLBACK_TO_MA20 = weaknessObserve 主導
    expect(thesis.triggeredRules, contains('PULLBACK_TO_MA20'));
    // 追蹤卡的現價 join
    expect(state.currentCloses['2330'], 1005.0);
  });

  test('pin() 指定 mode 覆寫 dominant 推斷', () async {
    final notifier = container.read(pinnedThesisProvider.notifier);
    await notifier.pin('2330', mode: 'strength');
    final state = await container.read(pinnedThesisProvider.future);
    expect(state.active.single.mode, 'strength');
  });

  test('重複釘選 → StateError', () async {
    final notifier = container.read(pinnedThesisProvider.notifier);
    await notifier.pin('2330');
    expect(() => notifier.pin('2330'), throwsStateError);
  });

  test('cancel = 物理刪除；archive 需先 INVALIDATED', () async {
    final notifier = container.read(pinnedThesisProvider.notifier);
    await notifier.pin('2330');
    var state = await container.read(pinnedThesisProvider.future);
    final id = state.active.single.id;

    await notifier.cancel(id);
    state = await container.read(pinnedThesisProvider.future);
    expect(state.active, isEmpty);
    expect(state.invalidated, isEmpty);
  });
}
