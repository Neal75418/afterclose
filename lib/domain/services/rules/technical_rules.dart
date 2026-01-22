import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Reversal Rules
// ==========================================

class WeakToStrongRule extends StockRule {
  const WeakToStrongRule();

  @override
  String get id => 'reversal_w2s';

  @override
  String get name => '弱轉強';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // Only applies to DOWN or RANGE trends
    if (context.trendState == TrendState.up) return null;

    final result = _checkWeakToStrong(data.prices, context);
    if (result) {
      return TriggeredReason(
        type: ReasonType.reversalW2S,
        score: RuleScores.reversalW2S,
        description: '底部型態確立 / 突破區間整理',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
  }

  bool _checkWeakToStrong(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    if (prices.isEmpty) return false;
    final today = prices.last;
    final close = today.close;
    if (close == null) return false;

    // 1. Breakout above range top
    if (context.rangeTop != null) {
      final breakoutLevel = context.rangeTop! * (1 + RuleParams.breakoutBuffer);
      if (close > breakoutLevel) return true;
    }

    // 2. Higher low formation
    // Note: Reusing logic from current implementation, ideally this helper moves to a shared utility
    // For now, implementing simplified version or relying on AnalysisService
    return false; // Complex logic handled by AnalysisService.detectReversalState usually
    // TODO: The original code had specific _hasHigherLow logic inside RuleEngine or AnalysisService
    // We should rely on context.reversalState if possible, or duplicate the logic here if it's rule-specific
  }
}

class StrongToWeakRule extends StockRule {
  const StrongToWeakRule();

  @override
  String get id => 'reversal_s2w';

  @override
  String get name => '強轉弱';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (context.trendState == TrendState.down) return null;

    final result = _checkStrongToWeak(data.prices, context);
    if (result) {
      return TriggeredReason(
        type: ReasonType.reversalS2W,
        score: RuleScores.reversalS2W,
        description: '頭部型態確立 / 跌破支撐',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
  }

  bool _checkStrongToWeak(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    if (prices.isEmpty) return false;
    final today = prices.last;
    final close = today.close;
    if (close == null) return false;

    // 1. Breakdown below support
    if (context.supportLevel != null) {
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakdownBuffer);
      if (close < breakdownLevel) return true;
    }

    return false;
  }
}

// ==========================================
// Breakout/Breakdown Rules
// ==========================================

class BreakoutRule extends StockRule {
  const BreakoutRule();

  @override
  String get id => 'tech_breakout';

  @override
  String get name => '向上突破';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    if (context.resistanceLevel != null) {
      // Use breakoutBuffer (1%)
      final breakoutLevel =
          context.resistanceLevel! * (1 + RuleParams.breakoutBuffer);
      if (close > breakoutLevel) {
        return TriggeredReason(
          type: ReasonType.techBreakout,
          score: RuleScores.techBreakout,
          description: '突破關鍵壓力位',
          evidence: {
            'close': close,
            'resistance': context.resistanceLevel,
            'breakoutLevel': breakoutLevel,
          },
        );
      }
    }
    return null;
  }
}

class BreakdownRule extends StockRule {
  const BreakdownRule();

  @override
  String get id => 'tech_breakdown';

  @override
  String get name => '向下跌破';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    if (context.supportLevel != null) {
      // Use breakdownBuffer (2%)
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakdownBuffer);
      if (close < breakdownLevel) {
        return TriggeredReason(
          type: ReasonType.techBreakdown,
          score: RuleScores.techBreakdown,
          description: '跌破關鍵支撐位',
          evidence: {
            'close': close,
            'support': context.supportLevel,
            'breakdownLevel': breakdownLevel,
          },
        );
      }
    }
    return null;
  }
}
