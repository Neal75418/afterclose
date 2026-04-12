// Stage 4 operational runner — wraps tool/replay_calibrator.dart main logic
// in a flutter_test `test()` block. See run_backfill.dart for rationale.
//
// ## Environment variables (set by scripts/calibrate.sh)
//
//   CALIBRATION_DB     optional — default tool/calibration.db
//   REPLAY_MIN_HISTORY optional — default RuleParams.swingWindow
//   REPLAY_SYMBOLS     optional — CSV whitelist for quick test runs
//   REPLAY_DRY_RUN     optional — set to "1" to enable dry run

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/replay_calibrator.dart' as replay;

void main() {
  test('Stage 4: replay calibrator', () async {
    final args = <String>[];

    final db = Platform.environment['CALIBRATION_DB'];
    if (db != null && db.isNotEmpty) {
      args.addAll(['--db', db]);
    }

    final minHistory = Platform.environment['REPLAY_MIN_HISTORY'];
    if (minHistory != null && minHistory.isNotEmpty) {
      args.addAll(['--min-history', minHistory]);
    }

    final symbols = Platform.environment['REPLAY_SYMBOLS'];
    if (symbols != null && symbols.isNotEmpty) {
      args.addAll(['--symbols', symbols]);
    }

    if (Platform.environment['REPLAY_DRY_RUN'] == '1') {
      args.add('--dry-run');
    }

    final code = await replay.runReplayCalibratorCli(args);
    expect(
      code,
      0,
      reason:
          'replay should exit 0; got $code. Exit codes: '
          '1=invalid args, 2=DB missing, 3=no firings',
    );
  }, timeout: Timeout.none);
}
