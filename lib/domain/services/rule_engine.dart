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

    // 依分數由高至低排序
    triggered.sort((a, b) => b.score.compareTo(a.score));

    return triggered;
  }

  /// 計算最終分數，包含加成、懲罰與上限
  int calculateScore(
    List<TriggeredReason> reasons, {
    bool wasRecentlyRecommended = false,
  }) {
    if (reasons.isEmpty) return 0;

    double score = 0.0;

    // 1. 累計各規則的基礎分數
    for (final reason in reasons) {
      score += reason.score;
    }

    // 2. 組合加成
    // 放量 + 突破 = 更強訊號
    final hasVolume = reasons.any((r) => r.type == ReasonType.volumeSpike);
    final hasBreakout = reasons.any((r) => r.type == ReasonType.techBreakout);
    final hasReversal = reasons.any((r) => r.type == ReasonType.reversalW2S);
    final hasInstitutional = reasons.any(
      (r) => r.type == ReasonType.institutionalBuy,
    );

    if (hasVolume && hasBreakout) score += RuleScores.breakoutVolumeBonus;
    if (hasVolume && hasReversal) score += RuleScores.reversalVolumeBonus;
    if (hasInstitutional && (hasBreakout || hasReversal)) {
      score += RuleScores.institutionalComboBonus;
    }

    // 3. 衝突訊號處理
    // 多空訊號已透過正負分數自然抵消：
    // - 多方訊號（突破、反轉、法人買超）為正分
    // - 空方訊號（跌破、強轉弱、空頭排列）為負分
    // 當多空訊號並存時，分數會自動降低

    // 4. 冷卻期懲罰：固定扣分而非乘數，避免高分股被不公平腰斬
    if (wasRecentlyRecommended) {
      score -= RuleParams.cooldownPenalty;
    }

    // 5. 分數範圍限制
    // 下限：0（本系統僅推薦做多，不推薦放空）
    // 上限：maxScore（避免多訊號造成分數膨脹）
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
