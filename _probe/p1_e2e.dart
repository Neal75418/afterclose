// TEMP PROBE — delete after verification run.
// 走與 tool/intraday_alert_check.dart 完全相同的程式碼路徑,只是 DB 指向副本。
import 'dart:io';

import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/intraday_alert_monitor.dart';

Future<void> main(List<String> args) async {
  final dbPath = args[0];
  final db = AppDatabase.forToolFile(dbPath);
  final client = IntradayQuoteClient();
  try {
    // 1) 插入一筆「必觸發」的提醒
    final id = await db.createPriceAlert(
      symbol: '2330',
      alertType: 'ABOVE',
      targetValue: 1.0,
      note: 'PROBE-must-fire',
    );
    print('[probe] inserted alert id=$id 2330 ABOVE 1.0');

    final before = await db.getAlertById(id);
    print(
      '[probe] before: isActive=${before!.isActive} '
      'triggeredAt=${before.triggeredAt}',
    );

    // 2) 第一輪 check()
    final r1 = await IntradayAlertMonitor(
      database: db,
      client: client,
    ).check(now: DateTime.now());
    print(
      '[probe] run1 fired=${r1.fired.length} '
      'quotesFetched=${r1.quotesFetched} symbolsWanted=${r1.symbolsWanted}',
    );
    for (final f in r1.fired) {
      print(
        '[probe] run1 FIRED ${f.alert.id} ${f.alert.symbol} '
        '${f.alert.alertType} ${f.alert.targetValue} '
        'note=${f.alert.note} price=${f.quote.price} t=${f.quote.time}',
      );
    }

    // 3) 真的發通知(與 CLI 同一段 osascript)
    var notified = 0;
    for (final f in r1.fired) {
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
      if (ok) notified++;
    }
    print('[probe] notified=$notified/${r1.fired.length}');

    final afterRun1 = await db.getAlertById(id);
    print(
      '[probe] after run1: isActive=${afterRun1!.isActive} '
      'triggeredAt=${afterRun1.triggeredAt}',
    );

    // 4) 直接再 claim 一次 → 必須 false
    final claimAgain = await db.claimAlertTrigger(id);
    print('[probe] claimAlertTrigger(second call) = $claimAgain');

    // 5) 第二輪 check() → 不應再 fire
    final r2 = await IntradayAlertMonitor(
      database: db,
      client: client,
    ).check(now: DateTime.now());
    print(
      '[probe] run2 fired=${r2.fired.length} '
      'quotesFetched=${r2.quotesFetched} symbolsWanted=${r2.symbolsWanted}',
    );

    // 6) 清掉自己插入的列並驗證
    await db.deletePriceAlert(id);
    final gone = await db.getAlertById(id);
    print(
      '[probe] cleanup: getAlertById($id) = ${gone == null ? 'null (deleted)' : 'STILL PRESENT'}',
    );
  } catch (e, s) {
    print('[probe] FAILED: $e');
    print(s);
    exitCode = 1;
  } finally {
    client.close();
    await db.close();
  }
}

Future<bool> _notify({required String title, required String body}) async {
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
    print('[probe] 通知失敗: ${result.stderr}');
    return false;
  }
  return true;
}
