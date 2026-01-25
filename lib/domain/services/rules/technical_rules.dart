import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 反轉規則
// ==========================================

class WeakToStrongRule extends StockRule {
  const WeakToStrongRule();

  @override
  String get id => 'reversal_w2s';

  @override
  String get name => '弱轉強';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (context.reversalState == ReversalState.weakToStrong) {
      return TriggeredReason(
        type: ReasonType.reversalW2S,
        score: RuleScores.reversalW2S,
        description: '底部型態確立 / 突破區間整理',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
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
    if (context.reversalState == ReversalState.strongToWeak) {
      // 過濾條件：須跌破 MA20 確認趨勢反轉
      if (data.prices.length >= 20) {
        double sum = 0;
        int count = 0;
        for (
          int i = data.prices.length - 1;
          i >= data.prices.length - 20;
          i--
        ) {
          if (data.prices[i].close != null) {
            sum += data.prices[i].close!;
            count++;
          }
        }
        if (count == 20) {
          final ma20 = sum / count;
          final close = data.prices.last.close;
          if (close != null && close > ma20) {
            return null; // 仍在 MA20 之上，視為回檔而非反轉
          }
        }
      }

      return TriggeredReason(
        type: ReasonType.reversalS2W,
        score: RuleScores.reversalS2W,
        description: '頭部型態確立 / 跌破支撐 (破月線)',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
  }
}

// ==========================================
// 突破/跌破規則
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
      // 使用突破緩衝區（1%）
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
      // 使用跌破緩衝區（2%）
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
