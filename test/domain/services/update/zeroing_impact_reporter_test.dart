// 負證據歸零的觀測性報告(2026-07-29 三態 lookup 配套)
//
// 「交付前先問:如果它沒生效,我怎麼知道?」——歸零上線後每日更新要
// log 三個數:歸零列數/涉及檔數/因歸零跌出訊號層的檔數。本檔測純計算
// 函式:給定當日 daily_reason rows + 歸零集 + hardcoded 對照,重算
// 「若無歸零」的 mode 分數,數出跌出訊號層(任一 mode 任一 horizon
// ≥ minScoreThreshold)的股票。
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/domain/services/update/zeroing_impact_reporter.dart';

DailyReasonEntry row(
  String symbol,
  String type, {
  double short = 0,
  double long = 0,
  int rank = 1,
}) => DailyReasonEntry(
  symbol: symbol,
  date: DateTime(2026, 7, 29),
  rank: rank,
  reasonType: type,
  evidenceJson: '{}',
  ruleScoreShort: short,
  ruleScoreLong: long,
);

void main() {
  // KD_GOLDEN_CROSS 屬 Mode A;hardcoded 15(測試值)
  const zeroed = {'KD_GOLDEN_CROSS'};
  const hardcoded = {'KD_GOLDEN_CROSS': 15, 'PBR_UNDERVALUED': 12};

  group('computeZeroingImpact', () {
    test('被歸零而跌出訊號層的股票被數到', () {
      // 2330:KD(歸零後 0)+ PBR 12 → 實際 A=12…仍達標?
      // 設計案例:只有 KD 一條 → 實際 0 <12、would-be 15 ≥12 → dropped
      final rows = [row('2330', 'KD_GOLDEN_CROSS', short: 0, rank: 1)];
      final impact = computeZeroingImpact(
        rows: rows,
        zeroedRules: zeroed,
        hardcodedScores: hardcoded,
      );
      expect(impact.zeroedRows, 1);
      expect(impact.zeroedStocks, 1);
      expect(impact.droppedStocks, 1);
      expect(impact.addedStocks, 0, reason: '方向 gate 下歸零不可能使股票新進訊號層');
    });

    test('歸零後仍達標的股票不算 dropped', () {
      // 2317:KD(0)+ PBR 12 → 實際 A=12 已達門檻 → 不算跌出
      final rows = [
        row('2317', 'KD_GOLDEN_CROSS', short: 0, rank: 1),
        row('2317', 'PBR_UNDERVALUED', short: 12, rank: 2),
      ];
      final impact = computeZeroingImpact(
        rows: rows,
        zeroedRules: zeroed,
        hardcodedScores: hardcoded,
      );
      expect(impact.zeroedRows, 1);
      expect(impact.zeroedStocks, 1);
      expect(impact.droppedStocks, 0);
    });

    test('long horizon 撐住 tier 的股票不算 dropped(歸零僅動 short)', () {
      final rows = [
        row('2603', 'KD_GOLDEN_CROSS', short: 0, long: 18, rank: 1),
      ];
      final impact = computeZeroingImpact(
        rows: rows,
        zeroedRules: zeroed,
        hardcodedScores: hardcoded,
      );
      expect(impact.droppedStocks, 0, reason: 'long=18 ≥12 兩版皆過 tier');
    });

    test('非歸零集的 0 分列不計入(例如其他 cut 的 fallback 前狀態)', () {
      final rows = [row('1101', 'PBR_UNDERVALUED', short: 12, rank: 1)];
      final impact = computeZeroingImpact(
        rows: rows,
        zeroedRules: zeroed,
        hardcodedScores: hardcoded,
      );
      expect(impact.zeroedRows, 0);
      expect(impact.zeroedStocks, 0);
      expect(impact.droppedStocks, 0);
    });

    test('空輸入回全零', () {
      final impact = computeZeroingImpact(
        rows: const [],
        zeroedRules: zeroed,
        hardcodedScores: hardcoded,
      );
      expect(impact.zeroedRows, 0);
      expect(impact.droppedStocks, 0);
    });
  });
}
