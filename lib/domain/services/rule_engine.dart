import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_registry.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

/// 股票分析規則引擎
///
/// 使用策略模式（Strategy Pattern）對股票資料套用一系列 [StockRule] 規則
class RuleEngine {
  /// 建立規則引擎，可選擇傳入自訂規則
  ///
  /// 若提供 [customRules]，則僅使用該規則集；否則載入預設規則集
  RuleEngine({List<StockRule>? customRules}) {
    _rules.addAll(customRules ?? RuleRegistry.defaultRules);
  }

  final List<StockRule> _rules = [];

  /// Mutex groups — 同 group 內的規則視為「同一個面向的訊號」，只保留分數最高的一條
  ///
  /// 動機：部分規則定義上彼此重疊（例如放量突破會同時觸發 VOLUME_SPIKE、PRICE_SPIKE、
  /// TECH_BREAKOUT、HIGH_VOLUME_BREAKOUT），若全部累加會 double-count 導致分數膨脹塞
  /// 爆 cap，使 Top 20 失去區分度。用 mutex group 語義讓「同一個訊號」只計一次。
  ///
  /// 贏家決定規則：依 [TriggeredReason.score] 由高至低，group 內第一個遇到的即是贏家。
  /// 分數相同時，依 [_rules] 註冊順序（Dart List.sort 為 stable sort）決定贏家 —
  /// 此行為 deterministic，由 [RuleRegistry.defaultRules] 順序隱含定義。
  ///
  /// **INVARIANT**：每個 [ReasonType] 最多只能出現在**一個** group 中。違反時
  /// [_reasonToGroup] 會靜默採用「最後寫入者勝出」，Stage 2 新增 group 時要特別注意。
  static const Map<String, Set<ReasonType>> _mutexGroups = {
    'momentum_breakout': {
      ReasonType.techBreakout,
      ReasonType.volumeSpike,
      ReasonType.priceSpike,
      ReasonType.highVolumeBreakout,
    },
  };

  /// Reverse lookup — `ReasonType → group name`，由 [_mutexGroups] 展開建構
  static final Map<ReasonType, String> _reasonToGroup = {
    for (final entry in _mutexGroups.entries)
      for (final type in entry.value) type: entry.key,
  };

  /// 對股票執行所有規則並回傳**所有**觸發的原因（**未經 mutex 過濾**）
  ///
  /// Mutex 過濾改成由消費端在進入 [calculateScore] / [getTopReasons] 前
  /// **顯式**呼叫 [applyMutexGroups]，並自行決定要用哪個 `scoreOf`：
  /// - scoring 路徑（scoring_isolate / scoring_service）：每個 horizon 各
  ///   呼一次 applyMutexGroups，`scoreOf` 是 horizon-aware calibrated lookup
  ///   （Stage 5b 設計：scoring 是 calibration 的 source of truth）
  /// - UI 路徑（getTopReasons）：呼叫端傳 `(r) => r.score`（hardcoded，
  ///   對應 design intent — UI 顯示「最強訊號」與舊行為一致）
  ///
  /// 過去 evaluateStock 直接套 hardcoded mutex，會把 calibration 永遠鎖在
  /// hardcoded 排序上 — 即使 calibration 認為 volumeSpike 在某 horizon
  /// 比 techBreakout 強，也無法贏 mutex。同時 mutex loser 規則永遠拿不到
  /// calibration sample，因為 replay_calibrator 也吃這份過濾結果。
  /// 把 mutex 延後到 score-aware 階段同時解這兩個問題。
  List<TriggeredReason> evaluateStock(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return [];

    final triggered = <TriggeredReason>[];

    for (final rule in _rules) {
      try {
        final reason = rule.evaluate(context, data);
        if (reason != null) {
          triggered.add(reason);
        }
      } catch (e, stackTrace) {
        // 記錄規則執行失敗，但不中斷程式
        AppLogger.warning('RuleEngine', '規則 ${rule.id} 評估失敗', e, stackTrace);
      }
    }

    // 依 hardcoded 分數排序（穩定輸出順序，供下游可預期 iteration）
    triggered.sort((a, b) => b.score.compareTo(a.score));
    return triggered;
  }

  /// 同一 mutex group 內只保留 [scoreOf] 回傳值最高的 reason。
  ///
  /// 由呼叫端在進 [calculateScore] / [getTopReasons] 之前**顯式**呼叫；
  /// 這兩個 method 本身都不再做 mutex（pure 算術 / pure dedup）。
  /// [scoreOf] 由呼叫端提供：
  /// - scoring 路徑：horizon-aware calibrated lookup（每 horizon 各呼一次）
  /// - UI 顯示路徑：通常傳 `(r) => r.score`（hardcoded，對應 design
  ///   intent — UI 顯示「最強訊號」的可讀性比 calibration 結果更重要）
  ///
  /// 內部會 stable-sort 輸入再過濾 — 呼叫端不需先排序。
  /// 不屬於任何 group 的 reason 原樣保留。
  List<TriggeredReason> applyMutexGroups(
    List<TriggeredReason> reasons,
    int Function(TriggeredReason) scoreOf,
  ) {
    if (reasons.isEmpty) return reasons;

    final sorted = [...reasons]
      ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));

    final seenGroups = <String>{};
    final result = <TriggeredReason>[];
    for (final reason in sorted) {
      final group = _reasonToGroup[reason.type];
      if (group == null) {
        result.add(reason); // 不屬於任何 group
      } else if (seenGroups.add(group)) {
        result.add(reason); // group 內第一次遇到（scoreOf 最高），勝出
      }
      // 其他：已有該 group 贏家，跳過
    }
    return result;
  }

  /// 計算最終分數，含冷卻懲罰與上限
  ///
  /// ## Dual-horizon (Stage 5b)
  ///
  /// 此 method 必須指定 [horizon]。每個 reason 會先嘗試在
  /// [calibratedScores] 對應 horizon 的查找表中查 calibrated 值，
  /// 查無則 fallback 到 `TriggeredReason.score`（hardcoded embedded）。
  /// 呼叫端需為每支股票分別呼叫 `Horizon.short` 與 `Horizon.long` 以得到
  /// 雙 horizon 分數。
  ///
  /// [calibratedScores] 預設為 [CalibratedScoreContext.empty]，代表
  /// 「所有規則都走 fallback」— 等效 Stage 5a 行為，單元測試可省略此參數。
  ///
  /// ## 組合加成已移除
  ///
  /// 組合加成（breakout+volume、reversal+volume、institutional+combo）已於
  /// 2026-04 移除：個別規則本身已要求量能配合，再加 bonus 是 double-count，
  /// 且會讓多訊號股票全部黏在 maxScore 80 失去區分度。
  int calculateScore(
    List<TriggeredReason> reasons, {
    required Horizon horizon,
    CalibratedScoreContext calibratedScores = CalibratedScoreContext.empty,
    bool wasRecentlyRecommended = false,
  }) {
    if (reasons.isEmpty) return 0;

    double score = 0.0;

    // 1. 累計各規則的分數 — 優先用 calibrated 值，查無則 fallback 到
    //    hardcoded `reason.score`。多空訊號透過正負分數自然抵消。
    //
    // 注意：本 method 是純算術契約（sum + cooldown + clamp），不做 mutex
    // 過濾。Mutex 過濾應由呼叫端（scoring_isolate / scoring_service）
    // 用 horizon-aware scoreOf 呼叫 [applyMutexGroups] 後再傳進來 —
    // 這樣 calibration 才能影響哪條 rule 贏 mutex group。
    for (final reason in reasons) {
      final calibrated = calibratedScores.lookup(horizon, reason.type.code);
      score += calibrated ?? reason.score;
    }

    // 2. 冷卻期懲罰：固定扣分而非乘數，避免高分股被不公平腰斬
    if (wasRecentlyRecommended) {
      score -= RuleParams.cooldownPenalty;
    }

    // 3. 分數範圍限制（下限 0：僅推薦做多；上限 maxScore 避免多訊號膨脹）
    if (score < 0) score = 0;
    if (score > RuleScores.maxScore) score = RuleScores.maxScore.toDouble();

    return score.round();
  }

  /// 取得觸發原因（去重複）供資料庫儲存與篩選
  ///
  /// 依 description 去重複（每條規則產生唯一描述），保留所有不同規則的觸發結果。
  /// 例如同為 institutionalBuy 類型的「外資連續買超」和「法人由賣轉買」都會被保留。
  /// UI 層自行使用 .take(2) 或 .take(3) 控制顯示數量。
  List<TriggeredReason> getTopReasons(List<TriggeredReason> reasons) {
    if (reasons.isEmpty) return [];

    // 依 description 去重複，同一規則不會產生相同描述。
    // 注意：本 method 不做 mutex 過濾 — 呼叫端如果需要先過濾 mutex 應該
    // 顯式呼 [applyMutexGroups]。把職責分開讓單元測試各自獨立。
    final seenDescriptions = <String>{};
    final result = <TriggeredReason>[];

    for (final r in reasons) {
      if (seenDescriptions.add(r.description)) {
        result.add(r);
      }
    }

    return result;
  }
}
