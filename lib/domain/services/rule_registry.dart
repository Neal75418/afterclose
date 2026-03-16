import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:afterclose/domain/services/rules/indicator_rules.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart';
import 'package:afterclose/domain/services/rules/institutional_rules.dart';
import 'package:afterclose/domain/services/rules/extended_market_rules.dart';
import 'package:afterclose/domain/services/rules/divergence_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_scan_rules.dart';
import 'package:afterclose/domain/services/rules/insider_rules.dart';
import 'package:afterclose/domain/services/rules/warning_rules.dart';

/// 規則註冊表 — 集中管理所有可用規則
abstract final class RuleRegistry {
  /// 所有預設規則
  static const List<StockRule> defaultRules = [
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
    ConcentrationHighRule(),
    // 第 5 階段：價量背離規則
    PriceVolumeBullishDivergenceRule(),
    PriceVolumeBearishDivergenceRule(),
    HighVolumeBreakoutRule(),
    LowVolumeAccumulationRule(),
    // 第 6 階段：基本面分析規則
    RevenueYoYSurgeRule(),
    RevenueYoYDeclineRule(),
    RevenueMomGrowthRule(),
    RevenueNewHighRule(),
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

  /// 按分類取得規則
  static List<StockRule> byCategory(RuleCategory category) =>
      defaultRules.where((r) => r.category == category).toList();

  /// 規則數量統計
  static Map<RuleCategory, int> get categoryCounts {
    final counts = <RuleCategory, int>{};
    for (final rule in defaultRules) {
      counts[rule.category] = (counts[rule.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 所有規則數量
  static int get totalCount => defaultRules.length;
}
