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
    expect(after.length, lessThanOrEqualTo(2000));
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
  });
}
