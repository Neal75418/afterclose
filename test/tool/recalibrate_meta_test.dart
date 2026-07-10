// recalibrate CLI 的 clustered 分流 loader 測試（sqlite3 in-memory，無 Drift）
//
// 驗證：
//   1. readRunMeta — meta 表缺失 → null；excess run → 解析 mode/threshold/baseline
//   2. loadDailyMeans — 依日期升序還原每 rule 的日均值序列

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../tool/recalibrate.dart';

void main() {
  group('readRunMeta', () {
    test('calibration_run_meta 表不存在（舊 DB）→ null', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      expect(readRunMeta(db), isNull);
    });

    test('excess run → 解析 mode / threshold / 兩個 baseline', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute(
        'CREATE TABLE calibration_run_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      db.execute(
        "INSERT INTO calibration_run_meta VALUES ('return_mode', 'excess')",
      );
      db.execute(
        "INSERT INTO calibration_run_meta VALUES ('excess_success_threshold', '0.0')",
      );
      db.execute(
        "INSERT INTO calibration_run_meta VALUES ('universe_baseline_hit_5d', '0.4712')",
      );
      db.execute(
        "INSERT INTO calibration_run_meta VALUES ('universe_baseline_hit_60d', '0.4525')",
      );

      final meta = readRunMeta(db);
      expect(meta, isNotNull);
      expect(meta!.returnMode, 'excess');
      expect(meta.isExcess, isTrue);
      expect(meta.excessThreshold, 0.0);
      expect(meta.baselineHit5, closeTo(0.4712, 1e-9));
      expect(meta.baselineHit60, closeTo(0.4525, 1e-9));
    });

    test('absolute run → isExcess false、baseline null', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute(
        'CREATE TABLE calibration_run_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      db.execute(
        "INSERT INTO calibration_run_meta VALUES ('return_mode', 'absolute')",
      );

      final meta = readRunMeta(db);
      expect(meta!.isExcess, isFalse);
      expect(meta.baselineHit5, isNull);
      expect(meta.baselineHit60, isNull);
    });
  });

  group('loadDailyMeans', () {
    test('依日期升序、按 period 過濾、多 rule 分組', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute('''
        CREATE TABLE rule_daily_stats (
          rule_id TEXT NOT NULL, period TEXT NOT NULL, date TEXT NOT NULL,
          n INTEGER NOT NULL, mean_return REAL NOT NULL,
          PRIMARY KEY (rule_id, period, date))''');
      // 亂序插入 → 讀出必須升序
      db.execute(
        "INSERT INTO rule_daily_stats VALUES ('R1', '5D', '2025-01-03', 2, 3.0)",
      );
      db.execute(
        "INSERT INTO rule_daily_stats VALUES ('R1', '5D', '2025-01-01', 5, 1.0)",
      );
      db.execute(
        "INSERT INTO rule_daily_stats VALUES ('R1', '60D', '2025-01-01', 5, 9.9)",
      );
      db.execute(
        "INSERT INTO rule_daily_stats VALUES ('R2', '5D', '2025-01-02', 1, -0.5)",
      );

      final means = loadDailyMeans(db, '5D');
      expect(means['R1'], [1.0, 3.0]); // 升序，60D 那筆不混入
      expect(means['R2'], [-0.5]);
      expect(means.containsKey('R3'), isFalse);
    });

    test('rule_daily_stats 表不存在（舊 DB）→ 空 map', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      expect(loadDailyMeans(db, '5D'), isEmpty);
    });
  });
}
