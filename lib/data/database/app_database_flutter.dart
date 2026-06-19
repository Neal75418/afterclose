import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Flutter-specific [QueryExecutor] 開啟工廠
///
/// **隔離 Flutter 依賴**：`AppDatabase` 本檔（`app_database.dart`）原本
/// `import 'package:drift_flutter/drift_flutter.dart'`，連鎖把 `dart:ui`
/// 拉進整套 type graph，所有依賴 AppDatabase 的純 Dart CLI（`tool/`）
/// 都 dart run 不起來（C 方案 spike 2026-06-19 確認）。
///
/// 把這條 import 隔離在獨立檔，AppDatabase 改為 pure-Dart constructors
/// (`AppDatabase.forTesting()` / `AppDatabase.forToolFile()` / 接 executor
/// 的 default constructor)，UI / WorkManager 路徑顯式呼叫此 helper
/// 取得 Flutter-flavoured executor 後注入。
///
/// 行為等同原 `_openConnection()` — 用 `drift_flutter` 的 `driftDatabase`
/// 統一管理跨 isolate 連線、預設啟 WAL。
QueryExecutor openDriftFlutterConnection() {
  return driftDatabase(
    name: 'afterclose',
    native: DriftNativeOptions(
      // 前景 (Riverpod container) 與背景 (WorkManager isolate) 都
      // `AppDatabase(openDriftFlutterConnection())`，不開 shareAcrossIsolates
      // 會各自開原生連線。預設 rollback journal 模式下背景 `_db.transaction()`
      // 拿到的寫鎖會讓前景寫 SQLITE_BUSY 失敗（夜間 sync 期間使用者打開 app
      // 必中）。shareAcrossIsolates 讓 drift 統一管理跨 isolate 並行存取；
      // setup 啟 WAL 進一步降低 reader 受寫鎖影響的時間。setup callback 會被
      // 跨 isolate 發送；用 no-capture closure 確保可序列化。
      shareAcrossIsolates: true,
      setup: (db) => db.execute('PRAGMA journal_mode=WAL;'),
    ),
  );
}
