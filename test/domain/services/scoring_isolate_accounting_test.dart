// 評分帳目完整性 — 每個候選股都必須有歸屬（輸出或某個 skip 分類）
//
// 2026-07-25 實測：日誌「候選 897 檔 → 評分 142 + 跳過 701」少了 54 檔，
// 根因是 scoring_isolate 兩個 continue 未計數（analysisResult == null、
// reasons.isEmpty）。前者更是靜默失敗——技術分析失敗的股票直接消失，
// 無 log 無計數，與同檔案「fail-loud 比 silent fallback 更安全」的既定
// 原則矛盾。此測試釘住「帳目必須平」的不變量。
import 'package:afterclose/domain/services/scoring_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoringBatchResult 帳目不變量', () {
    test('skippedTotal 涵蓋全部 skip 分類（含 NoAnalysis / NoReasons）', () {
      const result = ScoringBatchResult(
        outputs: [],
        candidateCount: 21,
        skippedNoData: 1,
        skippedInsufficientData: 2,
        skippedLowLiquidity: 3,
        skippedNoAnalysis: 4,
        skippedNoReasons: 5,
        skippedLowScore: 6,
      );

      expect(result.skippedTotal, 21);
      expect(result.accountingBalances, isTrue);
    });

    test('帳目不平時 accountingBalances 為 false（可據此告警）', () {
      const result = ScoringBatchResult(
        outputs: [],
        candidateCount: 100,
        skippedNoData: 1,
        skippedInsufficientData: 0,
        skippedLowLiquidity: 0,
        skippedNoAnalysis: 0,
        skippedNoReasons: 0,
        skippedLowScore: 0,
      );

      expect(result.accountingBalances, isFalse);
    });

    test('新欄位可跨 Isolate 邊界序列化', () {
      const original = ScoringBatchResult(
        outputs: [],
        candidateCount: 9,
        skippedNoData: 1,
        skippedInsufficientData: 1,
        skippedLowLiquidity: 1,
        skippedNoAnalysis: 3,
        skippedNoReasons: 2,
        skippedLowScore: 1,
      );

      final restored = ScoringBatchResult.fromMap(original.toMap());

      expect(restored.candidateCount, 9);
      expect(restored.skippedNoAnalysis, 3);
      expect(restored.skippedNoReasons, 2);
      expect(restored.accountingBalances, isTrue);
    });

    test('fromMap 對缺欄位的舊 map 容錯（預設 0，不 throw）', () {
      final legacy = <String, dynamic>{
        'outputs': <dynamic>[],
        'skippedNoData': 2,
        'skippedInsufficientData': 0,
        'skippedLowLiquidity': 0,
        'skippedLowScore': 0,
        // 無 candidateCount / skippedNoAnalysis / skippedNoReasons
      };

      final restored = ScoringBatchResult.fromMap(legacy);

      expect(restored.skippedNoAnalysis, 0);
      expect(restored.skippedNoReasons, 0);
      expect(restored.candidateCount, 0);
    });
  });

  group('evaluateStocksInIsolate 實跑帳目', () {
    test('資格不符的候選全部有歸屬，帳目平', () async {
      // 兩檔都無價格資料 → classifyCandidate 判 noData，不進技術分析
      const input = ScoringIsolateInput(
        candidates: ['9991', '9992'],
        pricesMap: {'9991': [], '9992': []},
        newsMap: {'9991': [], '9992': []},
        institutionalMap: {'9991': [], '9992': []},
      );

      final result = await evaluateStocksInIsolate(input);

      expect(result.candidateCount, 2);
      expect(result.outputs, isEmpty);
      expect(
        result.accountingBalances,
        isTrue,
        reason: '每個候選股都必須落在某個 skip 分類，不得無聲消失',
      );
    });
  });
}
