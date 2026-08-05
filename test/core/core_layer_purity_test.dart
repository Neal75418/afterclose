import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// core 層純度守門(2026-07-30 Batch 4B)。
///
/// 四層架構的方向不變量:core 是最底層,**不得 import domain/data/
/// presentation**。歷史上 core 累積了 5 個越層檔(price_calculator、
/// liquidity_checker、cache_warmup_service、filter_metadata、
/// semantic_colors 的 chip_strength 依賴),多角色審查給架構 7.0 分的
/// 主因——已全數歸位。此測試鎖住不變量,新增 core 檔案混入上層 import
/// 時在 CI 直接紅。
void main() {
  test('lib/core 不得 import domain/data/presentation', () {
    final importRe = RegExp(
      // 2026-08-05 複審補強:同 domain 守門——export 與相對路徑亦攔。
      r'''(import|export)\s+['"](package:afterclose/(domain|data|presentation)/|\.[^'"]*/(domain|data|presentation)/)''',
    );
    final violations = <String>[];
    for (final entity in Directory('lib/core').listSync(recursive: true)) {
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
          'core 層出現向上依賴(把檔案搬到正確層,或把純值物件下沉 core):\n'
          '${violations.join('\n')}',
    );
    // sanity:確實掃到了檔案(防路徑錯誤假綠)
    expect(
      Directory('lib/core').listSync(recursive: true).whereType<File>().length,
      greaterThan(30),
    );
  });
}
