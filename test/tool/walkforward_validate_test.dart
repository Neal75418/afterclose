// tool/walkforward_validate.dart 單元測試 — 驗純邏輯（指標 + gate + JSON 載入）。
// 完整 run() 走真實 DB + RuleEngine，待 backfill 完成後以實資料端對端驗。
import 'package:flutter_test/flutter_test.dart';

import '../../tool/replay_calibrator.dart' show RuleStats;
import '../../tool/walkforward_validate.dart';

/// 建一個帶指定樣本的 replay RuleStats（短/長各加 sample）。
RuleStats statsWith({
  List<double> short = const [],
  List<double> long = const [],
}) {
  final s = RuleStats();
  for (final r in short) {
    s.short.addSample(r, 0);
  }
  for (final r in long) {
    s.long.addSample(r, 0);
  }
  return s;
}

FoldResult fold(
  int year, {
  required double shortMarginNewSwe,
  required double shortOld,
  required double longNew,
  required double longOld,
}) {
  return FoldResult(
    testYear: year,
    short: HorizonComparison(
      newSwe: shortMarginNewSwe,
      oldSwe: shortOld,
      newActiveRules: 1,
    ),
    long: HorizonComparison(
      newSwe: longNew,
      oldSwe: longOld,
      newActiveRules: 1,
    ),
    testFirings: 100,
  );
}

void main() {
  group('parseCalibratedScores', () {
    test('從 JSON 載入 rule → score（含被 cut 的 0 分）', () {
      const json =
          '{"schema_version":1,"horizon":"5d","rules":{'
          '"RULE_A":{"score":25,"active":true},'
          '"RULE_B":{"score":0,"active":false}}}';
      final scores = parseCalibratedScores(json);
      expect(scores['RULE_A'], 25);
      expect(scores['RULE_B'], 0);
      expect(scores.length, 2);
    });

    test('無 rules 欄 → 空 map（不爆）', () {
      expect(parseCalibratedScores('{"schema_version":1}'), isEmpty);
    });
  });

  group('scoreWeightedExcess', () {
    final testStats = {
      'A': statsWith(short: [10, 10], long: [20, 20]),
      'B': statsWith(short: [2, 2], long: [4, 4]),
    };

    test('以「分數×頻率」加權各 rule 的樣本外超額', () {
      // {A:30,B:10}: (30·2·10 + 10·2·2)/(30·2 + 10·2) = 640/80 = 8
      expect(
        WalkForwardValidator.scoreWeightedExcess(
          {'A': 30, 'B': 10},
          testStats,
          WfHorizon.short,
        ),
        closeTo(8.0, 1e-9),
      );
      // 反向 {A:10,B:30}: 偏重低報酬 rule → 較低 = 4
      expect(
        WalkForwardValidator.scoreWeightedExcess(
          {'A': 10, 'B': 30},
          testStats,
          WfHorizon.short,
        ),
        closeTo(4.0, 1e-9),
      );
    });

    test('score=0（被 cut）與不在校準的 rule 都不計', () {
      // {A:30,B:0} → 只剩 A → 10
      expect(
        WalkForwardValidator.scoreWeightedExcess(
          {'A': 30, 'B': 0},
          testStats,
          WfHorizon.short,
        ),
        closeTo(10.0, 1e-9),
      );
      // 空校準 → 0
      expect(
        WalkForwardValidator.scoreWeightedExcess(
          const {},
          testStats,
          WfHorizon.short,
        ),
        0.0,
      );
    });
  });

  group('evaluateGate（多準則）', () {
    test('PASS：多數折 NEW 不輸且有勝 + 平均勝幅 > 折間噪音', () {
      final folds = [
        for (final y in [2022, 2023, 2024, 2025, 2026])
          fold(y, shortMarginNewSwe: 5, shortOld: 3, longNew: 5, longOld: 3),
      ];
      final v = WalkForwardValidator.evaluateGate(folds);
      expect(v.passed, isTrue);
    });

    test('FAIL：NEW 沒贏（margin = 0）', () {
      final folds = [
        for (final y in [2022, 2023, 2024])
          fold(y, shortMarginNewSwe: 3, shortOld: 3, longNew: 3, longOld: 3),
      ];
      expect(WalkForwardValidator.evaluateGate(folds).passed, isFalse);
    });

    test('FAIL：單折暴衝、勝幅被噪音淹沒 + 不一致', () {
      final folds = [
        fold(2022, shortMarginNewSwe: 20, shortOld: 0, longNew: 20, longOld: 0),
        fold(2023, shortMarginNewSwe: -1, shortOld: 0, longNew: -1, longOld: 0),
        fold(2024, shortMarginNewSwe: -1, shortOld: 0, longNew: -1, longOld: 0),
      ];
      expect(WalkForwardValidator.evaluateGate(folds).passed, isFalse);
    });

    test('空 folds → FAIL（資料不足）', () {
      expect(WalkForwardValidator.evaluateGate(const []).passed, isFalse);
    });
  });
}
