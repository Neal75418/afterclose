// getAllInstitutionalInRange — 全市場法人資料範圍查詢（族群排行用）
//
// 族群排行需要全市場（~2,500 檔）的近 3 交易日法人淨買賣。既有的
// getInstitutionalHistoryBatch 走 `symbol IN (...)`，SQLite 變數上限
// （999）撐不住全市場清單 → 提供無 symbol 過濾的範圍查詢
// （與 PriceDao.getAllPricesInRange 同款設計）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  DailyInstitutionalCompanion inst(
    String symbol,
    DateTime date, {
    double? foreign,
  }) {
    return DailyInstitutionalCompanion.insert(
      symbol: symbol,
      date: date,
      foreignNet: Value(foreign),
    );
  }

  group('getAllInstitutionalInRange', () {
    test('回傳範圍內全部 symbol 並分組、範圍外排除', () async {
      await db.insertInstitutionalData([
        inst('2330', DateTime(2026, 7, 17), foreign: 1000),
        inst('2330', DateTime(2026, 7, 20), foreign: 2000),
        inst('2317', DateTime(2026, 7, 20), foreign: 3000),
        inst('2330', DateTime(2026, 7, 1), foreign: 999999), // 範圍外
      ]);

      final result = await db.getAllInstitutionalInRange(
        startDate: DateTime(2026, 7, 15),
      );

      expect(result.keys, containsAll(['2330', '2317']));
      expect(result['2330'], hasLength(2));
      expect(result['2317'], hasLength(1));
      expect(
        result['2330']!.every((e) => !e.date.isBefore(DateTime(2026, 7, 15))),
        isTrue,
      );
    });

    test('endDate 上界生效', () async {
      await db.insertInstitutionalData([
        inst('2330', DateTime(2026, 7, 17), foreign: 1000),
        inst('2330', DateTime(2026, 7, 20), foreign: 2000),
      ]);

      final result = await db.getAllInstitutionalInRange(
        startDate: DateTime(2026, 7, 15),
        endDate: DateTime(2026, 7, 18),
      );

      expect(result['2330'], hasLength(1));
      expect(result['2330']!.single.date, DateTime(2026, 7, 17));
    });

    test('無資料 → 空 map', () async {
      final result = await db.getAllInstitutionalInRange(
        startDate: DateTime(2026, 7, 15),
      );
      expect(result, isEmpty);
    });
  });
}
