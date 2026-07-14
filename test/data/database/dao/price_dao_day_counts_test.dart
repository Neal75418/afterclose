// getPriceCountsByDayAndMarket — 各（日, 市場）價格筆數聚合（真 in-memory DB）
//
// phase-0 缺漏掃描用：一次 GROUP BY 取代逐 (日, 市場) 的
// countPricesByDateAndMarket。核心保證：對同一批資料，兩者逐格等價。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  Future<void> insertPrice(String symbol, DateTime date) => db.insertPrices([
    DailyPriceCompanion.insert(
      symbol: symbol,
      date: date,
      close: const Value(100),
      volume: const Value(1000),
    ),
  ]);

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '8069', name: '元太', market: 'TPEx'),
    ]);

    // 7/13：上市兩檔 + 上櫃一檔；7/14：僅上市一檔；7/10：窗外
    await insertPrice('2330', DateTime(2026, 7, 13));
    await insertPrice('2317', DateTime(2026, 7, 13));
    await insertPrice('8069', DateTime(2026, 7, 13));
    await insertPrice('2330', DateTime(2026, 7, 14));
    await insertPrice('2330', DateTime(2026, 7, 10));
  });

  tearDown(() async {
    await db.close();
  });

  final windowStart = DateTime(2026, 7, 11);
  final windowEnd = DateTime(2026, 7, 14);

  test('market → 日 → 筆數正確；窗外與零筆組不出現', () async {
    final counts = await db.getPriceCountsByDayAndMarket(
      startDate: windowStart,
      endDate: windowEnd,
    );

    expect(counts['TWSE'], {'2026-07-13': 2, '2026-07-14': 1});
    expect(counts['TPEx'], {'2026-07-13': 1});
    // 7/10 在窗外、7/14 上櫃無資料 → 缺鍵（caller 以 ?? 0 處理）
    expect(counts['TPEx']!.containsKey('2026-07-14'), isFalse);
  });

  test('與逐 (日, 市場) 的 countPricesByDateAndMarket 逐格等價', () async {
    final counts = await db.getPriceCountsByDayAndMarket(
      startDate: windowStart,
      endDate: windowEnd,
    );

    for (final market in ['TWSE', 'TPEx']) {
      for (
        var day = windowStart;
        !day.isAfter(windowEnd);
        day = day.add(const Duration(days: 1))
      ) {
        final single = await db.countPricesByDateAndMarket(day, market);
        final key =
            '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        final grouped = counts[market]?[key] ?? 0;
        expect(grouped, single, reason: '$market $key 逐格等價');
      }
    }
  });
}
