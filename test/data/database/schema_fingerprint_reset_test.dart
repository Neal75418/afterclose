import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:afterclose/data/database/app_database.dart';

/// Schema fingerprint reset 的回歸測試（2026-07-15 生產事故）。
///
/// 事故：fingerprint bump 觸發 reset 時，wipe 白名單表（如 portfolio_position、
/// news_mention_daily）未被 drop、其**索引**仍存在；drift `Migrator.createAll()`
/// 建表用 `CREATE TABLE IF NOT EXISTS` 但建索引**不帶 IF NOT EXISTS**，
/// 撞既存索引 → `SqliteException: index ... already exists`，啟動炸掉。
///
/// 用真實檔案 DB 走完整生命週期：初次建立 → 竄改 stored fingerprint 模擬
/// bump → 重開觸發 reset → 必須不炸、白名單資料保留、derived 表可用。
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fp_reset_test');
    dbFile = File('${tempDir.path}/fp_test.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('fingerprint mismatch reset 不因白名單表既存索引而炸，且保留白名單資料', () async {
    // 1. 初次開啟：建立全部 schema（含白名單表的索引）+ 寫入 fingerprint
    final db1 = AppDatabase(NativeDatabase(dbFile));
    await db1.customSelect('SELECT 1').get(); // 觸發 open/beforeOpen
    await db1.batch((b) {
      b.insert(
        db1.newsMentionDaily,
        NewsMentionDailyCompanion.insert(
          date: DateTime(2026, 7, 15),
          kind: 'stock',
          itemKey: '2330',
          mentionCount: 5,
          dictionaryVersion: 1,
        ),
      );
      b.insert(
        db1.stockMaster,
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
      );
      // 新聞歷史不可重抓（RSS 只供應當下窗口）——必須在 reset 中保留
      b.insert(
        db1.newsItem,
        NewsItemCompanion.insert(
          id: 'news-1',
          source: '鉅亨網',
          title: '台積電(2330)營收創高',
          url: 'https://example.com/1',
          category: 'OTHER',
          publishedAt: DateTime(2026, 7, 15, 9),
        ),
      );
      b.insert(
        db1.newsStockMap,
        NewsStockMapCompanion.insert(newsId: 'news-1', symbol: '2330'),
      );
    });
    await db1.close();

    // 2. 竄改 stored fingerprint 模擬「新版 app 開舊 DB」的 bump 情境
    final rawDb = raw.sqlite3.open(dbFile.path);
    rawDb.execute(
      "UPDATE _drift_schema_fingerprint SET value = 'stale-old-fingerprint'",
    );
    rawDb.close();

    // 3. 重開：beforeOpen 觸發 reset——修復前這裡炸
    //    SqliteException(index ... already exists)
    final db2 = AppDatabase(NativeDatabase(dbFile));
    final mentions = await db2
        .customSelect('SELECT COUNT(*) AS c FROM news_mention_daily')
        .getSingle();
    // 白名單表資料保留
    expect(mentions.read<int>('c'), 1);
    // 新聞與關聯保留（30 天存量 RSS 補不回，2026-07-15 事故教訓）
    final news = await db2
        .customSelect('SELECT COUNT(*) AS c FROM news_item')
        .getSingle();
    expect(news.read<int>('c'), 1);
    final map = await db2
        .customSelect('SELECT COUNT(*) AS c FROM news_stock_map')
        .getSingle();
    expect(map.read<int>('c'), 1);
    // 非白名單 derived 表被 wipe 後重建：空但可查詢
    final stocks = await db2
        .customSelect('SELECT COUNT(*) AS c FROM stock_master')
        .getSingle();
    expect(stocks.read<int>('c'), 0);
    // 白名單表的索引在 reset 後仍存在（被重建）
    final idx = await db2
        .customSelect(
          "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='index' "
          "AND name='idx_news_mention_daily_date'",
        )
        .getSingle();
    expect(idx.read<int>('c'), 1);
    await db2.close();
  });

  test('reset 後 fingerprint 已更新、二次重開不再 reset（冪等收斂）', () async {
    final db1 = AppDatabase(NativeDatabase(dbFile));
    await db1.customSelect('SELECT 1').get();
    await db1.close();

    final rawDb = raw.sqlite3.open(dbFile.path);
    rawDb.execute(
      "UPDATE _drift_schema_fingerprint SET value = 'stale-old-fingerprint'",
    );
    rawDb.close();

    final db2 = AppDatabase(NativeDatabase(dbFile));
    await db2.customSelect('SELECT 1').get(); // reset 完成
    await db2.batch((b) {
      b.insert(
        db2.stockMaster,
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
      );
    });
    await db2.close();

    // 三度開啟：fingerprint 已一致，不得再 wipe（derived 資料保留）
    final db3 = AppDatabase(NativeDatabase(dbFile));
    final stocks = await db3
        .customSelect('SELECT COUNT(*) AS c FROM stock_master')
        .getSingle();
    expect(stocks.read<int>('c'), 1);
    await db3.close();
  });
}
