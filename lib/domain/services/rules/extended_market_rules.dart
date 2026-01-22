import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Phase 4: Extended Market Data Rules
// ==========================================

/// Rule: Foreign Shareholding Increasing
/// Triggers when foreign ownership increases by a significant percentage
class ForeignShareholdingIncreasingRule extends StockRule {
  const ForeignShareholdingIncreasingRule();

  @override
  String get id => 'foreign_shareholding_increasing';

  @override
  String get name => '外資持股增加';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final change = marketData.foreignSharesRatioChange;
    if (change == null) return null;

    // Trigger when foreign shareholding increases by threshold
    if (change >= RuleParams.foreignShareholdingIncreaseThreshold) {
      return TriggeredReason(
        type: ReasonType.foreignShareholdingIncreasing,
        score: RuleScores.foreignShareholdingIncreasing,
        description: '外資持股比例增加 ${change.toStringAsFixed(2)}%',
        evidence: {'change': change, 'ratio': marketData.foreignSharesRatio},
      );
    }

    return null;
  }
}

/// Rule: Foreign Shareholding Decreasing
/// Triggers when foreign ownership decreases by a significant percentage
class ForeignShareholdingDecreasingRule extends StockRule {
  const ForeignShareholdingDecreasingRule();

  @override
  String get id => 'foreign_shareholding_decreasing';

  @override
  String get name => '外資持股減少';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final change = marketData.foreignSharesRatioChange;
    if (change == null) return null;

    // Trigger when foreign shareholding decreases by threshold
    if (change <= -RuleParams.foreignShareholdingIncreaseThreshold) {
      return TriggeredReason(
        type: ReasonType.foreignShareholdingDecreasing,
        score: RuleScores.foreignShareholdingDecreasing,
        description: '外資持股比例減少 ${change.abs().toStringAsFixed(2)}%',
        evidence: {'change': change, 'ratio': marketData.foreignSharesRatio},
      );
    }

    return null;
  }
}

/// Rule: High Day Trading Ratio
/// Triggers when day trading ratio exceeds threshold
class DayTradingHighRule extends StockRule {
  const DayTradingHighRule();

  @override
  String get id => 'day_trading_high';

  @override
  String get name => '高當沖比例';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final ratio = marketData.dayTradingRatio;
    if (ratio == null) return null;

    // Trigger when day trading ratio exceeds high threshold
    if (ratio >= RuleParams.dayTradingHighThreshold &&
        ratio < RuleParams.dayTradingExtremeThreshold) {
      return TriggeredReason(
        type: ReasonType.dayTradingHigh,
        score: RuleScores.dayTradingHigh,
        description: '當沖比例 ${ratio.toStringAsFixed(1)}%',
        evidence: {'dayTradingRatio': ratio},
      );
    }

    return null;
  }
}

/// Rule: Extreme Day Trading Ratio
/// Triggers when day trading ratio is extremely high (speculative warning)
class DayTradingExtremeRule extends StockRule {
  const DayTradingExtremeRule();

  @override
  String get id => 'day_trading_extreme';

  @override
  String get name => '極高當沖比例';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final ratio = marketData.dayTradingRatio;
    if (ratio == null) return null;

    // Trigger when day trading ratio exceeds extreme threshold
    if (ratio >= RuleParams.dayTradingExtremeThreshold) {
      return TriggeredReason(
        type: ReasonType.dayTradingExtreme,
        score: RuleScores.dayTradingExtreme,
        description: '當沖比例極高 ${ratio.toStringAsFixed(1)}%（警示）',
        evidence: {'dayTradingRatio': ratio},
      );
    }

    return null;
  }
}

/// Rule: High Concentration Ratio
/// Triggers when large holder concentration exceeds threshold
class ConcentrationHighRule extends StockRule {
  const ConcentrationHighRule();

  @override
  String get id => 'concentration_high';

  @override
  String get name => '籌碼集中';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final marketData = context.marketData;
    if (marketData == null) return null;

    final ratio = marketData.concentrationRatio;
    if (ratio == null) return null;

    // Trigger when concentration ratio exceeds threshold
    if (ratio >= RuleParams.concentrationHighThreshold) {
      return TriggeredReason(
        type: ReasonType.concentrationHigh,
        score: RuleScores.concentrationHigh,
        description: '大戶持股比例 ${ratio.toStringAsFixed(1)}%',
        evidence: {'concentrationRatio': ratio},
      );
    }

    return null;
  }
}
