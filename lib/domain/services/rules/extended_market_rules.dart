import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 第 4 階段：擴展市場資料規則
// ==========================================

/// 規則：外資持股增加
///
/// 當外資持股比例顯著增加時觸發
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

    // 當外資持股增加達到門檻時觸發
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

/// 規則：外資持股減少
///
/// 當外資持股比例顯著減少時觸發
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

    // 當外資持股減少達到門檻時觸發
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

/// 規則：高當沖比例
///
/// 當當沖比例超過門檻時觸發
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

    // 過濾條件：成交量 > 5000 股且價格上漲（收盤 > 開盤或漲幅 > 0）
    final lastPrice = data.prices.isNotEmpty ? data.prices.last : null;
    if (lastPrice == null ||
        lastPrice.volume == null ||
        lastPrice.volume! < RuleParams.minDayTradingVolumeShares) {
      return null;
    }

    // 高當沖比例不嚴格要求多頭價格走勢
    // 高週轉率在賣壓中也常發生
    // 我們著重在活動水平（比例與成交量）

    // 當當沖比例超過高門檻時觸發
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

/// 規則：極高當沖比例
///
/// 當當沖比例極高時觸發（投機警示）
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

    // 過濾條件：成交量 > 5000 股
    final lastPrice = data.prices.isNotEmpty ? data.prices.last : null;
    if (lastPrice == null ||
        lastPrice.volume == null ||
        lastPrice.volume! < RuleParams.minDayTradingVolumeShares) {
      return null;
    }

    // 當當沖比例超過極端門檻時觸發
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

/// 規則：籌碼集中
///
/// 當大戶持股集中度超過門檻時觸發
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

    // 當籌碼集中度超過門檻時觸發
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
