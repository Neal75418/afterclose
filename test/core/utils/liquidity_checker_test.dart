import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/liquidity_checker.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  DailyPriceEntry makePrice({double? close, double? volume}) {
    return DailyPriceEntry(
      symbol: 'TEST',
      date: now,
      open: close,
      high: close,
      low: close,
      close: close,
      volume: volume,
      priceChange: null,
    );
  }

  group('LiquidityChecker.checkCandidateLiquidity', () {
    test('returns null when all checks pass', () {
      // close=100, volume=2000000 → turnover=200M > 30M
      final entry = makePrice(close: 100.0, volume: 2000000);
      expect(LiquidityChecker.checkCandidateLiquidity(entry), isNull);
    });

    test('returns MISSING_DATA when close is null', () {
      final entry = makePrice(close: null, volume: 2000000);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('MISSING_DATA'),
      );
    });

    test('returns MISSING_DATA when volume is null', () {
      final entry = makePrice(close: 100.0, volume: null);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('MISSING_DATA'),
      );
    });

    test('returns MISSING_DATA when both close and volume are null', () {
      final entry = makePrice(close: null, volume: null);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('MISSING_DATA'),
      );
    });

    test('returns LOW_VOLUME when volume below threshold', () {
      // minCandidateVolumeShares = 1,000,000
      final entry = makePrice(close: 100.0, volume: 500000);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('LOW_VOLUME'),
      );
    });

    test('returns LOW_TURNOVER when turnover below threshold', () {
      // volume passes (1,500,000 >= 1,000,000)
      // but turnover = 10 * 1,500,000 = 15M < 30M
      final entry = makePrice(close: 10.0, volume: 1500000);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('LOW_TURNOVER'),
      );
    });

    test('passes at exact volume threshold', () {
      // volume = exactly 1,000,000 (minCandidateVolumeShares)
      // turnover = 100 * 1,000,000 = 100M > 30M
      final entry = makePrice(
        close: 100.0,
        volume: RuleParams.minCandidateVolumeShares,
      );
      expect(LiquidityChecker.checkCandidateLiquidity(entry), isNull);
    });

    test('passes at exact turnover threshold', () {
      // volume = 1,500,000 (passes)
      // turnover = 20 * 1,500,000 = 30M = minCandidateTurnover
      final entry = makePrice(
        close: RuleParams.minCandidateTurnover / 1500000,
        volume: 1500000,
      );
      expect(LiquidityChecker.checkCandidateLiquidity(entry), isNull);
    });

    test('LOW_VOLUME takes priority over LOW_TURNOVER', () {
      // volume = 100 < 1,000,000 → LOW_VOLUME (checked first)
      // turnover = 1 * 100 = 100 < 30M → would also be LOW_TURNOVER
      final entry = makePrice(close: 1.0, volume: 100);
      expect(
        LiquidityChecker.checkCandidateLiquidity(entry),
        equals('LOW_VOLUME'),
      );
    });
  });
}
