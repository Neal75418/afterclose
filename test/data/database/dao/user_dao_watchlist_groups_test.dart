// Integration tests for watchlist 自訂分組（資料夾模式）DAO 方法
//
// 用 in-memory Drift (`AppDatabase.forTesting`) 驗證分組 CRUD、指定分組、
// LEFT JOIN 帶分組名稱，以及刪除分組時 FK `onDelete: setNull` 的行為
// （成員回到未分組、不連帶刪除股票）。

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  // watchlist.symbol 有 FK 參照 StockMaster，先建主檔再加自選
  Future<void> insertTestStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2454', name: '聯發科', market: 'TWSE'),
    ]);
  }

  group('createWatchlistGroup', () {
    test('建立分組並回傳遞增 id', () async {
      final id1 = await db.createWatchlistGroup('核心持股');
      final id2 = await db.createWatchlistGroup('觀察名單');

      expect(id1, isNonZero);
      expect(id2, greaterThan(id1));

      final groups = await db.getWatchlistGroups();
      expect(groups.map((g) => g.name), ['核心持股', '觀察名單']);
    });

    test('新分組 sortOrder 遞增（附加在末端）', () async {
      await db.createWatchlistGroup('A');
      await db.createWatchlistGroup('B');
      await db.createWatchlistGroup('C');

      final groups = await db.getWatchlistGroups();
      // 依 sortOrder asc 排序，順序應為建立順序
      expect(groups.map((g) => g.name), ['A', 'B', 'C']);
      expect(groups.map((g) => g.sortOrder), [0, 1, 2]);
    });
  });

  group('renameWatchlistGroup', () {
    test('改名後查詢回傳新名稱', () async {
      final id = await db.createWatchlistGroup('舊名');
      await db.renameWatchlistGroup(id, '新名');

      final groups = await db.getWatchlistGroups();
      expect(groups.single.name, '新名');
    });
  });

  group('assignWatchlistGroup', () {
    test('指定股票到分組，getWatchlistWithGroups 帶出分組名稱', () async {
      await insertTestStocks();
      await db.addToWatchlist('2330');
      final groupId = await db.createWatchlistGroup('核心');

      await db.assignWatchlistGroup('2330', groupId);

      final withGroups = await db.getWatchlistWithGroups();
      final entry = withGroups.firstWhere((w) => w.entry.symbol == '2330');
      expect(entry.entry.groupId, groupId);
      expect(entry.groupName, '核心');
    });

    test('指定 null 代表移出分組', () async {
      await insertTestStocks();
      await db.addToWatchlist('2330');
      final groupId = await db.createWatchlistGroup('核心');
      await db.assignWatchlistGroup('2330', groupId);

      await db.assignWatchlistGroup('2330', null);

      final withGroups = await db.getWatchlistWithGroups();
      final entry = withGroups.firstWhere((w) => w.entry.symbol == '2330');
      expect(entry.entry.groupId, isNull);
      expect(entry.groupName, isNull);
    });
  });

  group('getWatchlistWithGroups', () {
    test('未分組股票 groupName 為 null', () async {
      await insertTestStocks();
      await db.addToWatchlist('2317');

      final withGroups = await db.getWatchlistWithGroups();
      final entry = withGroups.single;
      expect(entry.entry.symbol, '2317');
      expect(entry.entry.groupId, isNull);
      expect(entry.groupName, isNull);
    });

    test('混合分組與未分組正確帶出名稱', () async {
      await insertTestStocks();
      await db.addToWatchlist('2330');
      await db.addToWatchlist('2317');
      await db.addToWatchlist('2454');
      final groupId = await db.createWatchlistGroup('科技');
      await db.assignWatchlistGroup('2330', groupId);
      await db.assignWatchlistGroup('2454', groupId);

      final withGroups = await db.getWatchlistWithGroups();
      final byName = {for (final w in withGroups) w.entry.symbol: w.groupName};
      expect(byName['2330'], '科技');
      expect(byName['2454'], '科技');
      expect(byName['2317'], isNull);
    });
  });

  group('deleteWatchlistGroup — FK onDelete setNull', () {
    test('刪除分組後成員變未分組、股票不被連帶刪除', () async {
      await insertTestStocks();
      await db.addToWatchlist('2330');
      await db.addToWatchlist('2317');
      final groupId = await db.createWatchlistGroup('待刪');
      await db.assignWatchlistGroup('2330', groupId);
      await db.assignWatchlistGroup('2317', groupId);

      await db.deleteWatchlistGroup(groupId);

      // 分組已刪
      expect(await db.getWatchlistGroups(), isEmpty);

      // 兩檔股票仍在自選清單（沒被 cascade 刪掉）
      final watchlist = await db.getWatchlist();
      expect(watchlist.map((w) => w.symbol), containsAll(['2330', '2317']));

      // 成員 groupId 被 setNull 清空
      final withGroups = await db.getWatchlistWithGroups();
      for (final w in withGroups) {
        expect(w.entry.groupId, isNull);
        expect(w.groupName, isNull);
      }
    });
  });
}
