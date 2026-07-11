import 'package:flutter_test/flutter_test.dart';
import 'package:afterclose/core/constants/exit_params.dart';
import 'package:afterclose/core/constants/rule_params.dart';

void main() {
  test('ExitParams 常數值（spec §2 起始值，gate 後可調）', () {
    expect(ExitParams.hardStopPct, 0.08);
    expect(ExitParams.timeStopTradingDays, 40);
    expect(ExitParams.ma60Window, 60);
    expect(ExitParams.holdHorizonTradingDays, 60);
    expect(ExitParams.minCellSample, 30);
    expect(ExitParams.modeSignalScoreThreshold, RuleParams.minScoreThreshold);
  });

  test('ExitReason 宣告順序 = 同日 tie-break 優先序', () {
    expect(ExitReason.values, [
      ExitReason.hardStop,
      ExitReason.trendBreak,
      ExitReason.timeStop,
    ]);
  });
}
