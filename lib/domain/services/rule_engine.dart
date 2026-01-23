import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart';
import 'package:afterclose/domain/services/rules/divergence_rules.dart';
import 'package:afterclose/domain/services/rules/extended_market_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_scan_rules.dart';
import 'package:afterclose/domain/services/rules/indicator_rules.dart';
import 'package:afterclose/domain/services/rules/institutional_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:afterclose/domain/services/analysis_service.dart';

/// Rule Engine for stock analysis
///
/// Uses Strategy Pattern to apply a list of [StockRule]s to stock data.
class RuleEngine {
  /// Create RuleEngine with optional custom rules.
  /// If [customRules] is provided, only those rules will be used.
  /// Otherwise, the default rule set is loaded.
  RuleEngine({List<StockRule>? customRules}) {
    if (customRules != null) {
      _rules.addAll(customRules);
    } else {
      _rules.addAll(_defaultRules);
    }
  }

  /// Default rule set - Phase 1-6 rules
  static const List<StockRule> _defaultRules = [
    // Phase 1: Basic Rules
    WeakToStrongRule(),
    StrongToWeakRule(),
    BreakoutRule(),
    BreakdownRule(),
    VolumeSpikeRule(),
    PriceSpikeRule(),
    InstitutionalShiftRule(),
    NewsRule(),
    // Phase 2: Candlestick Pattern Rules
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
    // Phase 3: Technical Signal Rules
    Week52HighRule(),
    Week52LowRule(),
    MAAlignmentBullishRule(),
    MAAlignmentBearishRule(),
    RSIExtremeOverboughtRule(),
    RSIExtremeOversoldRule(),
    KDGoldenCrossRule(),
    KDDeathCrossRule(),
    // Phase 4: Institutional Streak Rules
    InstitutionalBuyStreakRule(),
    InstitutionalSellStreakRule(),
    // Phase 4: Extended Market Data Rules
    ForeignShareholdingIncreasingRule(),
    ForeignShareholdingDecreasingRule(),
    DayTradingHighRule(),
    DayTradingExtremeRule(),
    // NOTE: ConcentrationHighRule removed - requires paid API (股權分散表)
    // Phase 5: Price-Volume Divergence Rules
    PriceVolumeBullishDivergenceRule(),
    PriceVolumeBearishDivergenceRule(),
    HighVolumeBreakoutRule(),
    LowVolumeAccumulationRule(),
    // Phase 6: Fundamental Analysis Rules
    RevenueYoYSurgeRule(),
    RevenueYoYDeclineRule(),
    RevenueMomGrowthRule(),
    HighDividendYieldRule(),
    PEUndervaluedRule(),
    PEOvervaluedRule(),
    PBRUndervaluedRule(),
  ];

  final List<StockRule> _rules = [];

  /// Dynamically register a new rule
  void registerRule(StockRule rule) => _rules.add(rule);

  /// Dynamically unregister a rule by ID
  void unregisterRule(String ruleId) =>
      _rules.removeWhere((r) => r.id == ruleId);

  /// Run all rules on a stock and return triggered reasons
  List<TriggeredReason> evaluateStock({
    required List<DailyPriceEntry> priceHistory,
    required AnalysisContext context,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<NewsItemEntry>? recentNews,
    String? symbol,
    MonthlyRevenueEntry? latestRevenue,
    StockValuationEntry? latestValuation,
    List<MonthlyRevenueEntry>? revenueHistory,
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
    );

    final triggered = <TriggeredReason>[];

    for (final rule in _rules) {
      try {
        final reason = rule.evaluate(context, data);
        if (reason != null) {
          triggered.add(reason);
        }
      } catch (e, stackTrace) {
        // Log rule failure without crashing
        AppLogger.warning(
          'RuleEngine',
          'Rule ${rule.id} evaluation failed: $e',
          stackTrace,
        );
      }
    }

    // Sort by score descending
    triggered.sort((a, b) => b.score.compareTo(a.score));

    return triggered;
  }

  /// Calculate final score with bonuses, penalties, and caps
  int calculateScore(
    List<TriggeredReason> reasons, {
    bool wasRecentlyRecommended = false,
  }) {
    if (reasons.isEmpty) return 0;

    double score = 0.0;

    // 1. Base score from reasons
    for (final reason in reasons) {
      score += reason.score;
    }

    // 2. Bonuses for constructive combinations
    // Volume + Breakout = Stronger signal
    final hasVolume = reasons.any((r) => r.type == ReasonType.volumeSpike);
    final hasBreakout = reasons.any((r) => r.type == ReasonType.techBreakout);
    final hasReversal = reasons.any((r) => r.type == ReasonType.reversalW2S);
    final hasInstitutional = reasons.any(
      (r) => r.type == ReasonType.institutionalShift,
    );

    if (hasVolume && hasBreakout) score += 10;
    if (hasVolume && hasReversal) score += 10;
    if (hasInstitutional && (hasBreakout || hasReversal)) score += 15;

    // 3. Penalty for conflicting signals
    // E.g. Breakout (Bull) + Breakdown (Bear)?? Should be impossible but check anyway
    // Or W2S (Bull) + Institutional Strong Sell (Bear)
    // Simple conflict check: if mixed positive and negative scores?
    // For now, most scores are positive (importance).

    // 4. Cooldown penalty
    if (wasRecentlyRecommended) {
      score *= 0.5; // Reduce score by 50% if recently recommended
    }

    // 5. Cap score (using 100 as previously discussed, though tests expected 80/90,
    // let's stick to the logic - test might fail and we fix test)
    if (score > 100) score = 100;

    return score.round();
  }

  /// Get top reasons for display (deduplicated)
  List<TriggeredReason> getTopReasons(List<TriggeredReason> reasons) {
    if (reasons.isEmpty) return [];

    // Deduplicate by category/type priority
    // For now just take top 3 distinct types
    final distinct = <ReasonType>{};
    final result = <TriggeredReason>[];

    for (final r in reasons) {
      if (!distinct.contains(r.type)) {
        distinct.add(r.type);
        result.add(r);
        if (result.length >= 3) break;
      }
    }

    return result;
  }
}
