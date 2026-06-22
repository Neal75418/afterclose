// A3 walk-forward 驗證的 flutter test wrapper（同 run_backfill / run_replay 設計）。
//
// 因 walkforward_validate.dart 透過 AppDatabase 間接 import drift_flutter→dart:ui，
// 純 `dart run` compile fail，故包在 flutter test 內跑。
//
// env：CALIBRATION_DB（預設 tool/calibration.db）、WF_FOLD_YEARS（CSV）。
// 由 scripts 在 backfill + replay 後呼叫。NOT a unit test — 是 CLI 執行載體。
import 'package:flutter_test/flutter_test.dart';

import '../../tool/walkforward_validate.dart' as wf;

void main() {
  test('A3: walk-forward out-of-sample validation', () async {
    final code = await wf.runWalkForwardCli([]);
    // exit code：0 = gate PASS、1 = gate FAIL（兩者都是有效結論）、
    //           2 = 無 DB、3 = 無現行 calibrated JSON（setup 問題）。
    expect(
      code,
      lessThan(2),
      reason:
          'walk-forward 應正常完成（0=PASS / 1=FAIL 都算成功跑完）；'
          '2=無DB、3=無calibrated JSON 才是 setup 錯誤',
    );
  }, timeout: Timeout.none);
}
