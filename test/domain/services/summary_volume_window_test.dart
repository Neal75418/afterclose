// 量能文案跨窗矛盾(2026-08-01 實機,4903 聯一光 7/31)
//
// 同一張卡:關鍵訊號「單日漲幅達 9.9%,量增顯著」+風險提示「出現價漲
// 量縮警示,漲勢可能無力」——量增與量縮同時宣稱,直接對立。
//
// 機理是**跨窗矛盾**(與 7/26 修的連買天數跨窗矛盾同族,當時掃了
// streak、漏了量能這一對):
//   priceSpike   → 今日量 ≥ 20 日均量 × 1.5(RuleParams.volMa)
//   weakRally    → 今日量 ≤ 5 日均量 × 0.9(priceVolumeLookbackDays)
// 連環爆量日把 5 日均量墊高後兩者可同時成立——各自都對,但無窗文案
// 讓用戶讀到同一件事的兩個相反結論。
//
// 修法:比照 volumeSpike 既有先例(「成交量達近 20 日均量的 {multiple}
// 倍」),量能宣稱一律帶上比較窗——兩句可誠實並存,不互相打架。
// bearishDivergence(價跌量增,同一個 5 日窗)一併帶窗:它在當日上漲
// 的股票上觸發時(2026-08-01 實機,2395 研華 +2.9%),無窗文案讀起來
// 像在說今天。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/constants/rule_params.dart';

import 'package:daredevil/core/constants/calibrated_scores/horizon.dart';
import 'package:daredevil/domain/services/analysis_summary_service.dart';

import '../../helpers/analysis_data_generators.dart';

void main() {
  Map<String, dynamic> summaryCopy(String locale) =>
      (json.decode(File('assets/translations/$locale.json').readAsStringSync())
              as Map<String, dynamic>)['summary']
          as Map<String, dynamic>;

  group('量能宣稱必須帶比較窗(兩語系)', () {
    for (final locale in ['zh-TW', 'en']) {
      test(
        '🚨 $locale:priceSpike 帶 20 日窗、weakRally/bearishDivergence 帶 5 日窗',
        () {
          final copy = summaryCopy(locale);
          // 錨定參數常數(2026-08-05 複審):文案數字若寫死,volMa 或
          // lookback 一改就無聲漂移;斷言直接引用實作同源常數。
          expect(
            copy['priceSpike'] as String,
            contains('${RuleParams.volMa}'),
            reason:
                'priceSpike 的量能宣稱(vs ${RuleParams.volMa} 日均量)須標窗,'
                '否則與 weakRally 同卡對立',
          );
          expect(
            copy['priceVolumeWeakRally'] as String,
            contains('${TrendParams.priceVolumeLookbackDays}'),
          );
          expect(
            copy['bearishDivergence'] as String,
            contains('${TrendParams.priceVolumeLookbackDays}'),
          );
          // 價格宣稱也要帶窗(複審 Medium #8):weakRally 的價格條件量的
          // 是 5 日前收盤 vs 今收,無窗文案在紅 K 日讀起來像在說今天
          final zhPricePattern = RegExp(
            r'近\s*'
            '${TrendParams.priceVolumeLookbackDays}'
            r'\s*日',
          );
          if (locale == 'zh-TW') {
            expect(
              zhPricePattern.hasMatch(copy['priceVolumeWeakRally'] as String),
              isTrue,
              reason: 'weakRally 價格宣稱須標 5 日窗',
            );
          } else {
            expect(
              (copy['priceVolumeWeakRally'] as String).contains('5 days') ||
                  (copy['priceVolumeWeakRally'] as String).contains('5-day'),
              isTrue,
            );
          }
        },
      );
    }
  });

  group('generate():雙訊號同日觸發時兩句各帶自己的量能數字', () {
    const service = AnalysisSummaryService();

    test('priceSpike 帶量倍數、weakRally 帶萎縮百分比', () {
      final data = service.generate(
        analysis: null,
        reasons: [
          createTestReason(
            reasonType: 'PRICE_SPIKE',
            ruleScore: 15,
            evidenceJson: json.encode({
              'pctChange': 9.9,
              'volumeMultiple': 1.8,
            }),
          ),
          createTestReason(
            reasonType: 'PRICE_VOLUME_BULLISH_DIVERGENCE', // weakRally DB code
            ruleScore: -5,
            evidenceJson: json.encode({
              'priceChange': 9.9,
              'volumeChange': -23.4,
            }),
          ),
        ],
        latestPrice: null,
        priceChange: 9.9,
        institutionalHistory: const [],
        revenueHistory: const [],
        latestPER: null,
        horizon: Horizon.short,
      );

      final spike = data.keySignals.firstWhere(
        (s) => s.key == 'summary.priceSpike',
      );
      expect(
        spike.namedArgs['volMult'],
        '1.8',
        reason: '量能宣稱須帶實際倍數,不得裸稱「量增顯著」',
      );

      final weak = data.riskFactors.firstWhere(
        (s) => s.key == 'summary.priceVolumeWeakRally',
      );
      expect(
        weak.namedArgs['volShrink'],
        '23',
        reason: '量縮宣稱須帶實際萎縮%(取絕對值,方向由用詞承載)',
      );
    });
  });
}
