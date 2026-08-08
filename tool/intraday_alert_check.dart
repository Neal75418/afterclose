// 盤中提醒檢查(macOS launchd,2026-08-08)。
//
// 為什麼要有這支:app 內的輪詢是前景計時器,關掉 app 就停了。macOS 有
// launchd 這種 OS 層排程器,可在 app 完全關閉時定時喚醒——與盤後
// `daily_update.dart` 同一套機制、同一個維護心智。
//
// 執行方式(launchd `StartInterval=300`,每 5 分鐘喚醒一次):
//   dart run tool/intraday_alert_check.dart
// 盤前/盤後/假日由 IntradayPollSchedule 自行 no-op,不必在 plist 排時段。
//
// **純 Dart 鐵律**:本檔 import 閉包不得含 flutter/easy_localization/
// flutter plugins(守門:test/tool/tool_chain_pure_dart_test.dart)。
// 通知因此不能用 flutter_local_notifications,改用 macOS 原生 osascript。
import 'dart:io';

import 'package:daredevil/core/utils/log_rotation.dart';
import 'package:daredevil/core/utils/taiwan_time.dart';
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/intraday_alert_monitor.dart';
import 'package:daredevil/domain/services/alert/intraday_poll_schedule.dart';

Future<void> main(List<String> args) async {
  // 日誌自輪替(2026-08-08):不用 newsyslog——那要在 /etc 放一個未版控、
  // 換機就消失的設定檔,正是今天咬過我們兩次的那類東西
  // ⚠️ stderr 也要輪替(2026-08-08 三次審查 M-3):launchd 的
  // StandardErrorPath 是另一個檔案,而**故障訊息正好落在那裡**——最需要
  // 保護的日誌反而沒被保護。本專案已有前例:舊的 daily stderr 一路長到
  // 153 MB(7 月自動更新靜默斷 13 天的編譯錯誤洪流)。
  for (final name in [
    'daredevil-intraday.log',
    'daredevil-intraday.launchd.log',
  ]) {
    LogRotation.rotateIfNeeded(
      '${Platform.environment['HOME']}/Library/Logs/$name',
    );
  }

  final now = TaiwanTime.now();
  final force = args.contains('--force');

  // ⚠️ launchd 的 StartCalendarInterval 用**系統本地時間**喚醒,而盤中
  // 判定用台北時間——機器換時區時兩者會錯開(2026-08-08 三次審查)。
  // macOS 的「自動依位置設定時區」預設開啟,所以出差時它會自己改,
  // 使用者不會做任何動作。實測覆蓋率:東京/曼谷 78%、倫敦/紐約 0%。
  //
  // 不修喚醒時段(那要改 275 條 plist entry 或大幅增加喚醒次數),而是
  // 讓故障**自己講出來**:漏接提醒的症狀與「今天沒股票觸價」完全一樣,
  // 使用者會得出錯誤結論。這個專案反覆吃虧的正是這一類偽裝成正常的故障。
  final localOffset = DateTime.now().timeZoneOffset;
  const taipeiOffset = Duration(hours: 8);
  final tzMismatch = localOffset != taipeiOffset;

  // 心跳:每輪都留一行帶時戳的紀錄。原本非交易時段靜默 exit,結果
  // 「正常 no-op」與「dart 啟動就炸」在日誌上長得一模一樣——那正是本
  // 專案自動更新靜默斷 13 天的形狀(2026-08-08 端到端驗證指出)。
  // 55 次/日;輪替由 LogRotation 自己做(見檔首 import)。
  void beat(String state) => print(
    '[intraday_alert] ${now.toIso8601String().substring(0, 16)} $state'
    // 時區不符時每一行都帶警告——只印一次會被埋在 55 行裡面
    '${tzMismatch ? ' ⚠️TZ(本地 UTC${localOffset.isNegative ? '' : '+'}'
              '${localOffset.inHours},台北 UTC+8'
              '——launchd 依本地時間喚醒,喚醒時段已與台股盤中錯開)' : ''}',
  );

  if (!force && !IntradayPollSchedule.isMarketHours(now)) {
    beat('skip(非交易時段)');
    exit(0);
  }

  final dbPath =
      '${Platform.environment['HOME']}'
      '/Library/Containers/com.neo.afterclose/Data/Documents/afterclose.sqlite';
  if (!File(dbPath).existsSync()) {
    // 心跳:沒有這行,監控看到的是「零筆匹配」——與「job 沒被排到」
    // 完全無法區分(2026-08-08 三次審查 M-2)
    beat('FAIL(DB 不存在)');
    stderr.writeln('[intraday_alert] DB 不存在: $dbPath');
    exit(1);
  }

  AppDatabase? database;
  try {
    database = AppDatabase.forToolFile(dbPath);
    // --force 時印出判定過程:靜默成功無法證明 API 真的打通了
    if (force) {
      final pending = (await database.getActiveAlerts())
          .where((a) => a.triggeredAt == null)
          .toList();
      print('[intraday_alert] 待監控 ${pending.length} 筆');
      for (final a in pending) {
        print(
          '  ${a.symbol} ${a.alertType} ${a.targetValue} (${a.note ?? '-'})',
        );
      }
    }

    // 🔴 通知管道必須先確認可用,再檢查(2026-08-08 code review A2)。
    // check() 會把觸價的提醒標成已觸發且停用;若之後才發現 osascript
    // 發不出去,提醒就被靜默燒掉——使用者沒收到,收盤路徑也看不到它。
    if (!await _notificationChannelWorks()) {
      beat('FAIL(通知管道不可用)');
      stderr.writeln('[intraday_alert] 通知管道不可用,本輪不檢查(避免燒掉提醒)');
      await database.close();
      exit(1);
    }

    final result = await IntradayAlertMonitor(
      database: database,
      client: IntradayQuoteClient(),
    ).check(now: now);
    final fired = result.fired;

    if (force) {
      print(
        '[intraday_alert] 取得報價 '
        '${result.quotesFetched}/${result.symbolsWanted} 檔',
      );
    }
    if (result.symbolsWanted > 0 && result.quotesFetched == 0) {
      beat('FAIL(報價全滅)');
      // 報價全滅 ≠ 沒到價:這是故障,要能從 exit code 看出來
      stderr.writeln('[intraday_alert] 報價全數失敗,本輪判定不可信');
      exit(1);
    }
    if (fired.isEmpty) {
      beat('ok(無觸價,報價 ${result.quotesFetched}/${result.symbolsWanted})');
      exit(0);
    }

    var notified = 0;
    for (final f in fired) {
      final direction = f.alert.alertType == 'ABOVE' ? '突破' : '跌破';
      final label = f.alert.note ?? '$direction ${f.alert.targetValue}';
      final ok = await _notify(
        title: '${f.quote.symbol} ${f.quote.name} $label',
        body:
            '現價 ${f.quote.price.toStringAsFixed(2)}'
            '(${f.quote.changePercent >= 0 ? '+' : ''}'
            '${f.quote.changePercent.toStringAsFixed(2)}%)'
            ' · ${f.quote.time ?? ''}',
      );
      if (ok) {
        notified++;
      } else {
        // 🚨 認領發生在通知之前(跨 process 去重的代價),所以通知失敗
        // 必須退回可重試狀態——否則該筆停在 triggeredAt!=null,兩條
        // 路徑的 pending 過濾都會永久跳過它(2026-08-08 三次審查 C-1)
        await database.releaseAlertClaim(f.alert.id);
        stderr.writeln('[intraday_alert] 通知失敗,已釋放認領: ${f.alert.symbol}');
      }
    }
    // ⚠️ 措辭不可斷言「已送達」:osascript 即使通知被 Focus 模式或系統
    // 設定抑制也回 exit 0,我們只知道它「接受」了,不知道使用者看到沒
    beat('觸價 ${fired.length} 筆,osascript 接受 $notified 筆(未確認送達)');
    await database.close();
    exit(notified == fired.length ? 0 : 1);
  } catch (e, s) {
    // AppLogger 在 `dart run` 下是 no-op(輸出包在 assert 內、asserts
    // 未啟用)——堆疊必須自己印,否則故障現場只剩一行訊息
    beat('FAILED');
    stderr.writeln('[intraday_alert] FAILED: $e');
    stderr.writeln(s);
    exit(1);
  } finally {
    // ⚠️ 此區塊在多數路徑**不會執行**:上面每個分支都直接 exit(),而
    // exit() 立即終止 process(2026-08-08 三次審查 M-5)。留著只為了
    // 覆蓋「例外向上逃逸」這條路。**不要把非冪等的清理放進來**——
    // 它讀起來像有清理,實際多半沒跑。真正的關閉在各 exit() 之前。
    await database?.close();
  }
}

/// macOS 原生通知。CLI 不能用 flutter_local_notifications(純 Dart 鐵律),
/// osascript 是不需額外相依、在 app 關閉時也能發通知的原生管道。
///
/// 字串以雙引號包入 AppleScript,故需轉義 `\` 與 `"`;股票名稱理論上
/// 不含這些字元,但通知內容來自外部 API,不做假設。
Future<bool> _notify({required String title, required String body}) async {
  // 換行會截斷 AppleScript 字串字面值(2026-08-08 code review):note 由
  // 使用者輸入,不能假設單行
  String esc(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
  final script =
      'display notification "${esc(body)}" '
      'with title "Daredevil" subtitle "${esc(title)}"';
  final result = await Process.run('osascript', ['-e', script]);
  if (result.exitCode != 0) {
    stderr.writeln('[intraday_alert] 通知失敗: ${result.stderr}');
    return false;
  }
  return true;
}

/// 開跑前先確認 osascript 可用——寧可不檢查,也不要檢查完才發現叫不出來
Future<bool> _notificationChannelWorks() async {
  try {
    final r = await Process.run('osascript', ['-e', 'return 1']);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}
