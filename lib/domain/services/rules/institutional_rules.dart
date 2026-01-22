import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Phase 4: Institutional Streak Rules
// ==========================================

/// Rule: Institutional Buy Streak
/// Triggers when foreign investors have been net buyers for N consecutive days
class InstitutionalBuyStreakRule extends StockRule {
  const InstitutionalBuyStreakRule();

  @override
  String get id => 'institutional_buy_streak';

  @override
  String get name => '法人連買';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.institutional;
    if (history == null ||
        history.length < RuleParams.institutionalStreakDays) {
      return null;
    }

    // Check for consecutive buy days
    int streakDays = 0;
    double totalNet = 0;

    // Check from most recent backwards
    for (
      int i = history.length - 1;
      i >= 0 && i >= history.length - RuleParams.institutionalStreakDays;
      i--
    ) {
      final entry = history[i];
      final net = entry.foreignNet ?? 0;

      if (net > 0) {
        streakDays++;
        totalNet += net;
      } else {
        break; // Streak broken
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      return TriggeredReason(
        type: ReasonType.institutionalBuyStreak,
        score: RuleScores.institutionalBuyStreak,
        description: '外資連續買超 $streakDays 日',
        evidence: {
          'streakDays': streakDays,
          'totalNet': totalNet,
          'avgNet': totalNet / streakDays,
        },
      );
    }

    return null;
  }
}

/// Rule: Institutional Sell Streak
/// Triggers when foreign investors have been net sellers for N consecutive days
class InstitutionalSellStreakRule extends StockRule {
  const InstitutionalSellStreakRule();

  @override
  String get id => 'institutional_sell_streak';

  @override
  String get name => '法人連賣';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.institutional;
    if (history == null ||
        history.length < RuleParams.institutionalStreakDays) {
      return null;
    }

    // Check for consecutive sell days
    int streakDays = 0;
    double totalNet = 0;

    for (
      int i = history.length - 1;
      i >= 0 && i >= history.length - RuleParams.institutionalStreakDays;
      i--
    ) {
      final entry = history[i];
      final net = entry.foreignNet ?? 0;

      if (net < 0) {
        streakDays++;
        totalNet += net;
      } else {
        break;
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      return TriggeredReason(
        type: ReasonType.institutionalSellStreak,
        score: RuleScores.institutionalSellStreak,
        description: '外資連續賣超 $streakDays 日',
        evidence: {
          'streakDays': streakDays,
          'totalNet': totalNet,
          'avgNet': totalNet / streakDays,
        },
      );
    }

    return null;
  }
}
