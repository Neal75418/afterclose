import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// domain 層純度守門(2026-08-01 全專案 smell 掃描 Tier 1)。
///
/// 四層架構方向不變量:domain **不得 import presentation**。
/// data→domain 是 architecture.md 明文畫出的合法箭頭(Drift entry 當
/// 共用資料型別),不在禁止之列。
///
/// 這不是假設性防護:CHANGELOG 0.4.0(2026-03-25)記載
/// 「消除循環依賴:Domain→Presentation import 消除,13 個 data struct
/// 搬至 domain/models/」——同型違規真實發生過一次,修完後只靠人工
/// 紀律維持,此測試補上 CI 鎖(與 core_layer_purity_test 同 pattern)。
void main() {
  test('lib/domain 不得 import presentation', () {
    final importRe = RegExp(
      r'''import\s+['"]package:afterclose/presentation/''',
    );
    final violations = <String>[];
    for (final entity in Directory('lib/domain').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (importRe.hasMatch(lines[i])) {
          violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'domain 層出現對 presentation 的依賴(把型別搬到 domain/models,'
          '或把 UI 邏輯上移 presentation):\n${violations.join('\n')}',
    );
    // sanity:確實掃到了檔案(防路徑錯誤假綠)
    expect(
      Directory(
        'lib/domain',
      ).listSync(recursive: true).whereType<File>().length,
      greaterThan(50),
    );
  });
}
