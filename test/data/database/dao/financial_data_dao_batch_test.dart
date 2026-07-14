// getLatestFinancialDataDatesBatch — 批次最新財報日期（真 in-memory DB）
//
// 財報段 freshness 預篩用：一次 GROUP BY 取代逐檔 MAX(date)。
// 驗證與逐檔版 getLatestFinancialDataDate 的等價性。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  Future<void> insertStatement(String symbol, String type, DateTime date) =>
      db.insertFinancialData([
        FinancialDataCompanion.insert(
          symbol: symbol,
          date: date,
          statementType: type,
          dataType: 'EPS',
          value: const Value(1.0),
        ),
      ]);

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '1301', name: '台塑', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test('每檔回傳該 statement type 的最新日期；無資料的 symbol 不在 Map', () async {
    await insertStatement('2330', 'INCOME', DateTime(2025, 12, 31));
    await insertStatement('2330', 'INCOME', DateTime(2026, 3, 31));
    await insertStatement('2317', 'INCOME', DateTime(2025, 9, 30));
    // 1301 無 INCOME；2317 另有 BALANCE 不得混入
    await insertStatement('2317', 'BALANCE', DateTime(2026, 3, 31));

    final result = await db.getLatestFinancialDataDatesBatch([
      '2330',
      '2317',
      '1301',
    ], 'INCOME');

    expect(result['2330'], DateTime(2026, 3, 31));
    expect(result['2317'], DateTime(2025, 9, 30));
    expect(result.containsKey('1301'), isFalse);
  });

  test('與逐檔版 getLatestFinancialDataDate 等價', () async {
    await insertStatement('2330', 'BALANCE', DateTime(2026, 3, 31));
    await insertStatement('2317', 'BALANCE', DateTime(2025, 6, 30));

    final batch = await db.getLatestFinancialDataDatesBatch([
      '2330',
      '2317',
      '1301',
    ], 'BALANCE');

    for (final symbol in ['2330', '2317', '1301']) {
      final single = await db.getLatestFinancialDataDate(symbol, 'BALANCE');
      expect(batch[symbol], single, reason: '$symbol 批次與逐檔結果須一致');
    }
  });

  test('空 symbols 回空 Map（不發查詢）', () async {
    expect(await db.getLatestFinancialDataDatesBatch([], 'INCOME'), isEmpty);
  });
}
