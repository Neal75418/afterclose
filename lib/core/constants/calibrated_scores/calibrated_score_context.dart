import 'package:meta/meta.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

/// Scoring isolate 使用的 calibrated scores 查詢 context
///
/// 封裝兩個 horizon 的 `rule_id → calibrated score` 查找表，
/// 由主 isolate 從 [CalibratedScoresRegistry.snapshotForIsolate] 抽取後
/// 透過 [ScoringIsolateInput] 序列化傳入 scoring isolate。
///
/// ## 為什麼需要此 DTO
///
/// [CalibratedScoresRegistry] 是主 isolate 的 singleton，無法被
/// `Isolate.run()` spawn 的新 isolate 存取（isolate 間記憶體隔離）。
/// 在 isolate 邊界引入此 typed DTO，讓 scoring isolate 內的
/// `calculateScore` 能同步查詢兩個 horizon 的 calibrated 分數。
///
/// 設計對齊 [`CLAUDE.md`] 的 Isolate 通訊規則：
/// > 使用 typed DTO (ShareholdingData, WarningDataContext,
/// > InsiderDataContext)，避免 `Map<String, dynamic>`
///
/// ## 查詢語意
///
/// - [lookup] 回傳 `int?`：存在即為 calibrated value
/// - 查無（rule 未 calibrated 或 map 為空）回傳 null
/// - 呼叫端應 fallback 到 `TriggeredReason.score`（hardcoded embedded）
///
/// ## 空 context
///
/// 使用 [CalibratedScoreContext.empty] 產生空 context，所有查詢都會回 null，
/// 等效於「全部走 hardcoded fallback」。Pre-launch 時 placeholder JSON 是
/// 空的，這是預期的常態行為。
@immutable
class CalibratedScoreContext {
  const CalibratedScoreContext({
    required this.shortScores,
    required this.longScores,
  });

  /// 短線 horizon 的 rule_id → calibrated score 查找表
  final Map<String, int> shortScores;

  /// 長線 horizon 的 rule_id → calibrated score 查找表
  final Map<String, int> longScores;

  /// 空 context — 用於 registry 未載入、placeholder 為空、測試或 default param。
  ///
  /// 所有 [lookup] 查詢都會回 null，呼叫端自然走 fallback 路徑。
  /// 是 const 實例，可在 `const` 建構式或 default param 中直接使用。
  static const CalibratedScoreContext empty = CalibratedScoreContext(
    shortScores: <String, int>{},
    longScores: <String, int>{},
  );

  /// Horizon-aware 查詢單一規則的 calibrated score
  ///
  /// 若 [ruleId] 不在對應 horizon 的查找表中**或被 calibrated 砍到 0**，
  /// 回傳 null。呼叫端應 fallback 到 `TriggeredReason.score`（hardcoded
  /// embedded 值）。
  ///
  /// **2026-06-19**：跟 [CalibratedScoresTable.lookup] 對齊 — 0 視為 null
  /// fallback。原本 `Map<String, int>` 直接查 → score=0 回 0、把 caller 的
  /// `lookup() ?? hardcoded` fallback 永遠不會觸發；38 條被 calibrated 砍到
  /// 0 的 rule 在 scoring isolate 寫進 daily_reason 時拿 0 而非 hardcoded
  /// 正分，整個 Mode aggregator 失去 ranking 訊號。
  ///
  /// 這個 context 跟 [CalibratedScoresTable] 是兩個獨立 class（前者是 isolate
  /// DTO、後者是主 isolate 的 lookup table），fallback 邏輯必須兩邊同時修。
  int? lookup(Horizon horizon, String ruleId) {
    final v = switch (horizon) {
      Horizon.short => shortScores[ruleId],
      Horizon.long => longScores[ruleId],
    };
    return (v == null || v == 0) ? null : v;
  }

  /// 序列化為 `Map<String, dynamic>` 供 isolate 邊界傳輸
  ///
  /// 因為內部只有 `Map<String, int>`（primitive-only），序列化不需要
  /// 額外的 nested encoding。
  Map<String, dynamic> toMap() => {
    'shortScores': shortScores,
    'longScores': longScores,
  };

  /// 從 isolate 邊界反序列化 Map
  ///
  /// 容錯處理：null 或缺失欄位會 fall back 到空 map，呼叫端的查詢
  /// 會回 null 進而 fallback 到 hardcoded。不會 throw。
  factory CalibratedScoreContext.fromMap(Map<String, dynamic> map) =>
      CalibratedScoreContext(
        shortScores: Map<String, int>.from(
          (map['shortScores'] ?? <String, int>{}) as Map,
        ),
        longScores: Map<String, int>.from(
          (map['longScores'] ?? <String, int>{}) as Map,
        ),
      );
}
