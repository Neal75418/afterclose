import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/signal_names.dart';

/// MA 四階段優先序(2026-07-31):自選 tags 前置排序的契約。
/// 跌破(風控)必須最前——ReasonTags 只顯示 1-2 個,排序錯=風控被擠出視窗。
void main() {
  test('優先序:跌破 < 站回 < 回踩 < 蓄勢 < 其他', () {
    expect(SignalName.maStagePriority(SignalName.breakMa60), 0);
    expect(SignalName.maStagePriority(SignalName.breakMa20), 0);
    expect(SignalName.maStagePriority(SignalName.reclaimMa60), 1);
    expect(SignalName.maStagePriority(SignalName.pullbackToMa10), 2);
    expect(SignalName.maStagePriority(SignalName.coilingBelowMa60), 3);
    expect(SignalName.maStagePriority('KD_GOLDEN_CROSS'), 9);
  });

  test('排序實效:混合清單跌破排最前', () {
    final reasons = ['KD_GOLDEN_CROSS', 'COILING_BELOW_MA20', 'BREAK_MA60']
      ..sort(
        (a, b) => SignalName.maStagePriority(
          a,
        ).compareTo(SignalName.maStagePriority(b)),
      );
    expect(reasons.first, 'BREAK_MA60');
    expect(reasons[1], 'COILING_BELOW_MA20');
  });
}
