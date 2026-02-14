import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==================================================
// Killer Features：董監持股規則
// ==================================================

/// 規則：董監連續減持
///
/// 當董監連續數月減持時觸發（強賣訊號）
class InsiderSellingStreakRule extends StockRule {
  const InsiderSellingStreakRule();

  @override
  String get id => 'insider_selling_streak';

  @override
  String get name => '董監連續減持';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final insiderData = context.marketData?.insiderData;
    if (insiderData == null) return null;

    // 當董監連續減持達到門檻月數時觸發
    if (insiderData.hasSellingStreak &&
        insiderData.sellingStreakMonths >=
            RuleParams.insiderSellingStreakMonths) {
      return TriggeredReason(
        type: ReasonType.insiderSellingStreak,
        score: RuleScores.insiderSellingStreak,
        description: '董監連續 ${insiderData.sellingStreakMonths} 個月減持（強賣訊號）',
        evidence: {
          'sellingStreakMonths': insiderData.sellingStreakMonths,
          'insiderRatio': insiderData.insiderRatio,
        },
      );
    }

    return null;
  }
}

/// 規則：董監顯著增持
///
/// 當董監大量增持時觸發（買進訊號）
class InsiderSignificantBuyingRule extends StockRule {
  const InsiderSignificantBuyingRule();

  @override
  String get id => 'insider_significant_buying';

  @override
  String get name => '董監大量增持';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final insiderData = context.marketData?.insiderData;
    if (insiderData == null) return null;

    // 當董監增持超過門檻時觸發
    // 使用本地變數避免多次 null 檢查和強制解包
    final buyingChange = insiderData.buyingChange;
    if (insiderData.hasSignificantBuying &&
        buyingChange != null &&
        buyingChange >= RuleParams.insiderSignificantBuyingThreshold) {
      return TriggeredReason(
        type: ReasonType.insiderSignificantBuying,
        score: RuleScores.insiderSignificantBuying,
        description: '董監增持 ${buyingChange.toStringAsFixed(1)}%（買進訊號）',
        evidence: {
          'buyingChange': buyingChange,
          'insiderRatio': insiderData.insiderRatio,
        },
      );
    }

    return null;
  }
}

/// 規則：高質押比例
///
/// 當董監質押比例過高時觸發（風險警示）
class HighPledgeRatioRule extends StockRule {
  const HighPledgeRatioRule();

  @override
  String get id => 'high_pledge_ratio';

  @override
  String get name => '高質押比例';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final insiderData = context.marketData?.insiderData;
    if (insiderData == null) return null;

    final pledgeRatio = insiderData.pledgeRatio;
    if (pledgeRatio == null) return null;

    // 當質押比例超過門檻時觸發
    if (pledgeRatio >= RuleParams.highPledgeRatioThreshold) {
      return TriggeredReason(
        type: ReasonType.highPledgeRatio,
        score: RuleScores.highPledgeRatio,
        description: '董監質押比例 ${pledgeRatio.toStringAsFixed(1)}%（風險警示）',
        evidence: {
          'pledgeRatio': pledgeRatio,
          'insiderRatio': insiderData.insiderRatio,
        },
      );
    }

    return null;
  }
}

/// 規則：外資持股高度集中
///
/// 當外資持股超過警示門檻時觸發（風險警示）
class ForeignConcentrationWarningRule extends StockRule {
  const ForeignConcentrationWarningRule();

  @override
  String get id => 'foreign_concentration_warning';

  @override
  String get name => '外資高度集中';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final foreignRatio = marketData.foreignSharesRatio;
    if (foreignRatio == null) return null;

    // 當外資持股超過警示門檻時觸發
    if (foreignRatio >= RuleParams.foreignConcentrationWarningThreshold) {
      final isDanger =
          foreignRatio >= RuleParams.foreignConcentrationDangerThreshold;
      final description = isDanger
          ? '外資持股 ${foreignRatio.toStringAsFixed(1)}%（高度集中風險）'
          : '外資持股 ${foreignRatio.toStringAsFixed(1)}%（集中度警示）';

      return TriggeredReason(
        type: ReasonType.foreignConcentrationWarning,
        score: RuleScores.foreignConcentrationWarning,
        description: description,
        evidence: {'foreignSharesRatio': foreignRatio, 'isDanger': isDanger},
      );
    }

    return null;
  }
}

/// 規則：外資加速流出
///
/// 當外資連續多日大量賣出時觸發（強賣訊號）
class ForeignExodusRule extends StockRule {
  const ForeignExodusRule();

  @override
  String get id => 'foreign_exodus';

  @override
  String get name => '外資加速流出';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final change = marketData.foreignSharesRatioChange;
    if (change == null) return null;

    // 當外資持股變化低於門檻時觸發（門檻為負值）
    if (change <= RuleParams.foreignExodusThreshold) {
      return TriggeredReason(
        type: ReasonType.foreignExodus,
        score: RuleScores.foreignExodus,
        description:
            '外資 ${RuleParams.foreignExodusLookbackDays} 日持股減少 ${change.abs().toStringAsFixed(2)}%（加速流出）',
        evidence: {
          'foreignSharesRatioChange': change,
          'lookbackDays': RuleParams.foreignExodusLookbackDays,
        },
      );
    }

    return null;
  }
}
