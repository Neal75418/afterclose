// tool/daily_update.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// 每日跑一次 UpdateService 累積 forward calibration 資料。給 macOS
// launchd 用（workmanager 在 macOS 不支援，導致 forward data 累積
// 完全靠 user 手動開 app — 過去 2 個月實測有兩段 3 週空白）。
//
// ## 使用方式
//
//   # 一次性手動跑：
//   dart run tool/daily_update.dart
//
//   # launchd 自動排程（com.neo.afterclose.daily.plist）每天 15:30
//   # 跑同一條指令。
//
// ## 環境變數
//
//   FINMIND_TOKEN  必填（沒設只能跑 TWSE 免費資料，新聞 / EPS / 月營收
//                  / 股利等會 skip）。launchd 不讀 ~/.zshrc — plist 用
//                  zsh wrapper source rc 拿 token。
//
// ## 退出碼
//
//   0   更新成功 / 非交易日 skip
//   1   更新失敗（API error / DB write fail / 非預期 exception）
//
// ## 與既有路徑的關係
//
//   - `lib/app/background_update_service.dart`（iOS / Android workmanager）
//   - `tool/daily_update.dart`（macOS launchd） ← this file
//   - 都呼叫 `lib/app/headless_update_runner.dart::runHeadlessUpdate()`
//     單一 source of truth，避免 wiring 漂移。
//
// ## 與 tool/backfill.dart 的差別
//
//   backfill：抓 2 年歷史 → 寫獨立 calibration DB，跑數小時，一次性。
//   daily_update：抓今天 → 寫主 DB，跑數分鐘，每天。

import 'dart:io';

import 'package:afterclose/app/headless_update_runner.dart';
import 'package:afterclose/core/utils/logger.dart';

Future<void> main(List<String> args) async {
  final start = DateTime.now();
  print('[daily_update] started at ${start.toIso8601String()}');

  try {
    final result = await runHeadlessUpdate();
    final elapsed = DateTime.now().difference(start);
    print(
      '[daily_update] finished in ${elapsed.inSeconds}s — '
      'success=${result.success}, skipped=${result.skipped}, '
      'message=${result.message}',
    );
    print('[daily_update] summary: ${result.summary}');
    exit(result.success ? 0 : 1);
  } catch (e, s) {
    AppLogger.error('daily_update', 'unhandled exception', e, s);
    print('[daily_update] FAILED: $e');
    print(s);
    exit(1);
  }
}
