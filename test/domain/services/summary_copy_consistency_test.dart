// 摘要文案三處不一致（2026-07-27 實機五張個股詳情卡）
//
// **一、同一個數字，兩種說法**
// TPK-KY 內文：「收盤價 62.7 元，**漲跌幅** -2.5%。」
// 緯穎/晟田/緯創/微星：「……收盤價 X 元，**當日** Y%。」
// 前者走 `summary.confluenceOverall`（有訊號匯流時取代整句開場白），後者走
// overallUp / overallDown。同一個欄位、同一個位置，兩個模板用不同稱呼。
//
// **二、五條訊號文案缺句號**
// 微星關鍵訊號並列：
//   「ROE 達 24.9%，股東權益報酬率優異**。**」
//   「強勢股健康回檔至月線附近（距 1.5%），回檔進場觀察點」← 無句號
// 全掃 summary 區塊，句子型文案中缺句號的有 5 條（中英文皆然）：
// pullbackToMa20 / pullbackToMa10 / hammerAtSupport / kdHighPullback /
// patternDojiBearish。其餘無句號者是標籤（明顯偏多）、區塊標題（關鍵訊號）、
// 按鈕（設定警示），本來就不該有。
//
// **三、匯流訊號在開場白與清單各出現一次（已查證，本檔不修——見文末）**
// TPK-KY：
//   內文     「……估值偏低但趨勢轉弱，需留意價值陷阱。」
//   風險提示 「估值偏低但趨勢轉弱，需留意價值陷阱。」
// `confluenceOverall` 的 {confluence} 參數用 `summaryKeys.first`（:225），
// 而 `_buildKeySignals`(:349) 與 `_buildRiskFactors`(:394) 又把整個
// summaryKeys 加進清單 —— 有匯流就必定重複，不是邊界案例。
//
// 先前那次跨區去重（1810 和成的本益比）只涵蓋 supporting 對
// keySignals + riskFactors，overallParts 根本不在那個關係裡。
//
// **但這條沒有在此修**：analysis_summary_service_test.dart:472 與 :499 兩個
// 既有測試明文要求匯流 key 出現在 keySignals（且排第一）與 riskFactors，
// 拿掉會同時打破兩者。那兩個測試出自 5109878（refactor: domain 層去
// localization），是為了鎖住搬遷保真度而寫，並未表態「開場白也該講一次」；
// 但要不要改動這個對外契約屬產品決策，留待決定。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';

import '../../helpers/analysis_data_generators.dart';

void main() {
  Map<String, dynamic> summaryCopy(String locale) =>
      (json.decode(File('assets/translations/$locale.json').readAsStringSync())
              as Map<String, dynamic>)['summary']
          as Map<String, dynamic>;

  group('同一個數字不得有兩種稱呼', () {
    for (final locale in ['zh-TW', 'en']) {
      test('🚨 $locale：confluenceOverall 與 overallUp/Down 的漲跌欄用詞須一致', () {
        final copy = summaryCopy(locale);
        // 取「{change} 前面那個詞」：以 {change} 切開，比較前綴的最後幾個字
        String labelBefore(String template) {
          final i = template.indexOf('{change}');
          expect(i, greaterThan(0), reason: '模板應含 {change}');
          return template.substring(0, i);
        }

        final upLabel = labelBefore(copy['overallUp'] as String);
        final confLabel = labelBefore(copy['confluenceOverall'] as String);

        // 兩者都以「稱呼 + 空白/標點」結尾，比對最後一個詞
        String lastToken(String s) =>
            s.trim().split(RegExp(r'[，,。.\s]')).last.trim();

        expect(
          lastToken(confLabel),
          lastToken(upLabel),
          reason:
              'TPK-KY 顯示「漲跌幅 -2.5%」、其餘四檔顯示「當日 X%」——'
              '同一個欄位在不同開場模板下換了稱呼，使用者會以為是不同的量',
        );
      });
    }
  });

  group('句子型文案須以句號結尾', () {
    /// 這五條是實測缺句號者；用具名清單而非「全部句子」，避免把標籤誤判為句子。
    const sentenceKeys = [
      'pullbackToMa20',
      'pullbackToMa10',
      'hammerAtSupport',
      'kdHighPullback',
      'patternDojiBearish',
      // 對照：本來就有句號的同類文案
      'roeExcellent',
      'peUndervalued',
    ];

    for (final locale in ['zh-TW', 'en']) {
      test('🚨 $locale：訊號條列的文案結尾標點須一致', () {
        final copy = summaryCopy(locale);
        final terminator = locale == 'zh-TW' ? '。' : '.';
        final missing = <String>[
          for (final key in sentenceKeys)
            if (copy.containsKey(key) &&
                !(copy[key] as String).trimRight().endsWith(terminator))
              '$key → ${copy[key]}',
        ];

        expect(
          missing,
          isEmpty,
          reason:
              '同一個條列裡有的有句號有的沒有（微星實機：ROE 那條有、回檔那條沒有）。'
              '清單含兩條本來就有句號的對照鍵，若它們也被判缺，代表判準本身錯了',
        );
      });
    }
  });
}
