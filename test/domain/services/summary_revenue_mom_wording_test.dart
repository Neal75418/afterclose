// 營收月增摘要不得說「連續 1 個月」
//
// 實機（2026-07-26，6416 融程電）：關鍵訊號寫「營收連續 1 個月月增成長，
// 成長動能持續。」——一個月構不成「連續」。
//
// 這不是新問題，是**規則層早就解過、摘要層沒沿用**：
// fundamental_scan_rules 產生 description 時就特判過單月
//   consecutiveMonths == 1 ? '本月營收月增 X% (站上月線)'
//                          : '營收月增連續 N 個月 (站上月線)'
// 而摘要層只有 summary.revenueMomGrowth 一個 key，`{months}` 直接代入。
//
// 更麻煩的是 revenueMomConsecutiveMonths = 1，而規則的計數迴圈上界就是
// 這個常數 → consecutiveMonths **恆等於 1**。也就是說 `{months}` 是永遠
// 印 1 的死參數，那句話在正式環境每次都讀起來很怪。常數若日後調大，
// 複數那句才會第一次被用到，所以兩條路徑都要顧。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';

import '../../helpers/analysis_data_generators.dart';

void main() {
  const service = AnalysisSummaryService();

  LocalizableString revenueLineFor(String evidenceJson) {
    final result = service.generate(
      analysis: createTestAnalysis(trendState: 'UP', score: 40),
      reasons: [
        createTestReason(
          reasonType: 'REVENUE_MOM_GROWTH',
          ruleScore: 12,
          evidenceJson: evidenceJson,
        ),
      ],
      latestPrice: null,
      priceChange: null,
      institutionalHistory: [],
      revenueHistory: [],
      latestPER: null,
      horizon: Horizon.short,
    );

    final all = [
      ...result.keySignals,
      ...result.riskFactors,
      ...result.supportingData,
    ];
    return all.singleWhere(
      (ls) => ls.key.startsWith('summary.revenueMomGrowth'),
      orElse: () => throw StateError('找不到營收月增那一行：${all.map((e) => e.key)}'),
    );
  }

  test('🚨 單月（正式環境唯一可能值）不得走「連續 N 個月」句型', () {
    final line = revenueLineFor('{"consecutiveMonths":1,"avgMomGrowth":12.3}');

    expect(
      line.key,
      'summary.revenueMomGrowthSingle',
      reason: '規則層自己的 description 就特判過單月，摘要層須沿用同一個判斷',
    );
    expect(line.namedArgs['growth'], '12.3', reason: '單月講的是這個月增幅，不是月數');
  });

  test('多月時維持「連續 N 個月」句型', () {
    final line = revenueLineFor('{"consecutiveMonths":3,"avgMomGrowth":8.0}');

    expect(line.key, 'summary.revenueMomGrowth');
    expect(line.namedArgs['months'], '3');
  });

  test('文案本身：單月句不得含「連續」，複數句必須含', () {
    // 走 i18n 檔實字，避免「key 換了但文案照舊」的假綠
    final zh =
        (json.decode(File('assets/translations/zh-TW.json').readAsStringSync())
                as Map<String, dynamic>)['summary']
            as Map<String, dynamic>;

    // 先斷言 key 存在：缺 key 時值為 null，isNot(contains(...)) 會假綠
    expect(zh.keys, contains('revenueMomGrowthSingle'));
    expect(
      zh['revenueMomGrowthSingle'],
      isNot(contains('連續')),
      reason: '換了 key 卻沿用同一句話等於沒修',
    );
    expect(zh['revenueMomGrowth'], contains('連續'));
  });
}
