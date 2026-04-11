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

  /// 對股票執行所有規則並回傳觸發的原因
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

    // 依分數由高至低排序（mutex group 過濾依賴此順序決定 group 內贏家）
    triggered.sort((a, b) => b.score.compareTo(a.score));

    // Mutex group 過濾：重疊訊號只計最高分那條
    return _applyMutexGroups(triggered);
  }

  /// 同一 mutex group 內只保留分數最高的 reason。
  ///
  /// 前提：輸入已按 [TriggeredReason.score] 由高至低排序。
  /// 不屬於任何 group 的 reason 原樣保留。
  List<TriggeredReason> _applyMutexGroups(List<TriggeredReason> sortedReasons) {
    if (sortedReasons.isEmpty) return sortedReasons;

    final seenGroups = <String>{};
    final result = <TriggeredReason>[];
    for (final reason in sortedReasons) {
      final group = _reasonToGroup[reason.type];
      if (group == null) {
        result.add(reason); // 不屬於任何 group
      } else if (seenGroups.add(group)) {
        result.add(reason); // group 內第一次遇到（分數最高），勝出
      }
      // 其他：已有該 group 贏家，跳過
    }
    return result;
  }

  /// 計算最終分數，含冷卻懲罰與上限
  ///
  /// 組合加成（breakout+volume、reversal+volume、institutional+combo）已於
  /// 2026-04 移除：個別規則本身已要求量能配合，再加 bonus 是 double-count，
  /// 且會讓多訊號股票全部黏在 maxScore 80 失去區分度。
  int calculateScore(
    List<TriggeredReason> reasons, {
    bool wasRecentlyRecommended = false,
  }) {
    if (reasons.isEmpty) return 0;

    double score = 0.0;

    // 1. 累計各規則的基礎分數（多空訊號透過正負分數自然抵消）
    for (final reason in reasons) {
      score += reason.score;
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

    // 依 description 去重複，同一規則不會產生相同描述
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
