import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/utils/log_rotation.dart';

/// CLI 日誌自輪替(2026-08-08)。
///
/// 為什麼不用 newsyslog:那要在 `/etc/newsyslog.d/` 放一個**未版控、
/// 機器本地、換機就消失**的設定——今天已經被同一類東西咬過兩次
/// (plist 只存在 ~/Library 差點靜默失效、live job 跑著舊定義)。
/// 輪替寫進 CLI 就跟著 repo 走、有測試、換機自動生效、不需要 sudo。
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('logrot'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, String content) =>
      File('${tmp.path}/$name')..writeAsStringSync(content);

  test('未超過門檻 → 完全不動', () {
    final f = write('a.log', 'x' * 100);
    final before = f.readAsStringSync();
    LogRotation.rotateIfNeeded(f.path, maxBytes: 1000);
    expect(f.readAsStringSync(), before);
  });

  test('🚨 超過門檻 → 只留尾端,且保留完整行(不從半行切斷)', () {
    final lines = List.generate(500, (i) => '第 $i 行:一些內容');
    final f = write('b.log', '${lines.join('\n')}\n');
    expect(f.lengthSync(), greaterThan(2000));

    LogRotation.rotateIfNeeded(f.path, maxBytes: 2000);

    final after = f.readAsStringSync();
    // ⚠️ 必須用 lengthSync():`after` 是 Dart String,`.length` 算的是
    // UTF-16 code unit;本測試內容全中文,實測 1041 bytes / 573 units,
    // 比值 1.82——用 .length 當位元組上限等於容許 1.8 倍超標(2026-08-08)
    expect(f.lengthSync(), lessThanOrEqualTo(2000));
    expect(after, contains('第 499 行'), reason: '最新的必須留著');
    expect(after, isNot(contains('第 0 行')), reason: '最舊的被丟掉');
    // 第一行是刻意加的截斷提示;它之後的第一行不可以是被切一半的殘句
    final kept = after.split('\n');
    expect(kept.first, startsWith('--- truncated'));
    expect(kept[1], startsWith('第 '), reason: '不可從半行切斷');
  });

  test('保留提示行,讓人知道日誌被截過(不是資料不見了)', () {
    final f = write(
      'c.log',
      '${List.generate(500, (i) => 'line $i').join('\n')}\n',
    );
    LogRotation.rotateIfNeeded(f.path, maxBytes: 2000);
    expect(f.readAsStringSync(), contains('truncated'));
  });

  test('檔案不存在 → 安靜跳過,不拋例外', () {
    expect(
      () => LogRotation.rotateIfNeeded('${tmp.path}/nope.log', maxBytes: 100),
      returnsNormally,
    );
  });

  test('無換行的單一長行 → 仍能截斷,不無限成長', () {
    final f = write('d.log', 'x' * 5000);
    LogRotation.rotateIfNeeded(f.path, maxBytes: 1000);
    expect(f.lengthSync(), lessThanOrEqualTo(1000));
    // 🚨 舊版只斷言「有變小」,於是把保留量吃到 0 也算通過——見下一個測試。
    expect(f.lengthSync(), greaterThan(100), reason: '截斷不等於清空');
  });

  test('🚨 超長無換行爆量後才換行 → 保留量不可被「切掉殘句」吃光', () {
    // 真實事故形狀(2026-08-08):`dart run` 的進度輸出用 \r 不用 \n,
    // 異常時會一次吐出數十萬位元組的無換行內容。若尾端窗內第一個 \n
    // 落在很後面,「從第一個換行之後開始」就會丟掉幾乎整個保留區——
    // 實測 1.2 MB 的日誌輪替後只剩 104 bytes,**異常當下的證據全滅**。
    // 輪替的目的是限制大小,不是銷毀證據。
    final burst = 'Running build hooks...\r' * 4000; // 遠超保留量、無 \n
    final f = write('e.log', '早期\n$burst\n[log] 最後一次執行\n');
    expect(f.lengthSync(), greaterThan(80000));

    LogRotation.rotateIfNeeded(f.path, maxBytes: 20000);

    final after = f.lengthSync();
    expect(after, lessThanOrEqualTo(20000), reason: '仍須受上限約束');
    // 行為是決定性的:keep = 20000~/2 = 10000;burst 讓尾端窗內第一個
    // \n 落在 index 9974,maxTrim = 10000~/8 = 1250,9974 > 1250 → 不修剪
    // → 恆為 10000 + header。用區間斷言的話,把保留區砍到 5001 也會綠——
    // 而這條測試守的正是今天才炸過的那個 bug(2026-08-08 三次審查)
    expect(
      after,
      closeTo(10065, 40),
      reason: '保留量必須就是 keep(10000)加 header,不可被殘句修剪吃掉',
    );
  });
}
