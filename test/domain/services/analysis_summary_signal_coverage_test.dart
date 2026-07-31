import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';

/// 結構守門(2026-08-01 複審):每個 ReasonType 都必須有 summary builder。
///
/// 缺席的訊號在 AI 摘要的「關鍵訊號/風險提示」會被靜默濾掉——同一 bug
/// class 已發生兩次(回檔 v2 主訊號 2026-07-23、MA 穿越 6 訊號
/// 2026-07-31),逐案修補擋不住下一批新規則,改結構斷言。
void main() {
  test('每個 ReasonType 都有 summary signal builder(無靜默濾除)', () {
    final codes = AnalysisSummaryService.summarySignalCodes;
    final missing = ReasonType.values
        .where((t) => !codes.contains(t.code))
        .map((t) => t.code)
        .toList();
    expect(
      missing,
      isEmpty,
      reason:
          '以下 ReasonType 缺 summary builder,觸發時摘要不會提及: $missing。'
          '請在 analysis_summary_service.dart 對應分類 map 補上 builder'
          '(i18n key 慣例 summary.<code>)。',
    );
  });
}
