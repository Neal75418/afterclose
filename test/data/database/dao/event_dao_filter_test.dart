import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/database/app_database.dart';

/// getEventsInRange 的 symbols 過濾語意守門。
///
/// 空 list 必須代表「過濾到空集合（只剩無 symbol 的個人備忘）」而非
/// 「不過濾」——否則預設 watchlistOnly 下，空自選的使用者會看到全市場
/// 事件（2026-07-24 審查 Finding 1）。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '9999', name: '路人股', market: 'TWSE'),
    ]);
    await db.insertStockEvent(
      StockEventCompanion.insert(
        symbol: const Value('2330'),
        eventType: 'EX_DIVIDEND',
        eventDate: DateTime(2026, 7, 10),
        title: '2330 除息',
      ),
    );
    await db.insertStockEvent(
      StockEventCompanion.insert(
        symbol: const Value('9999'),
        eventType: 'SHAREHOLDER_MEETING',
        eventDate: DateTime(2026, 7, 12),
        title: '9999 股東會',
      ),
    );
    await db.insertStockEvent(
      StockEventCompanion.insert(
        symbol: const Value(null),
        eventType: 'CUSTOM',
        eventDate: DateTime(2026, 7, 15),
        title: '個人備忘',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> titles(List<String>? symbols) async {
    final rows = await db.getEventsInRange(
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 31),
      symbols: symbols,
    );
    return rows.map((e) => e.title).toList();
  }

  group('EventDao.getEventsInRange symbols 語意', () {
    test('null＝不過濾（全部）', () async {
      expect(await titles(null), hasLength(3));
    });

    test('非空清單＝清單內＋無 symbol 的個人備忘', () async {
      expect(await titles(['2330']), containsAll(['2330 除息', '個人備忘']));
      expect(await titles(['2330']), hasLength(2));
    });

    test('空清單＝只剩個人備忘，不得退化成全市場', () async {
      expect(await titles(const []), ['個人備忘']);
    });
  });
}
