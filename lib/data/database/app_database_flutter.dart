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
    // 🚫 命名邊界(2026-08-07 更名 Daredevil 時保留):此字串即 DB 檔名
    // afterclose.sqlite,改動 = App 指向新的空資料庫、既有資料看似消失。
    // 要改必須配套做檔案遷移,別在改名時順手動它。
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
      // 🔴 busy_timeout 不可省(2026-08-08 五次審查):CLI 側
      // (`AppDatabase.forToolFile`)設 5000ms 是因為實機被咬過——GUI 手動
      // 更新握住寫鎖時,launchd 那輪整個死在 SqliteException(5)。GUI 這側
      // 是**鏡像曝險**:盤中 CLI 每 5 分鐘持一次寫鎖,此時 app 內的認領/
      // 釋放寫入會當場拋例外(實測同一 isolate 內確實立刻 BUSY,不等待)。
      // WAL 只解決讀寫並行,寫寫仍需排隊——給它等,不要當場放棄。
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL;');
        db.execute('PRAGMA busy_timeout=5000;');
      },
    ),
  );
}
