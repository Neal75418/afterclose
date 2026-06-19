// Unit tests for the pure helpers exposed by mode_recommendation_provider —
// `isEligibleForMode` predicate + `computeRet5dForHistory`.
//
// 2026-06-19 audit Action 5b: filter-aware mode assignment. Predicate is the
// single source of truth for which mode a stock is allowed to land in.

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/analysis_dao.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';

void main() {
  group('isEligibleForMode — Mode A (momentumEntry)', () {
    test('eligible when today and 5D both within thresholds', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 5.0,
          ret5d: 5.0,
        ),
        isTrue,
      );
    });

    test('ineligible when today > +8% (no override)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 8.01,
          ret5d: 0.0,
        ),
        isFalse,
      );
    });

    test('mode_a_keeps_stock_at_exact_8pct_today_boundary', () {
      // strict `>` so 8.00% stays
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 8.0,
          ret5d: 0.0,
        ),
        isTrue,
      );
    });

    test('score_override_bypasses_5d_filter_but_not_today', () {
      // 5D > 8% but score >= 50 → 5D 不擋；today 2% < 8% → today 不擋 → eligible
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 60),
          todayPct: 2.0,
          ret5d: 15.0,
        ),
        isTrue,
      );
    });

    test('score_override_does_NOT_bypass_today_filter', () {
      // 6651-style: high score but today gap-up
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 80),
          todayPct: 10.0,
          ret5d: 2.0,
        ),
        isFalse,
      );
    });

    test('mode_a_eligible_when_history_below_6_closes (ret5d null)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 3.0,
          ret5d: null,
        ),
        isTrue,
      );
    });

    test('null_today_pct_treated_as_pass (data lag / new IPO)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: null,
          ret5d: null,
        ),
        isTrue,
      );
    });

    test('5d_filter_excludes_when_no_override', () {
      // 5D > 8%, score < 50 → 5D 擋
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 2.0,
          ret5d: 9.0,
        ),
        isFalse,
      );
    });
  });

  group('isEligibleForMode — Mode B (strengthObserve)', () {
    test('eligible when score > 0', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 1),
          todayPct: null,
          ret5d: null,
        ),
        isTrue,
      );
    });

    test('mode_b_rejects_zero_score_row', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 0),
          todayPct: null,
          ret5d: null,
        ),
        isFalse,
      );
    });

    test('mode_b_rejects_negative_score', () {
      // Rare: a Mode B rule scored negatively
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: -15),
          todayPct: null,
          ret5d: null,
        ),
        isFalse,
      );
    });

    test('mode_b_indifferent_to_price_filters', () {
      // 強勢觀察沒 price gate；只看 score 正性
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 50),
          todayPct: 10.0,
          ret5d: 20.0,
        ),
        isTrue,
      );
    });
  });

  group('isEligibleForMode — Mode C (weaknessObserve)', () {
    test('eligible when today ≤ 0 and score < 0', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: -20),
          todayPct: -1.5,
          ret5d: null,
        ),
        isTrue,
      );
    });

    test('mode_c_keeps_stock_at_exact_0pct_today_boundary', () {
      // strict `>` so 0.00% stays
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: -20),
          todayPct: 0.0,
          ret5d: null,
        ),
        isTrue,
      );
    });

    test('mode_c_drops_stock_at_tiny_positive_today', () {
      // 0.01% > 0% → 擋
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: -20),
          todayPct: 0.01,
          ret5d: null,
        ),
        isFalse,
      );
    });

    test('mode_c_rejects_zero_score_row', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 0),
          todayPct: -1.0,
          ret5d: null,
        ),
        isFalse,
      );
    });

    test('mode_c_rejects_positive_score', () {
      // 不應發生（Mode C rule 都是負分）但 defensive 該擋
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 5),
          todayPct: -1.0,
          ret5d: null,
        ),
        isFalse,
      );
    });

    test('null_today_pct_treated_as_pass — mode C', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: -20),
          todayPct: null,
          ret5d: null,
        ),
        isTrue,
      );
    });
  });

  group('isEligibleForMode — neutral', () {
    test('neutral mode never eligible (not user-facing)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.neutral,
          score: _score(short: 50),
          todayPct: 0.0,
          ret5d: 0.0,
        ),
        isFalse,
      );
    });
  });

  group('computeRet5dForHistory', () {
    test('returns null when history is null', () {
      expect(computeRet5dForHistory(null), isNull);
    });

    test('returns null when history.length < 6', () {
      final h = [
        _price(100),
        _price(101),
        _price(102),
        _price(103),
        _price(104),
      ];
      expect(computeRet5dForHistory(h), isNull);
    });

    test('returns null when oldest close is 0', () {
      final h = [
        _price(0),
        _price(101),
        _price(102),
        _price(103),
        _price(104),
        _price(105),
      ];
      expect(computeRet5dForHistory(h), isNull);
    });

    test('returns null when oldest close is null', () {
      final h = [
        _price(null),
        _price(101),
        _price(102),
        _price(103),
        _price(104),
        _price(105),
      ];
      expect(computeRet5dForHistory(h), isNull);
    });

    test('returns null when latest close is null', () {
      final h = [
        _price(100),
        _price(101),
        _price(102),
        _price(103),
        _price(104),
        _price(null),
      ];
      expect(computeRet5dForHistory(h), isNull);
    });

    test('computes +10% for valid history', () {
      // index 0 (length-6) = 100, last = 110 → +10%
      final h = [
        _price(100),
        _price(102),
        _price(104),
        _price(106),
        _price(108),
        _price(110),
      ];
      expect(computeRet5dForHistory(h), closeTo(10.0, 0.001));
    });

    test('computes -5% for negative return', () {
      final h = [
        _price(100),
        _price(98),
        _price(96),
        _price(96),
        _price(95),
        _price(95),
      ];
      expect(computeRet5dForHistory(h), closeTo(-5.0, 0.001));
    });

    test('uses index length-6, not 5 — accommodates longer history', () {
      // length 8: comparison is index 2 (length-6) vs index 7 (last)
      // index 2 = 200, index 7 = 220 → +10%
      final h = [
        _price(50), // ignored
        _price(100), // ignored
        _price(200), // [length-6]
        _price(205),
        _price(210),
        _price(215),
        _price(218),
        _price(220), // last
      ];
      expect(computeRet5dForHistory(h), closeTo(10.0, 0.001));
    });
  });
}

/// 建立 ModeStockScore 的 helper（test 內最常用 short 分數）
ModeStockScore _score({
  required int short,
  int long = 0,
  String symbol = 'TEST',
}) => ModeStockScore(
  symbol: symbol,
  modeScoreShort: short.toDouble(),
  modeScoreLong: long.toDouble(),
  reasonCount: 1,
);

/// 建立 DailyPriceEntry 的 helper — 只關心 close
DailyPriceEntry _price(double? close) =>
    DailyPriceEntry(symbol: 'TEST', date: DateTime(2026, 6, 18), close: close);
