import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:daredevil/data/database/app_database.dart';

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
    // 白名單表的(現行 schema 宣告的)索引在 reset 後仍存在（被重建）
    final idx = await db2
        .customSelect(
          "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='index' "
          "AND name='idx_news_item_published_at'",
        )
        .getSingle();
    expect(idx.read<int>('c'), 1);
    // idx_news_mention_daily_date 為 PK (date,kind,itemKey) 左前綴冗餘,
    // 2026-07-29 起由 _ensureIndexHygiene 清除、annotation 已移除——reset 後
    // 必須不存在(舊斷言的相反;索引處理不炸的原始回歸意圖由上一條承接)
    final legacy = await db2
        .customSelect(
          "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='index' "
          "AND name='idx_news_mention_daily_date'",
        )
        .getSingle();
    expect(legacy.read<int>('c'), 0);
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
  // ====================================================================
  // 加欄不得走 fingerprint bump（2026-07-26）
  //
  // fingerprint 機制會 drop 全部非 whitelist 表重建，而 daily_price 不在
  // whitelist —— 實測使用者 live DB 有 275 個交易日 / 565,570 列，wipe 後
  // Phase 0 市場日快照單次上限 30 次呼叫，回到原深度約需 19 次每日更新。
  //
  // 曾為了替 rule_accuracy 加一個純附加欄位而 bump 指紋（commit f8de299），
  // 等於用整份價格歷史換一個欄位。正確做法是 _ensureDealerSelfNetColumn
  // 式的 idempotent `PRAGMA table_info` + `ALTER TABLE ADD COLUMN`。
  // ====================================================================
  test('🚨 既有 DB 開啟後自動補上 rule_accuracy.distinct_dates，且不 wipe 價格', () async {
    // 1. 先用正常流程建好 DB（寫入當前 fingerprint）
    var db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT 1').get();
    await db.batch((b) {
      b.insert(
        db.stockMaster,
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
      );
    });
    await db.customStatement(
      "INSERT INTO daily_price (symbol, date) VALUES ('2330', '2026-07-24')",
    );
    // 2. 竄改成「舊版」：把 distinct_dates 欄拔掉，模擬既有使用者的 DB
    await db.customStatement('DROP TABLE rule_accuracy');
    await db.customStatement(
      'CREATE TABLE rule_accuracy (rule_id TEXT NOT NULL, period TEXT NOT NULL, '
      'trigger_count INTEGER NOT NULL DEFAULT 0, '
      'success_count INTEGER NOT NULL DEFAULT 0, '
      'avg_return REAL NOT NULL DEFAULT 0.0, '
      'updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP), '
      'PRIMARY KEY (rule_id, period))',
    );
    await db.close();

    // 3. 重開：beforeOpen 應以 idempotent ALTER 補欄，而非觸發 fingerprint reset
    db = AppDatabase(NativeDatabase(dbFile));
    final cols = await db
        .customSelect("PRAGMA table_info('rule_accuracy')")
        .get();
    expect(
      cols.map((r) => r.read<String>('name')).toSet(),
      contains('distinct_dates'),
      reason: 'idempotent ALTER 必須補上欄位',
    );

    final priceCount = await db
        .customSelect('SELECT COUNT(*) c FROM daily_price')
        .getSingle();
    expect(
      priceCount.read<int>('c'),
      1,
      reason: '加欄不得清空 daily_price —— 那是 275 天、56 萬列的回補成本',
    );

    // 4. 冪等：再開一次不得炸
    await db.close();
    db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT 1').get();
    await db.close();
  });
}
