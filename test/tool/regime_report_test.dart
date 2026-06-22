// tool/regime_report.dart 單元測試 — 驗 computeCell 純邏輯。
// 完整 run() 走真實 DB + RuleEngine（端對端以實資料跑）。
import 'package:flutter_test/flutter_test.dart';

import '../../tool/regime_report.dart';
import '../../tool/replay_calibrator.dart' show RuleHorizonStats;

void main() {
  group('computeCell', () {
    test('期望值 = 平均報酬；勝率/賺/賠由 returns 拆；相對來自 excess', () {
      final abs = RuleHorizonStats();
      for (final r in [10.0, -4.0, 6.0, -2.0]) {
        abs.addSample(r, 0);
      }
      final exc = RuleHorizonStats();
      for (final r in [1.5, 0.5]) {
        exc.addSample(r, 0);
      }

      final cell = computeCell(abs, exc);
      expect(cell.n, 4);
      expect(cell.expectancy, closeTo(2.5, 1e-9), reason: '(10-4+6-2)/4');
      expect(cell.winRate, closeTo(0.5, 1e-9), reason: '2 正 / 4');
      expect(cell.avgWin, closeTo(8.0, 1e-9), reason: '(10+6)/2');
      expect(cell.avgLoss, closeTo(-3.0, 1e-9), reason: '(-4-2)/2');
      expect(
        cell.relative,
        closeTo(1.0, 1e-9),
        reason: 'excess 平均 (1.5+0.5)/2',
      );
    });

    test('空 stats → 全 0（不爆）', () {
      final cell = computeCell(RuleHorizonStats(), RuleHorizonStats());
      expect(cell.n, 0);
      expect(cell.expectancy, 0.0);
      expect(cell.winRate, 0.0);
      expect(cell.avgWin, 0.0);
      expect(cell.avgLoss, 0.0);
      expect(cell.relative, 0.0);
    });

    test('全賺 → 勝率 1、avgLoss 0', () {
      final abs = RuleHorizonStats();
      for (final r in [3.0, 5.0]) {
        abs.addSample(r, 0);
      }
      final cell = computeCell(abs, RuleHorizonStats());
      expect(cell.winRate, 1.0);
      expect(cell.avgLoss, 0.0);
      expect(cell.avgWin, closeTo(4.0, 1e-9));
    });
  });
}
