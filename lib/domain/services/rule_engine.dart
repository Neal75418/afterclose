import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart';
import 'package:afterclose/domain/services/rules/divergence_rules.dart';
import 'package:afterclose/domain/services/rules/extended_market_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_scan_rules.dart';
import 'package:afterclose/domain/services/rules/indicator_rules.dart';
import 'package:afterclose/domain/services/rules/insider_rules.dart';
import 'package:afterclose/domain/services/rules/institutional_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:afterclose/domain/services/rules/warning_rules.dart';
import 'package:afterclose/domain/models/models.dart';

/// 股票分析規則引擎
///
/// 使用策略模式（Strategy Pattern）對股票資料套用一系列 [StockRule] 規則
class RuleEngine {
  /// 建立規則引擎，可選擇傳入自訂規則
  ///
  /// 若提供 [customRules]，則僅使用該規則集；否則載入預設規則集
  RuleEngine({List<StockRule>? customRules}) {
    if (customRules != null) {
      _rules.addAll(customRules);
    } else {
      _rules.addAll(_defaultRules);
    }
  }

  /// 預設規則集 - 第 1-6 階段規則
  static const List<StockRule> _defaultRules = [
    // 第 1 階段：基礎規則
    WeakToStrongRule(),
    StrongToWeakRule(),
    BreakoutRule(),
    BreakdownRule(),
    VolumeSpikeRule(),
    PriceSpikeRule(),
    InstitutionalShiftRule(),
    NewsRule(),
    // 第 2 階段：K 線型態規則
    DojiRule(),
    BullishEngulfingRule(),
    BearishEngulfingRule(),
    HammerRule(),
    HangingManRule(),
    GapUpRule(),
    GapDownRule(),
    MorningStarRule(),
    EveningStarRule(),
    ThreeWhiteSoldiersRule(),
    ThreeBlackCrowsRule(),
    // 第 3 階段：技術訊號規則
    Week52HighRule(),
    Week52LowRule(),
    MAAlignmentBullishRule(),
    MAAlignmentBearishRule(),
    RSIExtremeOverboughtRule(),
    RSIExtremeOversoldRule(),
    KDGoldenCrossRule(),
    KDDeathCrossRule(),
    // 第 4 階段：法人連續買賣規則
    InstitutionalBuyStreakRule(),
    InstitutionalSellStreakRule(),
    // 第 4 階段：擴展市場資料規則
    ForeignShareholdingIncreasingRule(),
    ForeignShareholdingDecreasingRule(),
    DayTradingHighRule(),
    DayTradingExtremeRule(),
    // 備註：ConcentrationHighRule 已移除 - 需要付費 API（股權分散表）
    // 第 5 階段：價量背離規則
    PriceVolumeBullishDivergenceRule(),
    PriceVolumeBearishDivergenceRule(),
    HighVolumeBreakoutRule(),
    LowVolumeAccumulationRule(),
    // 第 6 階段：基本面分析規則
    RevenueYoYSurgeRule(),
    RevenueYoYDeclineRule(),
    RevenueMomGrowthRule(),
    HighDividendYieldRule(),
    PEUndervaluedRule(),
    PEOvervaluedRule(),
    PBRUndervaluedRule(),
    // 第 7 階段：EPS 分析規則
    EPSYoYSurgeRule(),
    EPSConsecutiveGrowthRule(),
    EPSTurnaroundRule(),
    EPSDeclineWarningRule(),
    // 第 8 階段：ROE 分析規則
    ROEExcellentRule(),
    ROEImprovingRule(),
    ROEDecliningRule(),
    // Killer Features：注意/處置股票規則
    TradingWarningAttentionRule(),
    TradingWarningDisposalRule(),
    // Killer Features：董監持股規則
    InsiderSellingStreakRule(),
    InsiderSignificantBuyingRule(),
    HighPledgeRatioRule(),
    ForeignConcentrationWarningRule(),
    ForeignExodusRule(),
  ];

  final List<StockRule> _rules = [];

  /// 動態註冊新規則
  void registerRule(StockRule rule) => _rules.add(rule);

  /// 根據規則 ID 動態移除規則
  void unregisterRule(String ruleId) =>
      _rules.removeWhere((r) => r.id == ruleId);

  /// 對股票執行所有規則並回傳觸發的原因
  List<TriggeredReason> evaluateStock({
    required List<DailyPriceEntry> priceHistory,
    required AnalysisContext context,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<NewsItemEntry>? recentNews,
    String? symbol,
    MonthlyRevenueEntry? latestRevenue,
    StockValuationEntry? latestValuation,
    List<MonthlyRevenueEntry>? revenueHistory,
    List<FinancialDataEntry>? epsHistory,
    List<FinancialDataEntry>? roeHistory,
    List<DividendHistoryEntry>? dividendHistory,
  }) {
    if (priceHistory.isEmpty) return [];

    final data = StockData(
      symbol: symbol ?? 'UNKNOWN',
      prices: priceHistory,
      institutional: institutionalHistory,
      news: recentNews,
      latestRevenue: latestRevenue,
      latestValuation: latestValuation,
      revenueHistory: revenueHistory,
      epsHistory: epsHistory,
      roeHistory: roeHistory,
      dividendHistory: dividendHistory,
    );

    final triggered = <TriggeredReason>[];

    for (final rule in _rules) {
      try {
        final reason = rule.evaluate(context, data);
        if (reason != null) {
          triggered.add(reason);
        }
      } catch (e, stackTrace) {
        // 記錄規則執行失敗，但不中斷程式
        AppLogger.warning(
          'RuleEngine',
          '規則 ${rule.id} 評估失敗: $e',
          e,
          stackTrace,
        );
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
    // 上限：100（避免多訊號造成分數膨脹）
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    return score.round();
  }

  /// 取得觸發原因（去重複）供資料庫儲存與篩選
  ///
  /// 回傳所有不重複類型的原因，確保篩選功能正常。
  /// UI 層自行使用 .take(2) 或 .take(3) 控制顯示數量。
  List<TriggeredReason> getTopReasons(List<TriggeredReason> reasons) {
    if (reasons.isEmpty) return [];

    // 依類型去重複，保留所有觸發的規則供篩選使用
    final distinct = <ReasonType>{};
    final result = <TriggeredReason>[];

    for (final r in reasons) {
      if (!distinct.contains(r.type)) {
        distinct.add(r.type);
        result.add(r);
      }
    }

    return result;
  }
}
