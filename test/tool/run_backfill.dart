// Stage 3 operational runner — wraps tool/backfill.dart main logic in a
// flutter_test `test()` block so it can execute with Flutter runtime (where
// `dart:ui` + `drift_flutter` are available), since `dart run tool/backfill.dart`
// fails at compile time due to transitive `dart:ui` imports through logger.dart.
//
// This is NOT a unit test. It's a CLI invocation wrapper intended to be run
// by `scripts/calibrate.sh`. The `test()` block is purely a vehicle for the
// flutter test runner to load the Flutter Dart runtime.
//
// ## How it gets its arguments
//
// Arguments come from environment variables set by `scripts/calibrate.sh`:
//
//   FINMIND_TOKEN    required — FinMind API token
//   BACKFILL_YEARS   optional — default 2
//   CALIBRATION_DB   optional — default tool/calibration.db
//   BACKFILL_SYMBOLS optional — CSV whitelist, e.g. "2330,2317"
//   BACKFILL_DRY_RUN optional — set to "1" to enable dry run

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/backfill.dart' as backfill;

void main() {
  test('Stage 3: historical backfill', () async {
    final args = <String>[];

    final years = Platform.environment['BACKFILL_YEARS'];
    if (years != null && years.isNotEmpty) {
      args.addAll(['--years', years]);
    }

    // 精準區間覆寫（例：只補 2021-2023，不重抓既有 2024-2026）
    final startDate = Platform.environment['BACKFILL_START_DATE'];
    if (startDate != null && startDate.isNotEmpty) {
      args.addAll(['--start-date', startDate]);
    }
    final endDate = Platform.environment['BACKFILL_END_DATE'];
    if (endDate != null && endDate.isNotEmpty) {
      args.addAll(['--end-date', endDate]);
    }

    final db = Platform.environment['CALIBRATION_DB'];
    if (db != null && db.isNotEmpty) {
      args.addAll(['--db', db]);
    }

    final symbols = Platform.environment['BACKFILL_SYMBOLS'];
    if (symbols != null && symbols.isNotEmpty) {
      args.addAll(['--symbols', symbols]);
    }

    if (Platform.environment['BACKFILL_DRY_RUN'] == '1') {
      args.add('--dry-run');
    }

    // Token is read from FINMIND_TOKEN env var inside backfill.dart's
    // _parseArgs — no need to pass explicitly here.
    final code = await backfill.runBackfillCli(args);
    expect(
      code,
      0,
      reason:
          'backfill should exit 0; got $code. Exit codes: '
          '1=invalid args, 3=partial failure, 4=rate limit, 5=network',
    );
  }, timeout: Timeout.none);
}
