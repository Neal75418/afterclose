import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Phase 6: Fundamental Analysis Rules
// ==========================================

/// Rule: Revenue YoY Surge
/// Triggers when monthly revenue YoY growth > 30%
class RevenueYoYSurgeRule extends StockRule {
  const RevenueYoYSurgeRule();

  @override
  String get id => 'revenue_yoy_surge';

  @override
  String get name => '營收年增暴增';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final revenue = data.latestRevenue;
    if (revenue == null) return null;

    final yoyGrowth = revenue.yoyGrowth ?? 0;

    if (yoyGrowth >= RuleParams.revenueYoySurgeThreshold) {
      return TriggeredReason(
        type: ReasonType.revenueYoySurge,
        score: RuleScores.revenueYoySurge,
        description: '營收年增 ${yoyGrowth.toStringAsFixed(1)}%',
        evidence: {
          'yoyGrowth': yoyGrowth,
          'revenueYear': revenue.revenueYear,
          'revenueMonth': revenue.revenueMonth,
          'revenue': revenue.revenue,
        },
      );
    }

    return null;
  }
}

/// Rule: Revenue YoY Decline
/// Triggers when monthly revenue YoY growth < -20% (warning)
class RevenueYoYDeclineRule extends StockRule {
  const RevenueYoYDeclineRule();

  @override
  String get id => 'revenue_yoy_decline';

  @override
  String get name => '營收年減警示';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final revenue = data.latestRevenue;
    if (revenue == null) return null;

    final yoyGrowth = revenue.yoyGrowth ?? 0;

    if (yoyGrowth <= -RuleParams.revenueYoyDeclineThreshold) {
      return TriggeredReason(
        type: ReasonType.revenueYoyDecline,
        score: RuleScores.revenueYoyDecline,
        description: '營收年減 ${yoyGrowth.abs().toStringAsFixed(1)}%',
        evidence: {
          'yoyGrowth': yoyGrowth,
          'revenueYear': revenue.revenueYear,
          'revenueMonth': revenue.revenueMonth,
        },
      );
    }

    return null;
  }
}

/// Rule: High Dividend Yield
/// Triggers when dividend yield > 5%
class HighDividendYieldRule extends StockRule {
  const HighDividendYieldRule();

  @override
  String get id => 'high_dividend_yield';

  @override
  String get name => '高殖利率';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    final dividendYield = valuation.dividendYield ?? 0;

    if (dividendYield >= RuleParams.highDividendYieldThreshold * 100) {
      return TriggeredReason(
        type: ReasonType.highDividendYield,
        score: RuleScores.highDividendYield,
        description: '殖利率 ${dividendYield.toStringAsFixed(2)}%',
        evidence: {
          'dividendYield': dividendYield,
          'date': valuation.date.toIso8601String(),
        },
      );
    }

    return null;
  }
}

/// Rule: PE Undervalued
/// Triggers when PE < 10 (and > 0)
class PEUndervaluedRule extends StockRule {
  const PEUndervaluedRule();

  @override
  String get id => 'pe_undervalued';

  @override
  String get name => 'PE 低估';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    final pe = valuation.per ?? 0;

    // PE must be positive and below threshold
    if (pe > 0 && pe <= RuleParams.peUndervaluedThreshold) {
      return TriggeredReason(
        type: ReasonType.peUndervalued,
        score: RuleScores.peUndervalued,
        description: 'PE 僅 ${pe.toStringAsFixed(2)} 倍',
        evidence: {'pe': pe, 'date': valuation.date.toIso8601String()},
      );
    }

    return null;
  }
}

/// Rule: PE Overvalued
/// Triggers when PE > 50 (warning)
class PEOvervaluedRule extends StockRule {
  const PEOvervaluedRule();

  @override
  String get id => 'pe_overvalued';

  @override
  String get name => 'PE 偏高';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    final pe = valuation.per ?? 0;

    if (pe >= RuleParams.peOvervaluedThreshold) {
      return TriggeredReason(
        type: ReasonType.peOvervalued,
        score: RuleScores.peOvervalued,
        description: 'PE 高達 ${pe.toStringAsFixed(1)} 倍',
        evidence: {'pe': pe, 'date': valuation.date.toIso8601String()},
      );
    }

    return null;
  }
}

/// Rule: PBR Undervalued
/// Triggers when PBR < 1 (stock price below book value)
class PBRUndervaluedRule extends StockRule {
  const PBRUndervaluedRule();

  @override
  String get id => 'pbr_undervalued';

  @override
  String get name => '股價淨值比低於 1';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    final pbr = valuation.pbr ?? 0;

    if (pbr > 0 && pbr <= RuleParams.pbrUndervaluedThreshold) {
      return TriggeredReason(
        type: ReasonType.pbrUndervalued,
        score: RuleScores.pbrUndervalued,
        description: 'PBR 僅 ${pbr.toStringAsFixed(2)} 倍',
        evidence: {'pbr': pbr, 'date': valuation.date.toIso8601String()},
      );
    }

    return null;
  }
}
