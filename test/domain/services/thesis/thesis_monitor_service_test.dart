// ThesisMonitorService 測試 — 每日更新後的失效檢查（真 in-memory DB）
//
// 驗證 spec §5：全量重算冪等、INVALIDATED 凍結（只掃 ACTIVE）、
// lastCheckedDate 必更新、觸發日 = 首個滿足日的資料日。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/thesis/thesis_monitor_service.dart';

void main() {
  late AppDatabase db;
  late ThesisMonitorService service;

  final pinnedDate = DateTime(2026, 1, 5);

  setUp(() async {
    db = AppDatabase.forTesting();
    service = ThesisMonitorService(database: db);
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  /// 從釘選日起 seed [days] 天收盤（工作日連續、值由 [closeAt] 決定）
  Future<void> seedCloses(int days, double Function(int i) closeAt) async {
    await db.insertPrices([
      for (var i = 0; i < days; i++)
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: pinnedDate.add(Duration(days: i)),
          close: Value(closeAt(i)),
          volume: const Value(1000000),
        ),
    ]);
  }

  Future<int> pin() => db.pinThesis(
    symbol: '2330',
    pinnedDate: pinnedDate,
    referencePrice: 100.0,
    mode: 'pullback',
    triggeredRules: '[]',
    scoreShort: 20,
    scoreLong: 30,
  );

  test('40 列未實現 → INVALIDATED(timeStop)、觸發日 = 第 40 列資料日', () async {
    await seedCloses(45, (_) => 100.0); // 從未 > ref
    await pin();

    final invalidated = await service.checkActiveTheses(
      asOf: pinnedDate.add(const Duration(days: 44)),
    );
    expect(invalidated, 1);

    final row = (await db.getThesesByStatus('INVALIDATED')).single;
    expect(row.invalidatedReason, 'timeStop');
    expect(row.invalidatedDate, pinnedDate.add(const Duration(days: 40)));
    expect(row.lastCheckedDate, isNotNull);
  });

  test('論點實現（曾收高於 ref）→ 維持 ACTIVE、lastChecked 仍更新', () async {
    await seedCloses(45, (i) => i == 10 ? 101.0 : 100.0);
    await pin();

    final invalidated = await service.checkActiveTheses(
      asOf: pinnedDate.add(const Duration(days: 44)),
    );
    expect(invalidated, 0);

    final row = (await db.getActiveTheses()).single;
    expect(row.status, 'ACTIVE');
    expect(row.lastCheckedDate, isNotNull);
  });

  test('冪等：重跑不改變 INVALIDATED 的凍結欄位', () async {
    await seedCloses(45, (_) => 100.0);
    await pin();
    await service.checkActiveTheses(
      asOf: pinnedDate.add(const Duration(days: 44)),
    );
    final first = (await db.getThesesByStatus('INVALIDATED')).single;

    // 第二次跑（模擬隔日更新）：只掃 ACTIVE → 已失效者不動
    final second = await service.checkActiveTheses(
      asOf: pinnedDate.add(const Duration(days: 45)),
    );
    expect(second, 0);
    final after = (await db.getThesesByStatus('INVALIDATED')).single;
    expect(after.invalidatedDate, first.invalidatedDate);
    expect(after.updatedAt, first.updatedAt);
  });

  test('資料不足（< 40 列）→ 倒數中、維持 ACTIVE', () async {
    await seedCloses(20, (_) => 100.0);
    await pin();
    final invalidated = await service.checkActiveTheses(
      asOf: pinnedDate.add(const Duration(days: 19)),
    );
    expect(invalidated, 0);
    expect((await db.getActiveTheses()).single.status, 'ACTIVE');
  });
}
