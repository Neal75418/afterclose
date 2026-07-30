import 'dart:io';

import 'package:afterclose/data/remote/api_budget_tracker.dart';

/// [ApiBudgetStore] 的純 Dart 檔案實作——launchd CLI 專用。
///
/// GUI/背景 isolate 用 SharedPreferences 版;但 shared_preferences 是
/// flutter plugin(import flutter/foundation → dart:ui),混進
/// tool/daily_update.dart 的 `dart run` 鏈會編譯失敗(2026-07-27
/// `afc11afb` 事故,自動更新靜默斷更的第二波)。CLI 改存 JSON 檔。
///
/// **與 GUI 的計數不共享**:SharedPreferences 的 plist 在 app sandbox
/// domain,CLI 本來就讀不到(先前註解已明言 restore 會 fail-open)。
/// 兩邊各自延續自己的歷史,合計超額由 402 fail-open + 斷路器兜底。
class FileApiBudgetStore implements ApiBudgetStore {
  const FileApiBudgetStore(this.path);

  /// JSON 狀態檔完整路徑(慣例:DB 同目錄 `api_budget_cli.json`)。
  final String path;

  @override
  Future<String?> load() async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString(); // 壞檔讓例外上拋,tracker fail-open
  }

  @override
  Future<void> save(String json) async {
    await File(path).writeAsString(json, flush: true);
  }
}
