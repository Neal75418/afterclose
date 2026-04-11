// Stage 5b Commit 3 — dual-horizon isolate DTO tests
//
// 驗證 [ScoringIsolateInput] / [ScoringIsolateOutput] / [IsolateReasonOutput]
// 在新增 dual-horizon 欄位後的序列化正確性。
import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/domain/services/scoring_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoringIsolateInput.calibratedScores serialization', () {
    test('round-trip CalibratedScoreContext through toMap/fromMap', () {
      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 30, 'VOLUME_SPIKE': 22},
        longScores: {'TECH_BREAKOUT': 15},
      );

      const input = ScoringIsolateInput(
        candidates: ['2330'],
        pricesMap: {'2330': []},
        newsMap: {'2330': []},
        institutionalMap: {'2330': []},
        calibratedScores: ctx,
      );

      final map = input.toMap();
      final restored = ScoringIsolateInput.fromMap(map);

      expect(restored.calibratedScores.shortScores, {
        'TECH_BREAKOUT': 30,
        'VOLUME_SPIKE': 22,
      });
      expect(restored.calibratedScores.longScores, {'TECH_BREAKOUT': 15});
    });

    test('default calibratedScores is empty context', () {
      const input = ScoringIsolateInput(
        candidates: ['2330'],
        pricesMap: {'2330': []},
        newsMap: {'2330': []},
        institutionalMap: {'2330': []},
      );

      // Default 值是 empty — lookup 永遠回 null
      expect(input.calibratedScores.shortScores, isEmpty);
      expect(input.calibratedScores.longScores, isEmpty);
    });

    test('fromMap tolerates missing calibratedScores key', () {
      // 模擬舊版 map（Commit 2 之前）缺此欄位的情境
      final map = <String, dynamic>{
        'candidates': ['2330'],
        'pricesMap': <String, List>{'2330': []},
        'newsMap': <String, List>{'2330': []},
        'institutionalMap': <String, List>{'2330': []},
        // 沒有 calibratedScores
      };

      final restored = ScoringIsolateInput.fromMap(map);

      expect(restored.calibratedScores.shortScores, isEmpty);
      expect(restored.calibratedScores.longScores, isEmpty);
    });

    test('lookup via restored context returns same value', () {
      const ctx = CalibratedScoreContext(
        shortScores: {'TECH_BREAKOUT': 30},
        longScores: {'TECH_BREAKOUT': 10},
      );

      const input = ScoringIsolateInput(
        candidates: ['2330'],
        pricesMap: {'2330': []},
        newsMap: {'2330': []},
        institutionalMap: {'2330': []},
        calibratedScores: ctx,
      );

      final restored = ScoringIsolateInput.fromMap(input.toMap());

      expect(
        restored.calibratedScores.lookup(Horizon.short, 'TECH_BREAKOUT'),
        30,
      );
      expect(
        restored.calibratedScores.lookup(Horizon.long, 'TECH_BREAKOUT'),
        10,
      );
      expect(restored.calibratedScores.lookup(Horizon.short, 'UNKNOWN'), null);
    });
  });

  group('ScoringIsolateOutput dual-horizon fields', () {
    test('round-trip scoreShort + scoreLong', () {
      const output = ScoringIsolateOutput(
        symbol: '2330',
        scoreShort: 75,
        scoreLong: 45,
        turnover: 5000000000,
        trendState: 'UP',
        reversalState: 'NONE',
        reasons: [],
      );

      final restored = ScoringIsolateOutput.fromMap(output.toMap());

      expect(restored.symbol, '2330');
      expect(restored.scoreShort, 75);
      expect(restored.scoreLong, 45);
      expect(restored.turnover, 5000000000);
      expect(restored.trendState, 'UP');
    });

    test('different horizons can produce different scores', () {
      const output = ScoringIsolateOutput(
        symbol: '2330',
        scoreShort: 80,
        scoreLong: 20, // 短線很強但長線弱
        turnover: 1000000000,
        trendState: 'UP',
        reversalState: 'NONE',
        reasons: [],
      );

      final map = output.toMap();
      final restored = ScoringIsolateOutput.fromMap(map);

      expect(restored.scoreShort, isNot(equals(restored.scoreLong)));
      expect(restored.scoreShort, 80);
      expect(restored.scoreLong, 20);
    });
  });

  group('IsolateReasonOutput dual-horizon fields', () {
    test('round-trip scoreShort + scoreLong + evidence', () {
      const reason = IsolateReasonOutput(
        type: 'TECH_BREAKOUT',
        scoreShort: 30,
        scoreLong: 12,
        description: 'reasons.breakout',
        evidenceJson: '{"ma20":100}',
      );

      final map = reason.toMap();
      final restored = IsolateReasonOutput.fromMap(map);

      expect(restored.type, 'TECH_BREAKOUT');
      expect(restored.scoreShort, 30);
      expect(restored.scoreLong, 12);
      expect(restored.description, 'reasons.breakout');
      expect(restored.evidenceJson, '{"ma20":100}');
    });

    test('nested in ScoringIsolateOutput round-trips correctly', () {
      const output = ScoringIsolateOutput(
        symbol: '2330',
        scoreShort: 42,
        scoreLong: 18,
        turnover: 5e9,
        trendState: 'UP',
        reversalState: 'NONE',
        reasons: [
          IsolateReasonOutput(
            type: 'TECH_BREAKOUT',
            scoreShort: 30,
            scoreLong: 10,
            description: 'x',
            evidenceJson: '{}',
          ),
          IsolateReasonOutput(
            type: 'VOLUME_SPIKE',
            scoreShort: 12,
            scoreLong: 8,
            description: 'y',
            evidenceJson: '{}',
          ),
        ],
      );

      final restored = ScoringIsolateOutput.fromMap(output.toMap());

      expect(restored.reasons.length, 2);
      expect(restored.reasons[0].type, 'TECH_BREAKOUT');
      expect(restored.reasons[0].scoreShort, 30);
      expect(restored.reasons[0].scoreLong, 10);
      expect(restored.reasons[1].scoreShort, 12);
      expect(restored.reasons[1].scoreLong, 8);
    });
  });
}
