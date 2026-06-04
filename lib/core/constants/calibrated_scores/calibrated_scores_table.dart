import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_scores.dart';

/// `parseJson` 的回傳結構：table + 解析過程中產生的 warning 列表
///
/// 採用 record 讓 parser 保持純函式（無 side effect），呼叫端再決定
/// warning 如何 log 或 assert（測試用途）。
typedef CalibratedScoresParseResult = ({
  CalibratedScoresTable table,
  List<String> warnings,
});

/// 單一 horizon 的 calibrated rule scores 查找表
///
/// 不可變資料結構。由 `parseJson` 從 JSON 產生或由 `empty()` 建立
/// safe fallback 表（用於解析失敗情境）。
///
/// ## 查詢語意
///
/// - [lookup] 回傳 `int?`：存在即為 calibrated value，null 表示該規則未
///   被 calibrated，呼叫端應 fallback 至 `RuleScores` hardcoded 值。
/// - 未載入的規則與不存在的規則行為一致（皆回 null），不需額外區分。
///
/// ## 與 Stage 5b 的關係
///
/// Stage 5a 只在主 isolate 使用此 table。Stage 5b 會透過
/// `ScoringIsolateInput` 把 table 的 raw map 傳入 scoring isolate，
/// 屆時 isolate 端會用 `CalibratedScoresTable` 的 constructor 直接重建
/// 而非重新 parseJson。
@immutable
class CalibratedScoresTable {
  const CalibratedScoresTable({
    required this.horizon,
    required this.schemaVersion,
    required this.generatedAt,
    required Map<String, int> scores,
  }) : _scores = scores;

  /// 此 table 對應的 horizon
  final Horizon horizon;

  /// JSON schema 版本（目前僅支援 1）
  final int schemaVersion;

  /// `generated_at` 欄位解析結果，缺失或格式錯誤時為 null
  final DateTime? generatedAt;

  /// rule_id → calibrated score 的不可變查找表
  final Map<String, int> _scores;

  /// 查詢單一規則的 calibrated score
  ///
  /// 若 [ruleId] 不在 table 中，回傳 null。呼叫端應 fallback 到
  /// `RuleScores` hardcoded 值。
  int? lookup(String ruleId) => _scores[ruleId];

  /// 已載入的規則數量，供診斷與 smoke test 使用
  int get ruleCount => _scores.length;

  /// 取得 `_scores` 的 unmodifiable view
  ///
  /// 用於 Stage 5b 的 [CalibratedScoresRegistry.snapshotForIsolate]：
  /// 打包 DTO 時需要讀取完整 map 內容而不暴露寫入能力。回傳的 map
  /// 可以安全跨 isolate 傳輸（Dart 會深拷貝 primitive map）。
  Map<String, int> scoresSnapshot() => Map.unmodifiable(_scores);

  /// 空 table — 作為 malformed JSON / asset 缺失時的 safe fallback
  ///
  /// 所有 [lookup] 查詢都會回 null，呼叫端自然走 fallback 路徑。
  factory CalibratedScoresTable.empty(Horizon horizon) => CalibratedScoresTable(
    horizon: horizon,
    schemaVersion: 0,
    generatedAt: null,
    scores: const {},
  );

  /// 從 JSON 字串解析 calibrated scores table
  ///
  /// ## Error policy（Q4 方案 III：結構嚴格 + 內容寬鬆）
  ///
  /// **結構錯誤** — parser 回傳 `empty(horizon)` + warnings：
  /// - Malformed JSON
  /// - Root 不是 Map
  /// - `schema_version` 缺失、非 int、或 != 1
  /// - `rules` 欄位缺失或非 Map
  ///
  /// **內容錯誤** — parser skip 該條 + warning，其他條照常處理：
  /// - 單條 rule 不是 object
  /// - `score` 欄位缺失或非數值
  /// - [knownRuleIds] 不為 null 且 rule_id 不在 whitelist 中
  ///
  /// **Clamp** — `score > RuleScores.maxScore` 或 `< RuleScores.minScore`
  /// 會被 clamp 到邊界並產生 warning。正常 calibrated JSON 不應觸發此路徑
  /// （`tool/recalibrate.dart` 已限制在 [10, 35] 範圍），此為 defensive
  /// safety net。
  ///
  /// ## [knownRuleIds] 的用途
  ///
  /// 若提供，parser 會檢查每條 rule_id 是否在 `ReasonType.values` 中存在。
  /// 不存在則 skip + warn（scenario 7）。若傳 null 則 skip 此檢查，全部
  /// rule_id 照單全收。分離此參數是為避免 `calibrated_scores/` 反向依賴
  /// `ReasonType`，維持乾淨的依賴 DAG — caller（registry 或 main.dart）
  /// 負責從外部注入 whitelist。
  ///
  /// ## [hardcodedScores] 的用途（Scenario 8：sign-flip 警示）
  ///
  /// 若提供 rule_id → hardcoded score 的對照表，parser 會對每條 calibrated
  /// 分數做 sign-flip 檢查：當 hardcoded 非零且與 calibrated 異號（空方規則
  /// 被算出正分、或多方規則被算出負分），加 warning。這個情境**不是 bug**
  /// — calibration 允許 backtest 翻轉 rule 的 design semantic — 但會造成
  /// UX 矛盾（reason chip 顯示「跌破支撐」卻對 Top 20 推薦分數有正貢獻），
  /// 值得在 calibration candidate review 時被看見。
  ///
  /// Parser 不修改分數，只產生 warning。依賴 DAG 的拆解方式與
  /// [knownRuleIds] 一致：caller 從 `ReasonType` 構造 map 傳入。
  static CalibratedScoresParseResult parseJson(
    String jsonStr, {
    required Horizon horizon,
    Set<String>? knownRuleIds,
    Map<String, int>? hardcodedScores,
  }) {
    final warnings = <String>[];

    Object? root;
    try {
      root = jsonDecode(jsonStr);
    } on FormatException catch (e) {
      warnings.add('malformed JSON: ${e.message}');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }

    if (root is! Map) {
      warnings.add('root must be object, got ${root.runtimeType}');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }

    final schemaVersion = root['schema_version'];
    if (schemaVersion is! int) {
      warnings.add('schema_version missing or invalid');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }
    if (schemaVersion != 1) {
      warnings.add('unsupported schema_version: $schemaVersion');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }

    // Calibration drift guard：拒絕載入 metadata 與 runtime canonical 不一致的 JSON
    //
    // 動機：`success_threshold_pct` 是「returnRate 算不算命中」的定義；
    // 一旦 [CalibrationThresholds.successThresholds] 在 repo 更新但 JSON 沒
    // 同步重產，所有 hit_rate / t_stat / active 就建立在錯誤門檻上，
    // 對外稱「校準分數」實際失效。
    //
    // 防呆：parser 比對 JSON metadata 與 [Horizon.successThresholdPct]，差距
    // 超過 0.01 即拒載並 return empty table（呼叫端會走 fallback chain 退到
    // hardcoded `RuleScores`，與 calibration miss 同路徑）。
    //
    // 修：執行 `dart run tool/recalibrate.dart --horizon both` 重產 JSON，
    // 確認 metadata 後 promote `_candidate.json` 取代 production 檔。
    // backtest.success_threshold_pct 存在且不匹配時拒載；缺失 / 非 Map 都
    // 寬鬆通過（測試 fixture 與早期版本不含此 block，無需強制）。如果
    // production JSON 含 block 但缺 success_threshold_pct 屬於 producer
    // 異常但不阻擋 — 後續 CI guard 可額外加 schema 嚴格度。
    final backtest = root['backtest'];
    if (backtest is Map) {
      final declared = backtest['success_threshold_pct'];
      if (declared is num) {
        final canonical = horizon.successThresholdPct;
        if ((declared.toDouble() - canonical).abs() > 0.01) {
          warnings.add(
            'success_threshold_pct drift: JSON metadata $declared vs '
            'runtime canonical $canonical (Horizon.${horizon.name}). '
            'Refusing to load — rerun tool/recalibrate.dart and promote.',
          );
          return (
            table: CalibratedScoresTable.empty(horizon),
            warnings: warnings,
          );
        }
      }
    }

    final rulesRaw = root['rules'];
    if (rulesRaw == null) {
      warnings.add('rules field missing');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }
    if (rulesRaw is! Map) {
      warnings.add('rules must be object, got ${rulesRaw.runtimeType}');
      return (table: CalibratedScoresTable.empty(horizon), warnings: warnings);
    }

    // generated_at 是選填 metadata，解析失敗不影響 table 本體
    DateTime? generatedAt;
    final generatedAtRaw = root['generated_at'];
    if (generatedAtRaw is String) {
      generatedAt = DateTime.tryParse(generatedAtRaw);
    }

    final scores = <String, int>{};
    for (final entry in rulesRaw.entries) {
      final ruleId = entry.key.toString();
      final ruleValue = entry.value;

      // Scenario 5a: entry 不是 object
      if (ruleValue is! Map) {
        warnings.add('rule $ruleId: entry not object');
        continue;
      }

      // Scenario 5b: score 欄位缺失
      final scoreRaw = ruleValue['score'];
      if (scoreRaw == null) {
        warnings.add('rule $ruleId: score field missing');
        continue;
      }

      // Scenario 5c: score 不是數值
      if (scoreRaw is! num) {
        warnings.add('rule $ruleId: score not numeric');
        continue;
      }

      // Scenario 7: unknown ReasonType code（whitelist 檢查）
      if (knownRuleIds != null && !knownRuleIds.contains(ruleId)) {
        warnings.add(
          'rule $ruleId: unknown ReasonType code, ignored (possibly removed or typo)',
        );
        continue;
      }

      // Scenario 5d: 非整數 score 會被 round 到最近整數並發出 warning
      //
      // `tool/recalibrate.dart` 目前使用 `.round()` 輸出整數，但手動編輯
      // 或 drift 的 producer 可能產生 fractional score。使用 `.round()`
      // 而非 `.toInt()` 避免 `.toInt()` 對負數的非對稱截斷（例如 -22.7 →
      // -22 而非 -23）。`22.0`（整數表示的 double）不會觸發 warning，因為
      // `22.0.round() == 22` 且 `22 == 22.0` 在 Dart 中為 true。
      final rounded = scoreRaw.round();
      if (rounded != scoreRaw) {
        warnings.add(
          'rule $ruleId: non-integer score $scoreRaw rounded to $rounded',
        );
      }

      // Scenarios 6a/6b: clamp 到 [minScore, maxScore]
      var score = rounded;
      if (score > RuleScores.maxScore) {
        warnings.add(
          'rule $ruleId: score $score clamped to ${RuleScores.maxScore}',
        );
        score = RuleScores.maxScore;
      } else if (score < RuleScores.minScore) {
        warnings.add(
          'rule $ruleId: score $score clamped to ${RuleScores.minScore}',
        );
        score = RuleScores.minScore;
      }

      // Scenario 8: sign flip vs hardcoded design intent — clamp to 0
      //
      // 例：TECH_BREAKDOWN（跌破支撐）hardcoded -20，calibrated +22。Backtest
      // 統計上 hit_rate 0.547 / t-stat 4.07 是合法 pipeline 輸出，但 UX 上
      // 使用者看到 Top 20 推薦顯示 reason chip「跌破支撐」對分數有正貢獻
      // 會直接質疑 App 的可信度。
      //
      // Pre-launch decision: 翻轉符號的 rule 一律 clamp 到 0（等同 cut，
      // 不貢獻分數），但保留 metadata 在 table 中供 review。等 Stage 4 累積
      // 真實 forward data（不只是 backtest）驗證 sign-flip pattern 仍穩定後
      // 再考慮解鎖。對稱處理 bearish→positive 與 bullish→negative：兩個方向
      // 都代表 calibration 與 design semantics 不一致，採同一個保守 fallback。
      if (hardcodedScores != null) {
        final hardcoded = hardcodedScores[ruleId];
        if (hardcoded != null && hardcoded != 0 && score != 0) {
          final hardcodedPositive = hardcoded > 0;
          final calibratedPositive = score > 0;
          if (hardcodedPositive != calibratedPositive) {
            warnings.add(
              'rule $ruleId: sign flip — hardcoded $hardcoded vs calibrated '
              '$score, clamped to 0 (rule treated as cut for safety)',
            );
            score = 0;
          }
        }
      }

      scores[ruleId] = score;
    }

    return (
      table: CalibratedScoresTable(
        horizon: horizon,
        schemaVersion: schemaVersion,
        generatedAt: generatedAt,
        scores: scores,
      ),
      warnings: warnings,
    );
  }
}
