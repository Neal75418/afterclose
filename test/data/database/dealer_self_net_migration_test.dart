import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// `daily_institutional.dealer_self_net` 的 idempotent ALTER 遷移回歸測試。
///
/// 鏡像 `AppDatabase._ensureDealerSelfNetColumn` 的邏輯：pre-launch 鎖
/// schemaVersion=1，既有 DB 不 bump fingerprint（不 wipe derived 資料），改以
/// `PRAGMA table_info` 偵測欄位是否存在、不在才 `ALTER TABLE ADD COLUMN`。
///
/// 用 raw in-memory sqlite3 建一張「沒有 dealer_self_net」的舊版表，驗證：
/// 1. 遷移後欄位被加上
/// 2. 既有 row 完整保留（dealer_net 原值不變、新欄為 NULL）
/// 3. 重跑 idempotent（不重複 ALTER、不報錯、不動資料）
void main() {
  late Database db;

  /// 鏡像 _ensureDealerSelfNetColumn：idempotent PRAGMA-check + ALTER。
  /// 回傳 true 代表本次實際執行了 ALTER（供斷言 idempotency）。
  bool ensureDealerSelfNetColumn() {
    final columns = db.select("PRAGMA table_info('daily_institutional')");
    final hasColumn = columns.any((row) => row['name'] == 'dealer_self_net');
    if (hasColumn) return false;

    db.execute(
      'ALTER TABLE daily_institutional ADD COLUMN dealer_self_net REAL',
    );
    return true;
  }

  bool hasDealerSelfNetColumn() {
    final columns = db.select("PRAGMA table_info('daily_institutional')");
    return columns.any((row) => row['name'] == 'dealer_self_net');
  }

  setUp(() {
    db = sqlite3.openInMemory();
    // 舊版 schema：無 dealer_self_net 欄
    db.execute('''
      CREATE TABLE daily_institutional (
        symbol TEXT NOT NULL,
        date TEXT NOT NULL,
        foreign_net REAL,
        investment_trust_net REAL,
        dealer_net REAL,
        PRIMARY KEY (symbol, date)
      )
    ''');
    // 既有資料（重新同步前累積的 derived 資料）
    db.execute('''
      INSERT INTO daily_institutional
        (symbol, date, foreign_net, investment_trust_net, dealer_net)
      VALUES ('2330', '2026-06-13', 500.0, 100.0, 20.0)
    ''');
  });

  tearDown(() {
    db.close();
  });

  group('dealer_self_net idempotent ALTER migration', () {
    test('adds the column to an existing table without it', () {
      expect(hasDealerSelfNetColumn(), isFalse, reason: '前置：舊表無此欄');

      final didAlter = ensureDealerSelfNetColumn();

      expect(didAlter, isTrue, reason: '缺欄時應實際執行 ALTER');
      expect(hasDealerSelfNetColumn(), isTrue, reason: '遷移後欄位應存在');
    });

    test('preserves existing rows; new column is NULL', () {
      ensureDealerSelfNetColumn();

      final rows = db.select(
        'SELECT symbol, dealer_net, dealer_self_net '
        'FROM daily_institutional',
      );

      expect(rows, hasLength(1), reason: '既有 row 不得遺失');
      final row = rows.single;
      expect(row['symbol'], '2330');
      expect(row['dealer_net'], 20.0, reason: 'dealer_net 原值保留');
      expect(row['dealer_self_net'], isNull, reason: '新欄回填為 NULL');
    });

    test('is idempotent on rerun (no duplicate ALTER, data intact)', () {
      final first = ensureDealerSelfNetColumn();
      final second = ensureDealerSelfNetColumn();
      final third = ensureDealerSelfNetColumn();

      expect(first, isTrue, reason: '第一次補欄');
      expect(second, isFalse, reason: '已存在 → no-op');
      expect(third, isFalse, reason: '再跑仍 no-op');

      // 欄位仍只有一個 dealer_self_net，資料未受影響
      final columns = db.select("PRAGMA table_info('daily_institutional')");
      final selfCols = columns
          .where((r) => r['name'] == 'dealer_self_net')
          .toList();
      expect(selfCols, hasLength(1), reason: '不得重複加欄');

      final rows = db.select('SELECT dealer_net FROM daily_institutional');
      expect(rows.single['dealer_net'], 20.0, reason: 'rerun 不動既有資料');
    });

    test('on a fresh table that already has the column, ALTER is skipped', () {
      // 模擬全新安裝：createAll 已建出含此欄的表
      db.execute('DROP TABLE daily_institutional');
      db.execute('''
        CREATE TABLE daily_institutional (
          symbol TEXT NOT NULL,
          date TEXT NOT NULL,
          foreign_net REAL,
          investment_trust_net REAL,
          dealer_net REAL,
          dealer_self_net REAL,
          PRIMARY KEY (symbol, date)
        )
      ''');

      final didAlter = ensureDealerSelfNetColumn();

      expect(didAlter, isFalse, reason: '全新安裝已含此欄 → no-op');
      expect(hasDealerSelfNetColumn(), isTrue);
    });
  });
}
