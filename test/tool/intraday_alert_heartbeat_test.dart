import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 盤中提醒 CLI 的心跳(2026-08-08 三次審查 M-1)。
///
/// **為什麼需要端到端跑一次**:心跳(`beat()`)是 commit `31b54e03` 的全部
/// 價值——它讓「正常跳過」與「啟動就炸」在日誌上長得不一樣。但在此之前
/// **沒有任何測試斷言它**:把 `beat(...)` 改回 `return;`、或把 `print`
/// 換成 `AppLogger.debug`(在 `dart run` 下是 no-op),全套測試照樣綠,
/// 而非交易時段會靜靜地變回無聲。
///
/// 這條同時擋住另一個更貴的失效:**編譯失敗導致自動更新靜默斷線**
/// (本專案 2026-07 為此斷了 13 天)。`dart run` 若編譯不過,這裡會拿到
/// 空的 stdout 與非零 exit code。
///
/// **安全性**:刻意把 `HOME` 指到一個空的暫存目錄,讓 CLI 走「DB 不存在」
/// 的早退路徑——不連網、不碰真的資料庫、不會認領或通知任何提醒。
void main() {
  test('🚨 CLI 一定會發心跳——即使是早退路徑', () async {
    final fakeHome = Directory.systemTemp.createTempSync('dd_hb_home');
    addTearDown(() => fakeHome.deleteSync(recursive: true));

    final result = await Process.run(
      'dart',
      ['run', 'tool/intraday_alert_check.dart'],
      environment: {'HOME': fakeHome.path},
      workingDirectory: Directory.current.path,
    );

    final out = '${result.stdout}';
    expect(
      out,
      contains('[intraday_alert]'),
      reason:
          '心跳不見了。若 stdout 全空,先確認是不是編譯失敗——'
          '那正是 2026-07 自動更新靜默斷 13 天的形狀。stderr: ${result.stderr}',
    );
    // ⚠️ 不可斷言特定分支:非交易時段的 skip 早退在 DB 檢查**之前**,
    // 所以走哪條取決於跑測試的當下(平日盤中 vs 週末)。第一版就是這樣
    // 寫死成「FAIL(DB 不存在)」,週六跑立刻紅——測試自己抓到了自己的
    // 日期依賴。這裡改為斷言「屬於已知狀態之一」,與時間無關。
    const knownStates = [
      'skip(非交易時段)',
      'FAIL(DB 不存在)',
      'FAIL(通知管道不可用)',
      'FAILED',
      '無觸價',
      '觸價',
    ];
    expect(
      knownStates.any(out.contains),
      isTrue,
      reason:
          '心跳內容不是任何已知狀態,可能有人新增分支卻忘了發心跳。'
          '實際輸出:$out',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
