// getPriceCoverageBatch — 價格覆蓋聚合（真 in-memory DB）
//
// 歷史需求掃描的 aggregate 讀取模型。核心保證：對同一批資料，
// coverage 必須與「getPriceHistoryBatch 整包載入後在 Dart 端聚合」
// 完全等價（count / 首末日含 == 語意 / 每月分佈）——掃描邏輯的四個
// 消費者只依賴這些聚合值。
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
      StockMasterCompanion.insert(symbol: '8069', name: '元太', market: 'TPEx'),
      StockMasterCompanion.insert(symbol: '1301', name: '台塑', market: 'TWSE'),
    ]);

    // 2330：跨三個月、含窗邊界；8069：單月兩筆；1301：窗外資料（不得入計）
    for (final d in [
      DateTime(2026, 5, 4),
      DateTime(2026, 5, 5),
      DateTime(2026, 6, 30),
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 14),
    ]) {
      await insertPrice('2330', d);
    }
    await insertPrice('8069', DateTime(2026, 7, 7));
    await insertPrice('8069', DateTime(2026, 7, 8));
    await insertPrice('1301', DateTime(2026, 4, 30)); // 窗外
  });

  tearDown(() async {
    await db.close();
  });

  final windowStart = DateTime(2026, 5, 1);
  final windowEnd = DateTime(2026, 7, 14);

  test('count / 首末日 / 每月分佈正確；窗外資料與無資料 symbol 不入計', () async {
    final coverage = await db.getPriceCoverageBatch(
      ['2330', '8069', '1301'],
      startDate: windowStart,
      endDate: windowEnd,
    );

    final tsmc = coverage['2330']!;
    expect(tsmc.count, 5);
    expect(tsmc.firstDate, DateTime(2026, 5, 4));
    expect(tsmc.lastDate, DateTime(2026, 7, 14));
    expect(tsmc.daysByMonth, {(2026, 5): 2, (2026, 6): 1, (2026, 7): 2});

    expect(coverage['8069']!.count, 2);
    expect(coverage['8069']!.daysByMonth, {(2026, 7): 2});

    // 1301 只有窗外資料 → 不在 Map
    expect(coverage.containsKey('1301'), isFalse);
  });

  test('與 getPriceHistoryBatch 整包載入後聚合完全等價', () async {
    final coverage = await db.getPriceCoverageBatch(
      ['2330', '8069', '1301'],
      startDate: windowStart,
      endDate: windowEnd,
    );
    final batch = await db.getPriceHistoryBatch(
      ['2330', '8069', '1301'],
      startDate: windowStart,
      endDate: windowEnd,
    );

    expect(coverage.keys.toSet(), batch.keys.toSet());
    for (final symbol in batch.keys) {
      final prices = batch[symbol]!;
      final cov = coverage[symbol]!;
      expect(cov.count, prices.length, reason: '$symbol count');
      expect(cov.firstDate, prices.first.date, reason: '$symbol first');
      expect(cov.lastDate, prices.last.date, reason: '$symbol last');
      final months = <(int, int), int>{};
      for (final p in prices) {
        final key = (p.date.year, p.date.month);
        months[key] = (months[key] ?? 0) + 1;
      }
      expect(cov.daysByMonth, months, reason: '$symbol daysByMonth');
    }
  });

  test('未請求的 symbol 不回傳；空 symbols 回空 Map', () async {
    final coverage = await db.getPriceCoverageBatch(
      ['2330'],
      startDate: windowStart,
      endDate: windowEnd,
    );
    expect(coverage.keys, ['2330']);

    expect(
      await db.getPriceCoverageBatch(
        [],
        startDate: windowStart,
        endDate: windowEnd,
      ),
      isEmpty,
    );
  });
}
