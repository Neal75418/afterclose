import 'dart:io';

/// CLI 日誌自輪替(2026-08-08)。
///
/// **為什麼不用 newsyslog**:那要在 `/etc/newsyslog.d/` 放一個未版控、
/// 機器本地、換機就消失的設定檔——而本專案今天已經被同一類東西咬過
/// 兩次(launchd plist 只存在 `~/Library` 差點靜默失效;改了 plist 檔
/// 卻沒重新 bootstrap,live job 一直跑舊定義)。輪替寫進程式就跟著
/// repo 走、有測試覆蓋、換機自動生效,而且不需要 sudo。
///
/// 策略是「就地截斷保留尾端」而非改名輪替:launchd 的 append 重導
/// 握著同一個 file descriptor,改名會讓後續輸出繼續寫進已改名的舊檔
/// (寫到沒人看的地方),就地截斷則沒有這個問題。
abstract final class LogRotation {
  /// 預設上限 1 MB。實測(2026-08-08 三次審查 F-7):每次執行約 100 bytes
  /// ——心跳行之外還有 `dart run` 自己吐的 `Running build hooks...`(44
  /// bytes 且無換行)。55 次/日 ≈ 5.5 KB/日 → 1 MB 約留 **190 天**。
  ///
  /// ⚠️ 上述只適用**穩態**。開發期間程式碼一改,下一次 `dart run` 會重新
  /// 編譯並吐出大量 `\r` 進度輸出:2026-08-08 一天之內就衝到 1.2 MB 觸發
  /// 輪替(平時要 190 天)。看到日誌暴漲先確認是不是剛改過 code,不必然
  /// 是故障。
  static const int defaultMaxBytes = 1024 * 1024;

  /// 超過 [maxBytes] 時就地截斷,保留最新的約一半內容。
  ///
  /// 失敗一律吞掉——**輪替永遠不該是主功能失敗的原因**。
  static void rotateIfNeeded(String path, {int maxBytes = defaultMaxBytes}) {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final length = file.lengthSync();
      if (length <= maxBytes) return;

      // 保留一半:留太少會讓「剛截斷完」的日誌幾乎沒有上下文
      final keep = maxBytes ~/ 2;
      final bytes = file.readAsBytesSync();
      var tail = bytes.sublist(bytes.length - keep);

      // 從第一個換行之後開始,避免開頭是被切一半的殘句。
      //
      // ⚠️ 但只在「殘句本身很短」時才修剪(2026-08-08 實機事故)。
      // `dart run` 的進度輸出用 `\r` 不用 `\n`,異常時會一次吐出數十萬
      // 位元組完全沒有換行的內容;此時尾端窗內的第一個 `\n` 落在很後面,
      // 無條件修剪會把**整個保留區**吃光——實測 1.2 MB 的日誌輪替後只
      // 剩 104 bytes,異常當下的證據全滅,連「發生了什麼」都查不到了。
      // 輪替的目的是限制大小,不是銷毀證據:寧可開頭留一段殘句。
      final nl = tail.indexOf(0x0A);
      final maxTrim = tail.length ~/ 8;
      if (nl >= 0 && nl < tail.length - 1 && nl <= maxTrim) {
        tail = tail.sublist(nl + 1);
      }

      final header =
          '--- truncated at ${DateTime.now().toIso8601String()} '
          '(was $length bytes) ---\n';
      file.writeAsBytesSync([...header.codeUnits, ...tail]);
    } catch (_) {
      // 輪替失敗不影響本體
    }
  }
}
