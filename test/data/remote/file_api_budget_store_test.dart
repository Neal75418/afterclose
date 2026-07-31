import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/file_api_budget_store.dart';

/// FileApiBudgetStore(launchd CLI 配額持久化)的檔案語意(2026-08-01 複審)。
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('budget_store'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('save→load roundtrip;temp 檔不殘留(原子 rename)', () async {
    final store = FileApiBudgetStore('${tempDir.path}/b.json');
    await store.save('{"finmind":[1,2,3]}');
    expect(await store.load(), '{"finmind":[1,2,3]}');
    expect(
      File('${tempDir.path}/b.json.tmp').existsSync(),
      isFalse,
      reason: 'rename 後 tmp 不得殘留',
    );
  });

  test('無檔案 → load 回 null(首跑)', () async {
    final store = FileApiBudgetStore('${tempDir.path}/missing.json');
    expect(await store.load(), isNull);
  });

  test('覆寫:第二次 save 取代第一次', () async {
    final store = FileApiBudgetStore('${tempDir.path}/b.json');
    await store.save('v1');
    await store.save('v2');
    expect(await store.load(), 'v2');
  });
}
