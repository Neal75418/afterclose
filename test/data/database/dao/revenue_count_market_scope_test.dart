// 營收「已快取」判斷的市場範圍 — P1-10
//
// fundamental_repository 的全市場營收同步只抓**上市**
// （`_twse.getAllMonthlyRevenue()`），卻用 `getRevenueCountForYearMonth`
// 數**全市場**的筆數來判斷「該月抓齊了沒」。上櫃營收由另一條流程
// （syncOtcCandidatesFundamentals）寫入，會被算進這個判斷。
//
// 實測 2026/06：全市場 1,316 筆 = 上市 1,067 + 上櫃 249。門檻 1,000。
// 也就是說「上市抓齊了沒」這個判斷有**四分之一的依據來自上櫃**，而上市
// 自身只有 6.7% 餘裕。若某次同步只落地 940 筆上市，加上上櫃 249 = 1,189
// 仍 > 1,000 → 判定已快取而跳過，該月上市就永久少 12%，且不會再被補。
//
// 目前無症狀（上市 1,067 自己就過門檻），屬結構性脆弱。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      for (var i = 0; i < 3; i++)
        StockMasterCompanion.insert(
          symbol: 'T$i',
          name: '上市$i',
          market: 'TWSE',
        ),
      for (var i = 0; i < 5; i++)
        StockMasterCompanion.insert(
          symbol: 'O$i',
          name: '上櫃$i',
          market: 'TPEx',
        ),
    ]);

    await db.insertMonthlyRevenue([
      for (var i = 0; i < 3; i++)
        MonthlyRevenueCompanion.insert(
          symbol: 'T$i',
          date: DateTime(2026, 6),
          revenueYear: 2026,
          revenueMonth: 6,
          revenue: 100000,
          momGrowth: const Value(null),
          yoyGrowth: const Value(null),
        ),
      for (var i = 0; i < 5; i++)
        MonthlyRevenueCompanion.insert(
          symbol: 'O$i',
          date: DateTime(2026, 6),
          revenueYear: 2026,
          revenueMonth: 6,
          revenue: 100000,
          momGrowth: const Value(null),
          yoyGrowth: const Value(null),
        ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test('🚨 限定市場時只數該市場的筆數', () async {
    expect(
      await db.getRevenueCountForYearMonth(2026, 6, market: 'TWSE'),
      3,
      reason: '判斷「上市抓齊了沒」不得把上櫃的筆數算進來',
    );
    expect(await db.getRevenueCountForYearMonth(2026, 6, market: 'TPEx'), 5);
  });

  test('不指定市場時維持全市場計數（向後相容）', () async {
    expect(await db.getRevenueCountForYearMonth(2026, 6), 8);
  });

  test('其他月份不受影響', () async {
    expect(await db.getRevenueCountForYearMonth(2026, 5, market: 'TWSE'), 0);
  });
}
