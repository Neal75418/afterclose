import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/calibration_thresholds.dart';
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
/// ## Isolate 邊界
///
/// `ScoringIsolateInput` 把 table 的 raw map 傳入 scoring isolate，
/// isolate 端用 `CalibratedScoresTable` 的 constructor 直接重建
/// 而非重新 parseJson。
@immutable
class CalibratedScoresTable {
  const CalibratedScoresTable({
    required this.horizon,
    required this.schemaVersion,
    required this.generatedAt,
    required Map<String, int> scores,
    Set<String> zeroedRules = const {},
  }) : _scores = scores,
       _zeroedRules = zeroedRules;

  /// 此 table 對應的 horizon
  final Horizon horizon;

  /// JSON schema 版本（目前僅支援 1）
  final int schemaVersion;

  /// `generated_at` 欄位解析結果，缺失或格式錯誤時為 null
  final DateTime? generatedAt;

  /// rule_id → calibrated score 的不可變查找表
  final Map<String, int> _scores;

  /// 負證據歸零集（2026-07-29 三態 lookup）——lookup 對這些規則回 0。
  final Set<String> _zeroedRules;

  /// 查詢單一規則的 calibrated score——**三態語意（2026-07-29）**：
  ///
  /// 1. 在 [_zeroedRules] 中 → 回 **0**（負證據歸零生效，呼叫端的
  ///    `?? hardcoded` 不會觸發）
  /// 2. 有非零 calibrated 值 → 回該值
  /// 3. 不在 table / score=0 但無負證據 → 回 **null**（fallback hardcoded）
  ///
  /// ## 演進史
  ///
  /// **2026-06-19：0 一律視為 null**——當時 calibrated 0 與「未校準」共用
  /// 同一訊號，直接尊重 0 導致 38 條 cut 規則覆蓋 hardcoded、3-tab 失去
  /// ranking 訊號，故一律 fallback。
  ///
  /// **2026-07-29：拆成三態**——「一律 fallback」讓 avg<0 且 t≤−1.5 的
  /// 28 條負證據規則持續以 hardcoded 正分驅動 Mode A 排名。504 天 clustered
  /// 校準（統計面）＋ 10 日離線重放（產品面：A 縮編但零空日、被除名股
  /// 5 日超額 −1.68%）支持歸零。Mode C 的 4 條結構 gate 豁免（見
  /// [parseJson] 的 structuralExemptions），長線 horizon 不套用（其校準
  /// 仍是舊 absolute+pooled 產物，待重校準）。
  int? lookup(String ruleId) {
    if (_zeroedRules.contains(ruleId)) return 0;
    final v = _scores[ruleId];
    return (v == null || v == 0) ? null : v;
  }

  /// 取得負證據歸零集的 unmodifiable view（isolate DTO 打包用）
  Set<String> zeroedSnapshot() => Set.unmodifiable(_zeroedRules);

  /// 已載入的規則數量，供診斷與 smoke test 使用
  int get ruleCount => _scores.length;

  /// 取得 `_scores` 的 unmodifiable view
  ///
  /// 用於 [CalibratedScoresRegistry.snapshotForIsolate]：打包 DTO 時需要
  /// 讀取完整 map 內容而不暴露寫入能力。回傳的 map 可以安全跨 isolate
  /// 傳輸（Dart 會深拷貝 primitive map）。
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
  /// ## [applyNegativeEvidenceZeroing] 與 [structuralExemptions]（三態 lookup）
  ///
  /// 開啟時，score=0 且帶決定性負面證據（`avg_return < 0` 且
  /// `t_stat <= CalibrationThresholds.negativeEvidenceTStatMax`）的規則
  /// 進入歸零集——[lookup] 對其回 0 而非 null。[structuralExemptions]
  /// 中的規則一律不歸零（Mode C 結構 gate：規則是 tab 的定義而非證據
  /// 宣稱，且校準測的是無條件母體、測不到條件化用法）。缺 metadata 的
  /// cut 保守不歸零。預設關閉 = 完整保留 2026-06-19 的 fallback 契約。
  static CalibratedScoresParseResult parseJson(
    String jsonStr, {
    required Horizon horizon,
    Set<String>? knownRuleIds,
    Map<String, int>? hardcodedScores,
    bool applyNegativeEvidenceZeroing = false,
    Set<String> structuralExemptions = const {},
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
    // 防呆：parser 比對 JSON metadata 與 [CalibrationThresholds.successThresholds]
    // （以 [Horizon.tradingDays] 當 key），差距超過 0.01 即拒載並 return empty
    // table（呼叫端會走 fallback chain 退到 hardcoded `RuleScores`，與
    // calibration miss 同路徑）。
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
        // Mode-aware canonical：excess JSON 的 success_threshold_pct 是
        // 「超額百分點」語意（canonical = excessSuccessThreshold），拿絕對
        // 門檻（1.5/8.0）比對會把合法 excess JSON 全數誤殺。
        final isExcess = backtest['return_mode'] == 'excess';
        final canonical = isExcess
            ? CalibrationThresholds.excessSuccessThreshold
            : (CalibrationThresholds.successThresholds[horizon.tradingDays] ??
                  CalibrationThresholds.defaultSuccessThreshold);
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
    final zeroedRules = <String>{};
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

      // Scenario 8: sign flip vs hardcoded design intent — skip and fallback
      //
      // 例：TECH_BREAKDOWN（跌破支撐）hardcoded -20，calibrated +22。Backtest
      // 統計上 hit_rate 0.547 / t-stat 4.07 是合法 pipeline 輸出，但 UX 上
      // 使用者看到 Top 20 推薦顯示 reason chip「跌破支撐」對分數有正貢獻
      // 會直接質疑 App 的可信度。
      //
      // **2026-06-19 修正**：原本 clamp 到 0 + 寫進 `_scores`，配合 lookup
      // 把 0 視為「有值」→ hardcoded 永遠 fallback 不了 → TECH_BREAKDOWN
      // 從 -20 變成 0 → Mode C 弱勢觀察少一條 -20 訊號。
      //
      // 改成 **skip 該 rule（不寫進 _scores）**：lookup 找不到 → fallback 到
      // hardcoded -20 → Mode C 正常拿到 -20 → 跌破支撐重回 Mode C。
      //
      // sign-flip 通常代表 backtest 對單一 horizon 過擬合，design semantics
      // 才是 ground truth。pre-launch 階段強制信 hardcoded、等 Stage 4 累積
      // 真實 forward data 後再考慮放回。
      if (hardcodedScores != null) {
        final hardcoded = hardcodedScores[ruleId];
        if (hardcoded != null && hardcoded != 0 && score != 0) {
          final hardcodedPositive = hardcoded > 0;
          final calibratedPositive = score > 0;
          if (hardcodedPositive != calibratedPositive) {
            warnings.add(
              'rule $ruleId: sign flip — hardcoded $hardcoded vs calibrated '
              '$score, skipped (fallback to hardcoded)',
            );
            continue;
          }
        }
      }

      scores[ruleId] = score;

      // 三態 lookup:負證據歸零集判定(僅對 score=0 的 cut 條目)
      //
      // **方向 gate(2026-07-29 審查 B2)**:只有 hardcoded **正分**(多方
      // 宣稱)的規則可被「觸發後下跌」判死。空方/防護規則(hardcoded 負分,
      // 如 TECH_BREAKDOWN -20、KD_DEATH_CROSS -12)觸發後 avg<0 是**命題
      // 被證實**——校準管線把所有規則當多方評是已知侷限,對它們歸零等於
      // 拔掉實證有效的防護,且 mutex 排序下 0 會擊敗活著的負分。
      // hardcodedScores 未提供時保守不歸零(方向不明)。
      //
      // **顯式排除集(2026-07-30)**:hardcoded>0 判多方在「空方訊號用正
      // 顯示分」的規則(如 WEEK_52_LOW +8)上漏接——它們 avg<0 是預測
      // 正確。見 [CalibrationThresholds.zeroingBearishDisplayExclusions]。
      if (applyNegativeEvidenceZeroing &&
          score == 0 &&
          !structuralExemptions.contains(ruleId) &&
          !CalibrationThresholds.zeroingBearishDisplayExclusions.contains(
            ruleId,
          ) &&
          (hardcodedScores?[ruleId] ?? 0) > 0) {
        final avg = ruleValue['avg_return'];
        final t = ruleValue['t_stat'];
        if (avg is num &&
            t is num &&
            avg < 0 &&
            t <= CalibrationThresholds.negativeEvidenceTStatMax) {
          zeroedRules.add(ruleId);
        }
      }
    }

    return (
      table: CalibratedScoresTable(
        horizon: horizon,
        schemaVersion: schemaVersion,
        generatedAt: generatedAt,
        scores: scores,
        zeroedRules: zeroedRules,
      ),
      warnings: warnings,
    );
  }
}
