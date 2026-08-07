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

import 'package:daredevil/core/utils/logger.dart';
import 'package:daredevil/core/utils/taiwan_time.dart';
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/intraday_alert_monitor.dart';
import 'package:daredevil/domain/services/alert/intraday_poll_schedule.dart';

Future<void> main(List<String> args) async {
  final now = TaiwanTime.now();
  final force = args.contains('--force');

  if (!force && !IntradayPollSchedule.isMarketHours(now)) {
    // 非交易時段是常態(一天 288 次喚醒裡約 234 次落在這裡),不印噪音
    exit(0);
  }

  final dbPath =
      '${Platform.environment['HOME']}'
      '/Library/Containers/com.neo.afterclose/Data/Documents/afterclose.sqlite';
  if (!File(dbPath).existsSync()) {
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
      // 報價全滅 ≠ 沒到價:這是故障,要能從 exit code 看出來
      stderr.writeln('[intraday_alert] 報價全數失敗,本輪判定不可信');
      exit(1);
    }
    if (fired.isEmpty) {
      if (force) print('[intraday_alert] 本輪無觸價');
      exit(0);
    }

    for (final f in fired) {
      final direction = f.alert.alertType == 'ABOVE' ? '突破' : '跌破';
      final label = f.alert.note ?? '$direction ${f.alert.targetValue}';
      await _notify(
        title: '${f.quote.symbol} ${f.quote.name} $label',
        body:
            '現價 ${f.quote.price.toStringAsFixed(2)}'
            '(${f.quote.changePercent >= 0 ? '+' : ''}'
            '${f.quote.changePercent.toStringAsFixed(2)}%)'
            ' · ${f.quote.time ?? ''}',
      );
    }
    print('[intraday_alert] 觸價 ${fired.length} 筆,已通知');
    exit(0);
  } catch (e, s) {
    AppLogger.error('intraday_alert', 'unhandled', e, s);
    stderr.writeln('[intraday_alert] FAILED: $e');
    exit(1);
  } finally {
    await database?.close();
  }
}

/// macOS 原生通知。CLI 不能用 flutter_local_notifications(純 Dart 鐵律),
/// osascript 是不需額外相依、在 app 關閉時也能發通知的原生管道。
///
/// 字串以雙引號包入 AppleScript,故需轉義 `\` 與 `"`;股票名稱理論上
/// 不含這些字元,但通知內容來自外部 API,不做假設。
Future<void> _notify({required String title, required String body}) async {
  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  final script =
      'display notification "${esc(body)}" '
      'with title "Daredevil" subtitle "${esc(title)}"';
  final result = await Process.run('osascript', ['-e', script]);
  if (result.exitCode != 0) {
    stderr.writeln('[intraday_alert] 通知失敗: ${result.stderr}');
  }
}
