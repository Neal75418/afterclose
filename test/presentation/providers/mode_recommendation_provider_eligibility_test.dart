// Unit tests for the pure helpers exposed by mode_recommendation_provider —
// `isEligibleForMode` predicate + `computeBiasMa20ForHistory`.
//
// 2026-06-19 audit Action 5b: filter-aware mode assignment. Predicate is the
// single source of truth for which mode a stock is allowed to land in.

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/analysis_dao.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';

void main() {
  group('isEligibleForMode — Mode A (momentumEntry) — 乖離率 gate', () {
    test('eligible when today and bias both within thresholds', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 5.0,
          biasMa20: 5.0,
        ),
        isTrue,
      );
    });

    test('ineligible when today > +8%', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 8.01,
          biasMa20: 0.0,
        ),
        isFalse,
      );
    });

    test('keeps stock at exact +8% today boundary (strict >)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 8.0,
          biasMa20: 0.0,
        ),
        isTrue,
      );
    });

    test('ineligible when MA20 bias > +15% (6742-style 已漲一波)', () {
      // 6742 澤米：乖離 +15.7% → 過度延伸、踢出
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 57),
          todayPct: 2.0,
          biasMa20: 15.7,
        ),
        isFalse,
      );
    });

    test('high score does NOT exempt extended stock (豁免已移除)', () {
      // 強訊號不再豁免延伸：score 90 但乖離 +20% → 仍踢出
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 90),
          todayPct: 2.0,
          biasMa20: 20.0,
        ),
        isFalse,
      );
    });

    test('keeps stock at exact +15% bias boundary (strict >)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 2.0,
          biasMa20: 15.0,
        ),
        isTrue,
      );
    });

    test('eligible when bias modest (貼均線早期移動)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 3.0,
          biasMa20: 8.0,
        ),
        isTrue,
      );
    });

    test('null bias (history < 20) treated as permissive', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: 3.0,
          biasMa20: null,
        ),
        isTrue,
      );
    });

    test('null today treated as pass (data lag / new IPO)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 30),
          todayPct: null,
          biasMa20: null,
        ),
        isTrue,
      );
    });

    test('today gap-up excludes even when bias modest (導去 Mode B)', () {
      // 從低於 MA20 跳上來：乖離還小但今天 +10% → today gate 擋
      expect(
        isEligibleForMode(
          mode: ScoringMode.momentumEntry,
          score: _score(short: 40),
          todayPct: 10.0,
          biasMa20: 3.0,
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
        ),
        isTrue,
      );
    });
  });

  // **2026-06-19 v2 audit — Mode C 重定義為「回檔觀察 / 強股回檔進場」**
  // - 從「負分警示」改「正分機會」tab
  // - 必過 gate：至少 1 條主訊號 rule fire（PULLBACK_TO_MA20 / HAMMER_AT_SUPPORT /
  //   KD_HIGH_PULLBACK / PATTERN_HAMMER）
  // - todayPct in [-4%, 0%]（回檔但非崩跌）
  // - score ≥ +12（最弱主訊號 kdHighPullback 的分數）
  group('isEligibleForMode — Mode C v2 (回檔觀察 pullbackEntry)', () {
    const mainSignalGate = {'PULLBACK_TO_MA20'};

    test('eligible when all conditions met (主訊號 + 今日 ≤0 + score ≥12)', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: -1.5,
          triggeredReasonCodes: mainSignalGate,
        ),
        isTrue,
      );
    });

    test('mode_c_keeps_stock_at_exact_0pct_today_boundary', () {
      // strict `>` so 0.00% stays
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: 0.0,
          triggeredReasonCodes: mainSignalGate,
        ),
        isTrue,
      );
    });

    test('mode_c_drops_stock_at_tiny_positive_today', () {
      // 0.01% > 0% → 擋
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: 0.01,
          triggeredReasonCodes: mainSignalGate,
        ),
        isFalse,
      );
    });

    test('mode_c_drops_stock_at_min_today_boundary (-4.01%)', () {
      // 深 V 不算健康回檔
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: -4.01,
          triggeredReasonCodes: mainSignalGate,
        ),
        isFalse,
      );
    });

    test('mode_c_keeps_stock_at_exact_min_today (-4.00%)', () {
      // strict `<` so -4.00% stays
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: -4.0,
          triggeredReasonCodes: mainSignalGate,
        ),
        isTrue,
      );
    });

    test('mode_c_rejects_when_no_main_signal_fires (gate)', () {
      // 只有 warning rule fire、無主訊號 → drop
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: -1.0,
          triggeredReasonCodes: const {'RSI_EXTREME_OVERBOUGHT'},
        ),
        isFalse,
      );
    });

    test('mode_c_rejects_when_score_below_min_12', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 11),
          todayPct: -1.0,
          triggeredReasonCodes: mainSignalGate,
        ),
        isFalse,
      );
    });

    test('mode_c_keeps_at_exact_min_score_12', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 12),
          todayPct: -1.0,
          triggeredReasonCodes: mainSignalGate,
        ),
        isTrue,
      );
    });

    test(
      'mode_c_accepts_other_main_signals (HAMMER_AT_SUPPORT / KD_HIGH_PULLBACK)',
      () {
        for (final code in ['HAMMER_AT_SUPPORT', 'KD_HIGH_PULLBACK']) {
          expect(
            isEligibleForMode(
              mode: ScoringMode.weaknessObserve,
              score: _score(short: 15),
              todayPct: -1.0,
              triggeredReasonCodes: {code},
            ),
            isTrue,
            reason: 'main signal $code should pass gate',
          );
        }
      },
    );

    test('null_today_pct_with_gate_treated_as_pass — mode C', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: null,
          triggeredReasonCodes: mainSignalGate,
        ),
        isTrue,
      );
    });

    test('empty_triggered_codes_default_fails_gate', () {
      // 預設 triggeredReasonCodes 空 set → gate 失敗
      expect(
        isEligibleForMode(
          mode: ScoringMode.weaknessObserve,
          score: _score(short: 15),
          todayPct: -1.0,
        ),
        isFalse,
      );
    });
  });

  // Mode B 從 v2 加 `todayPct > 0` 排他條件（讓 Mode C 接走回檔股）
  group('isEligibleForMode — Mode B v2 排他 today ≤ 0', () {
    test('mode_b_rejects_today_negative_to_let_mode_c_handle', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 30),
          todayPct: -1.0,
        ),
        isFalse,
      );
    });

    test('mode_b_rejects_today_zero_to_let_mode_c_handle', () {
      // strict `<=` Mode C maxTodayPct(0) → today=0 也讓給 C
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 30),
          todayPct: 0.0,
        ),
        isFalse,
      );
    });

    test('mode_b_keeps_today_positive', () {
      expect(
        isEligibleForMode(
          mode: ScoringMode.strengthObserve,
          score: _score(short: 30),
          todayPct: 0.1,
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
        ),
        isFalse,
      );
    });
  });

  group('computeBiasMa20ForHistory', () {
    test('returns null when history is null', () {
      expect(computeBiasMa20ForHistory(null), isNull);
    });

    test('returns null when history.length < 20', () {
      final h = List.generate(19, (_) => _price(100));
      expect(computeBiasMa20ForHistory(h), isNull);
    });

    test('returns null when any close in MA20 window is null', () {
      final h = List.generate(20, (i) => _price(i == 5 ? null : 100));
      expect(computeBiasMa20ForHistory(h), isNull);
    });

    test('returns null when latest close is null', () {
      final h = List.generate(20, (i) => _price(i == 19 ? null : 100));
      expect(computeBiasMa20ForHistory(h), isNull);
    });

    test('returns null when MA20 is 0 (all zero closes)', () {
      final h = List.generate(20, (_) => _price(0));
      expect(computeBiasMa20ForHistory(h), isNull);
    });

    test('computes +10% bias (MA20=100, latest=110)', () {
      // 10×90 + 10×110 → MA20 = 100, latest = 110 → +10%
      final h = [
        ...List.generate(10, (_) => _price(90)),
        ...List.generate(10, (_) => _price(110)),
      ];
      expect(computeBiasMa20ForHistory(h), closeTo(10.0, 0.001));
    });

    test('negative bias when latest below MA20', () {
      // 10×110 + 10×90 → MA20 = 100, latest = 90 → -10%
      final h = [
        ...List.generate(10, (_) => _price(110)),
        ...List.generate(10, (_) => _price(90)),
      ];
      expect(computeBiasMa20ForHistory(h), closeTo(-10.0, 0.001));
    });

    test('uses last 20 closes only — ignores older history', () {
      // 前置極端值落在 MA20 窗口外、不影響
      final h = [
        _price(99999),
        ...List.generate(10, (_) => _price(90)),
        ...List.generate(10, (_) => _price(110)),
      ];
      expect(computeBiasMa20ForHistory(h), closeTo(10.0, 0.001));
    });
  });

  group('computeRet60dForHistory', () {
    test('returns null when history is null', () {
      expect(computeRet60dForHistory(null), isNull);
    });

    test('returns null when history.length < 61', () {
      final h = List.generate(60, (_) => _price(100));
      expect(computeRet60dForHistory(h), isNull);
    });

    test('returns null when oldest (index length-61) close is 0', () {
      final h = [
        _price(0),
        ...List.generate(59, (_) => _price(120)),
        _price(150),
      ];
      expect(computeRet60dForHistory(h), isNull);
    });

    test('returns null when oldest close is null', () {
      final h = [
        _price(null),
        ...List.generate(59, (_) => _price(120)),
        _price(150),
      ];
      expect(computeRet60dForHistory(h), isNull);
    });

    test('returns null when latest close is null', () {
      final h = [
        _price(100),
        ...List.generate(59, (_) => _price(120)),
        _price(null),
      ];
      expect(computeRet60dForHistory(h), isNull);
    });

    test('computes +50% (index length-61 = 100, last = 150)', () {
      final h = [
        _price(100), // [length-61]
        ...List.generate(59, (_) => _price(120)), // ignored
        _price(150), // last
      ];
      expect(computeRet60dForHistory(h), closeTo(50.0, 0.001));
    });

    test('uses index length-61, not 60 — accommodates longer history', () {
      // length 62：比較 index 1 (length-61) vs index 61 (last)
      final h = [
        _price(999), // ignored
        _price(200), // [length-61]
        ...List.generate(59, (_) => _price(210)),
        _price(220), // last
      ];
      expect(computeRet60dForHistory(h), closeTo(10.0, 0.001));
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
