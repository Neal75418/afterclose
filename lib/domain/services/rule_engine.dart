import 'dart:convert';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/pattern_service.dart';

/// Rule Engine for stock analysis
///
/// All rules are implemented as pure functions that take price/market data
/// and return triggered reasons with evidence.
class RuleEngine {
  const RuleEngine();

  /// Run all rules on a stock and return triggered reasons
  ///
  /// Returns list of [TriggeredReason] sorted by score descending
  List<TriggeredReason> evaluateStock({
    required List<DailyPriceEntry> priceHistory,
    required AnalysisContext context,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<NewsItemEntry>? recentNews,
  }) {
    if (priceHistory.length < RuleParams.swingWindow) {
      return []; // Not enough data
    }

    final reasons = <TriggeredReason>[];

    // R1 & R2: Reversal patterns (mutually exclusive)
    // A stock cannot be both reversing up AND reversing down simultaneously
    final r1 = checkWeakToStrong(priceHistory, context);
    final r2 = checkStrongToWeak(priceHistory, context);

    if (r1 != null && r2 != null) {
      // Both triggered - resolve conflict based on price action
      // This can happen when technical patterns overlap
      final today = priceHistory.last;
      final yesterday = priceHistory[priceHistory.length - 2];
      final todayClose = today.close ?? 0;
      final yesterdayClose = yesterday.close ?? 0;

      if (todayClose > yesterdayClose) {
        // Price went up - favor W2S (bullish reversal)
        reasons.add(r1);
      } else if (todayClose < yesterdayClose) {
        // Price went down - favor S2W (bearish reversal)
        reasons.add(r2);
      } else {
        // Flat day (todayClose == yesterdayClose) - add both signals
        // Direction is inconclusive, but both technical patterns were detected.
        // The score is not reduced here; scoring adjustment happens in calculateScore().
        reasons.add(r1);
        reasons.add(r2);
      }
    } else if (r1 != null) {
      reasons.add(r1);
    } else if (r2 != null) {
      reasons.add(r2);
    }

    // R3: TECH_BREAKOUT
    final r3 = checkBreakout(priceHistory, context);
    if (r3 != null) reasons.add(r3);

    // R4: TECH_BREAKDOWN
    final r4 = checkBreakdown(priceHistory, context);
    if (r4 != null) reasons.add(r4);

    // R5: VOLUME_SPIKE
    final r5 = checkVolumeSpike(priceHistory);
    if (r5 != null) reasons.add(r5);

    // R6: PRICE_SPIKE
    final r6 = checkPriceSpike(priceHistory);
    if (r6 != null) reasons.add(r6);

    // R7: INSTITUTIONAL_SHIFT (optional)
    if (institutionalHistory != null && institutionalHistory.isNotEmpty) {
      final r7 = checkInstitutionalShift(institutionalHistory);
      if (r7 != null) reasons.add(r7);
    }

    // R8: NEWS_RELATED (optional)
    if (recentNews != null && recentNews.isNotEmpty) {
      final r8 = checkNewsRelated(recentNews);
      if (r8 != null) reasons.add(r8);
    }

    // R9: KD_GOLDEN_CROSS (requires technical indicators)
    final r9 = checkKdGoldenCross(context);
    if (r9 != null) reasons.add(r9);

    // R10: KD_DEATH_CROSS (requires technical indicators)
    final r10 = checkKdDeathCross(context);
    if (r10 != null) reasons.add(r10);

    // R11/R12: INSTITUTIONAL_BUY/SELL_STREAK (optional)
    if (institutionalHistory != null && institutionalHistory.isNotEmpty) {
      final r11 = checkInstitutionalStreak(institutionalHistory);
      if (r11 != null) reasons.add(r11);
    }

    // R13+: CANDLESTICK_PATTERNS
    final patternReasons = checkCandlePatterns(priceHistory);
    reasons.addAll(patternReasons);

    // R14: 52-WEEK HIGH/LOW
    final r14 = checkWeek52HighLow(priceHistory);
    if (r14 != null) reasons.add(r14);

    // R15: MA ALIGNMENT
    final r15 = checkMaAlignment(priceHistory);
    if (r15 != null) reasons.add(r15);

    // R16: RSI EXTREME OVERBOUGHT/OVERSOLD
    final r16 = checkRsiExtreme(context);
    if (r16 != null) reasons.add(r16);

    // R17: FOREIGN_SHAREHOLDING_INCREASING/DECREASING
    final r17 = checkForeignShareholding(context);
    if (r17 != null) reasons.add(r17);

    // R18: DAY_TRADING_HIGH/EXTREME
    final r18 = checkDayTradingRatio(context);
    if (r18 != null) reasons.add(r18);

    // R19: CONCENTRATION_HIGH
    final r19 = checkConcentration(context);
    if (r19 != null) reasons.add(r19);

    // R20: PRICE_VOLUME_DIVERGENCE
    final r20 = checkPriceVolumeDivergence(priceHistory);
    if (r20 != null) reasons.add(r20);

    // R21: REVENUE SIGNALS (YoY surge/decline, MoM growth)
    final r21 = checkRevenueSignals(context);
    if (r21 != null) reasons.add(r21);

    // R22: VALUATION SIGNALS (dividend yield, PE, PBR)
    final r22Results = checkValuationSignals(context);
    reasons.addAll(r22Results);

    // Sort by score descending
    reasons.sort((a, b) => b.score.compareTo(a.score));

    return reasons;
  }

  /// Calculate final score with bonuses, penalties, and caps
  ///
  /// Score adjustments:
  /// 1. Base score from all triggered reasons
  /// 2. Bonuses for signal combinations (breakout+volume, reversal+volume, etc.)
  /// 3. Penalty for conflicting bull/bear signals (reduces clarity)
  /// 4. Cooldown penalty for recent recommendations
  /// 5. Maximum score cap to prevent score inflation
  int calculateScore(
    List<TriggeredReason> reasons, {
    bool wasRecentlyRecommended = false,
  }) {
    if (reasons.isEmpty) return 0;

    // Base score
    var score = reasons.fold<int>(0, (sum, r) => sum + r.score);

    // Bonus: BREAKOUT + VOLUME_SPIKE
    final hasBreakout = reasons.any((r) => r.type == ReasonType.techBreakout);
    final hasVolumeSpike = reasons.any((r) => r.type == ReasonType.volumeSpike);

    if (hasBreakout && hasVolumeSpike) {
      score += RuleScores.breakoutVolumeBonus;
    }

    // Bonus: REVERSAL_* + VOLUME_SPIKE
    final hasReversal = reasons.any(
      (r) =>
          r.type == ReasonType.reversalW2S || r.type == ReasonType.reversalS2W,
    );

    if (hasReversal && hasVolumeSpike) {
      score += RuleScores.reversalVolumeBonus;
    }

    // Bonus: Strong PATTERN + VOLUME_SPIKE
    // Candlestick patterns confirmed by volume are highly significant signals
    final hasStrongPattern = reasons.any((r) =>
        r.type == ReasonType.patternBullishEngulfing ||
        r.type == ReasonType.patternBearishEngulfing ||
        r.type == ReasonType.patternMorningStar ||
        r.type == ReasonType.patternEveningStar ||
        r.type == ReasonType.patternThreeWhiteSoldiers ||
        r.type == ReasonType.patternThreeBlackCrows);

    if (hasStrongPattern && hasVolumeSpike) {
      score += RuleScores.patternVolumeBonus;
    }

    // Penalty: Conflicting bull/bear signals reduce score clarity
    // When both bullish and bearish signals are present, reduce overall score
    final conflictPenalty = _calculateConflictPenalty(reasons);
    if (conflictPenalty > 0) {
      score = (score * (1 - conflictPenalty)).round();
    }

    // Cooldown penalty
    if (wasRecentlyRecommended) {
      score = (score * RuleParams.cooldownMultiplier).round();
    }

    // Apply maximum score cap to prevent score inflation
    if (score > RuleScores.maxScore) {
      score = RuleScores.maxScore;
    }

    return score;
  }

  /// Calculate conflict penalty for mixed bull/bear signals
  ///
  /// Returns a penalty multiplier (0.0 - 0.3) based on signal conflicts.
  /// Higher penalty when strong opposing signals cancel each other out.
  double _calculateConflictPenalty(List<TriggeredReason> reasons) {
    // Define bullish signal types
    const bullishTypes = {
      ReasonType.reversalW2S,
      ReasonType.techBreakout,
      ReasonType.kdGoldenCross,
      ReasonType.patternBullishEngulfing,
      ReasonType.patternHammer,
      ReasonType.patternGapUp,
      ReasonType.patternMorningStar,
      ReasonType.patternThreeWhiteSoldiers,
      ReasonType.week52High,
      ReasonType.maAlignmentBullish,
      ReasonType.institutionalBuyStreak,
      ReasonType.foreignShareholdingIncreasing,
      // Phase 5: Low volume accumulation is bullish (potential reversal)
      ReasonType.lowVolumeAccumulation,
      // Phase 6: Positive fundamental signals
      ReasonType.revenueYoySurge,
      ReasonType.revenueMomGrowth,
      ReasonType.highDividendYield,
      ReasonType.peUndervalued,
      ReasonType.pbrUndervalued,
    };

    // Define bearish signal types
    const bearishTypes = {
      ReasonType.reversalS2W,
      ReasonType.techBreakdown,
      ReasonType.kdDeathCross,
      ReasonType.patternBearishEngulfing,
      ReasonType.patternHangingMan,
      ReasonType.patternGapDown,
      ReasonType.patternEveningStar,
      ReasonType.patternThreeBlackCrows,
      ReasonType.week52Low,
      ReasonType.maAlignmentBearish,
      ReasonType.institutionalSellStreak,
      ReasonType.foreignShareholdingDecreasing,
      // Phase 5: Price-volume divergences are warning signals (bearish)
      ReasonType.priceVolumeBullishDivergence, // 價漲量縮 = warning
      ReasonType.priceVolumeBearishDivergence, // 價跌量增 = bearish
      ReasonType.highVolumeBreakout, // 高檔爆量 = potential distribution
      // Phase 6: Negative fundamental signals
      ReasonType.revenueYoyDecline,
      ReasonType.peOvervalued,
    };

    // Count bullish and bearish signals
    int bullishCount = 0;
    int bearishCount = 0;
    int bullishScore = 0;
    int bearishScore = 0;

    for (final reason in reasons) {
      if (bullishTypes.contains(reason.type)) {
        bullishCount++;
        bullishScore += reason.score;
      } else if (bearishTypes.contains(reason.type)) {
        bearishCount++;
        bearishScore += reason.score;
      }
    }

    // No conflict if only one direction or no directional signals
    if (bullishCount == 0 || bearishCount == 0) {
      return 0.0;
    }

    // Calculate conflict intensity based on score balance
    // More balanced scores = higher conflict penalty
    final totalDirectionalScore = bullishScore + bearishScore;
    if (totalDirectionalScore == 0) return 0.0;

    final scoreRatio = (bullishScore - bearishScore).abs() / totalDirectionalScore;
    // scoreRatio close to 0 = highly conflicted, close to 1 = one side dominates

    // Penalty: 30% when perfectly balanced, 0% when one side dominates
    // Formula: penalty = 0.3 * (1 - scoreRatio)
    return 0.3 * (1 - scoreRatio);
  }

  /// Get top reasons (max 2, deduplicated by category)
  List<TriggeredReason> getTopReasons(List<TriggeredReason> reasons) {
    if (reasons.isEmpty) return [];

    final result = <TriggeredReason>[];
    final usedCategories = <_ReasonCategory>{};

    for (final reason in reasons) {
      if (result.length >= RuleParams.maxReasonsPerStock) break;

      final category = _getCategory(reason.type);
      if (!usedCategories.contains(category)) {
        result.add(reason);
        usedCategories.add(category);
      }
    }

    return result;
  }

  // ==========================================
  // R1: REVERSAL_W2S (Weak to Strong) +35
  // ==========================================

  /// Check for weak-to-strong reversal pattern
  TriggeredReason? checkWeakToStrong(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    if (prices.length < RuleParams.rangeLookback) return null;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    // Check: Breakout above range top
    // Allow when in downtrend OR range (relaxed condition for more signals)
    if (context.rangeTop != null) {
      final breakoutLevel = context.rangeTop! * (1 + RuleParams.breakoutBuffer);
      if (todayClose > breakoutLevel &&
          (context.trendState == TrendState.down ||
              context.trendState == TrendState.range)) {
        return TriggeredReason(
          type: ReasonType.reversalW2S,
          score: RuleScores.reversalW2S,
          evidence: {
            'trigger': 'breakout_range_top',
            'range_top': context.rangeTop,
            'close': todayClose,
            'buffer': RuleParams.breakoutBuffer,
            'trend': context.trendState.code,
          },
          template: '弱轉強：突破盤整區上緣 ${context.rangeTop?.toStringAsFixed(2)}',
        );
      }
    }

    // Check: Downtrend structure broken (no new low + higher low)
    // Also check when in range with recent weakness
    if (context.trendState == TrendState.down ||
        context.trendState == TrendState.range) {
      final recentPrices = prices.reversed
          .take(RuleParams.swingWindow)
          .toList();
      final prevLow = _findSwingLow(
        prices.reversed
            .skip(RuleParams.swingWindow)
            .take(RuleParams.swingWindow)
            .toList(),
      );
      final recentLow = _findSwingLow(recentPrices);

      if (prevLow != null && recentLow != null && recentLow > prevLow) {
        return TriggeredReason(
          type: ReasonType.reversalW2S,
          score: RuleScores.reversalW2S,
          evidence: {
            'trigger': 'higher_low',
            'prev_low': prevLow,
            'recent_low': recentLow,
            'close': todayClose,
          },
          template: '弱轉強：跌勢結構被破壞，形成較高低點',
        );
      }
    }

    return null;
  }

  // ==========================================
  // R2: REVERSAL_S2W (Strong to Weak) +35
  // ==========================================

  /// Check for strong-to-weak reversal pattern
  TriggeredReason? checkStrongToWeak(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    if (prices.length < RuleParams.rangeLookback) return null;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    // Check: Breakdown below support
    // Allow when in uptrend OR range (relaxed condition for more signals)
    // Uses breakdownBuffer (looser than breakoutBuffer) for easier triggering
    if (context.supportLevel != null) {
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakdownBuffer);
      if (todayClose < breakdownLevel &&
          (context.trendState == TrendState.up ||
              context.trendState == TrendState.range)) {
        return TriggeredReason(
          type: ReasonType.reversalS2W,
          score: RuleScores.reversalS2W,
          evidence: {
            'trigger': 'breakdown_support',
            'support': context.supportLevel,
            'close': todayClose,
            'buffer': RuleParams.breakdownBuffer,
            'trend': context.trendState.code,
          },
          template: '強轉弱：跌破關鍵支撐 ${context.supportLevel?.toStringAsFixed(2)}',
        );
      }
    }

    // Check: Breakdown below range bottom
    if (context.rangeBottom != null) {
      final breakdownLevel =
          context.rangeBottom! * (1 - RuleParams.breakdownBuffer);
      if (todayClose < breakdownLevel &&
          context.trendState != TrendState.down) {
        return TriggeredReason(
          type: ReasonType.reversalS2W,
          score: RuleScores.reversalS2W,
          evidence: {
            'trigger': 'breakdown_range_bottom',
            'range_bottom': context.rangeBottom,
            'close': todayClose,
            'buffer': RuleParams.breakdownBuffer,
          },
          template: '強轉弱：跌破盤整區下緣 ${context.rangeBottom?.toStringAsFixed(2)}',
        );
      }
    }

    // Check: Significant lower-low pattern
    // Requires: today's close < yesterday's low by at least 1.5%
    // This filters out minor fluctuations
    if (context.trendState != TrendState.down) {
      final yesterday = prices[prices.length - 2];
      final yesterdayLow = yesterday.low;
      if (yesterdayLow != null && todayClose < yesterdayLow) {
        final dropPercent = (yesterdayLow - todayClose) / yesterdayLow;
        // Only trigger if drop is significant (>= 1.5%)
        if (dropPercent >= 0.015) {
          return TriggeredReason(
            type: ReasonType.reversalS2W,
            score: RuleScores.reversalS2W,
            evidence: {
              'trigger': 'significant_lower_low',
              'yesterday_low': yesterdayLow,
              'today_close': todayClose,
              'drop_percent': dropPercent,
            },
            template:
                '強轉弱：大幅跌破昨日低點 ${yesterdayLow.toStringAsFixed(2)}（跌${(dropPercent * 100).toStringAsFixed(1)}%）',
          );
        }
      }
    }

    return null;
  }

  // ==========================================
  // R3: TECH_BREAKOUT +25
  // ==========================================

  /// Check for technical breakout above resistance
  TriggeredReason? checkBreakout(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    if (context.resistanceLevel == null) return null;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    final breakoutLevel =
        context.resistanceLevel! * (1 + RuleParams.breakoutBuffer);

    if (todayClose > breakoutLevel) {
      return TriggeredReason(
        type: ReasonType.techBreakout,
        score: RuleScores.techBreakout,
        evidence: {
          'resistance': context.resistanceLevel,
          'close': todayClose,
          'buffer': RuleParams.breakoutBuffer,
        },
        template: '技術突破：收盤突破壓力 ${context.resistanceLevel?.toStringAsFixed(2)}',
      );
    }

    return null;
  }

  // ==========================================
  // R4: TECH_BREAKDOWN +25
  // ==========================================

  /// Check for technical breakdown below support
  TriggeredReason? checkBreakdown(
    List<DailyPriceEntry> prices,
    AnalysisContext context,
  ) {
    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    // Check: Breakdown below support level
    if (context.supportLevel != null) {
      // Uses breakdownBuffer (looser than breakoutBuffer) for easier triggering
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakdownBuffer);

      if (todayClose < breakdownLevel) {
        return TriggeredReason(
          type: ReasonType.techBreakdown,
          score: RuleScores.techBreakdown,
          evidence: {
            'support': context.supportLevel,
            'close': todayClose,
            'buffer': RuleParams.breakdownBuffer,
          },
          template: '技術跌破：收盤跌破支撐 ${context.supportLevel?.toStringAsFixed(2)}',
        );
      }
    }

    // Fallback: Check close significantly below recent 10-day swing low
    // Use 10 days (longer than S2W's implicit pattern) to avoid overlap
    // Requires at least 1% below the swing low for significance
    final swingLow10 = _findSwingLowN(prices, 10);
    if (swingLow10 != null && todayClose < swingLow10) {
      final breakPercent = (swingLow10 - todayClose) / swingLow10;
      if (breakPercent >= 0.01) {
        return TriggeredReason(
          type: ReasonType.techBreakdown,
          score: RuleScores.techBreakdown,
          evidence: {
            'swing_low_10d': swingLow10,
            'close': todayClose,
            'break_percent': breakPercent,
          },
          template:
              '技術跌破：跌破近10日低點 ${swingLow10.toStringAsFixed(2)}（破${(breakPercent * 100).toStringAsFixed(1)}%）',
        );
      }
    }

    return null;
  }

  /// Find swing low over N days (excluding today)
  double? _findSwingLowN(List<DailyPriceEntry> prices, int days) {
    if (prices.length < days + 1) return null;
    final recentPrices = prices.reversed.skip(1).take(days).toList();
    double? minLow;
    for (final price in recentPrices) {
      final low = price.low;
      if (low != null && (minLow == null || low < minLow)) {
        minLow = low;
      }
    }
    return minLow;
  }

  // ==========================================
  // R5: VOLUME_SPIKE +18
  // ==========================================

  /// Check for abnormal volume spike
  TriggeredReason? checkVolumeSpike(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.volMa + 1) return null;

    final today = prices.last;
    final todayVolume = today.volume;
    if (todayVolume == null || todayVolume <= 0) return null;

    // Calculate 20-day volume moving average (excluding today)
    final volumeHistory = prices.reversed
        .skip(1)
        .take(RuleParams.volMa)
        .map((p) => p.volume ?? 0)
        .toList();

    if (volumeHistory.isEmpty) return null;

    final volMa20 =
        volumeHistory.reduce((a, b) => a + b) / volumeHistory.length;
    if (volMa20 <= 0) return null;

    final volumeMult = todayVolume / volMa20;

    // Check volume multiplier threshold
    if (volumeMult < RuleParams.volumeSpikeMult) return null;

    // Additional filter: require meaningful price movement
    // Volume spikes without price action are less significant
    final todayClose = today.close;
    final todayOpen = today.open;
    if (todayClose == null || todayOpen == null || todayOpen <= 0) return null;

    final priceChange = (todayClose - todayOpen).abs() / todayOpen;
    if (priceChange < RuleParams.minPriceChangeForVolume) return null;

    final changeDirection = todayClose >= todayOpen ? '漲' : '跌';
    final changePercent = (priceChange * 100).toStringAsFixed(1);

    return TriggeredReason(
      type: ReasonType.volumeSpike,
      score: RuleScores.volumeSpike,
      evidence: {
        'vol': todayVolume,
        'vol_ma20': volMa20,
        'mult': volumeMult,
        'price_change': priceChange,
      },
      template:
          '放量$changeDirection$changePercent%：成交量 ${_formatVolume(todayVolume)}（${volumeMult.toStringAsFixed(1)}x 均量）',
    );
  }

  // ==========================================
  // R6: PRICE_SPIKE +15
  // ==========================================

  /// Check for abnormal price movement
  TriggeredReason? checkPriceSpike(List<DailyPriceEntry> prices) {
    if (prices.length < 2) return null;

    final today = prices.last;
    final yesterday = prices[prices.length - 2];

    final todayClose = today.close;
    final yesterdayClose = yesterday.close;

    if (todayClose == null || yesterdayClose == null || yesterdayClose == 0) {
      return null;
    }

    final pctChange = ((todayClose - yesterdayClose) / yesterdayClose) * 100;

    if (pctChange.abs() >= RuleParams.priceSpikePercent) {
      return TriggeredReason(
        type: ReasonType.priceSpike,
        score: RuleScores.priceSpike,
        evidence: {
          'pct': pctChange,
          'threshold': RuleParams.priceSpikePercent,
          'close': todayClose,
          'prev_close': yesterdayClose,
        },
        template:
            '價格異常：今日 ${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(2)}%'
            '（波動超過門檻 ${RuleParams.priceSpikePercent}%）',
      );
    }

    return null;
  }

  // ==========================================
  // R7: INSTITUTIONAL_SHIFT +12
  // ==========================================

  /// Check for institutional investor direction change
  ///
  /// Triggers when:
  /// - Direction reverses from buy to sell or sell to buy
  /// - Significant change from neutral to strong buy/sell (or vice versa)
  TriggeredReason? checkInstitutionalShift(
    List<DailyInstitutionalEntry> history,
  ) {
    if (history.length < 4) return null;

    // Get today's data
    final today = history.last;
    final todayNet =
        (today.foreignNet ?? 0) +
        (today.investmentTrustNet ?? 0) +
        (today.dealerNet ?? 0);

    // Calculate previous 3 days net
    final prev3Days = history.reversed.skip(1).take(3).toList();
    if (prev3Days.length < 3) return null;

    double prev3Net = 0;
    for (final entry in prev3Days) {
      prev3Net +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    // Use numeric direction for comparison: 1 = buy, -1 = sell, 0 = neutral
    int getDirection(double netValue) {
      if (netValue > 0) return 1;
      if (netValue < 0) return -1;
      return 0;
    }

    String getDirectionLabel(int dir) {
      return switch (dir) {
        1 => 'buy',
        -1 => 'sell',
        _ => 'neutral',
      };
    }

    final todayDir = getDirection(todayNet);
    final prevDir = getDirection(prev3Net);

    // Check for meaningful direction change:
    // 1. Direct reversal: buy ↔ sell
    // 2. Transition involving neutral: neutral → buy/sell OR buy/sell → neutral
    if (todayDir != prevDir && (todayDir != 0 || prevDir != 0)) {
      final todayLabel = getDirectionLabel(todayDir);
      final prevLabel = getDirectionLabel(prevDir);

      return TriggeredReason(
        type: ReasonType.institutionalShift,
        score: RuleScores.institutionalShift,
        evidence: {
          'foreign_net': today.foreignNet,
          'dir_prev3': prevLabel,
          'dir_today': todayLabel,
          'today_net': todayNet,
          'prev3_net': prev3Net,
        },
        template: '法人變化：方向轉換（$prevLabel → $todayLabel）',
      );
    }

    return null;
  }

  // ==========================================
  // R8: NEWS_RELATED +8
  // ==========================================

  /// Positive sentiment keywords (bullish signals)
  static const _positiveKeywords = [
    '突破',
    '創高',
    '創新高',
    '漲停',
    '獲利',
    '營收成長',
    '法說',
    '利多',
    '看好',
    '調升',
    '目標價',
    '買進',
    '強勢',
    '利好',
    '訂單',
    '擴產',
  ];

  /// Negative sentiment keywords (bearish signals)
  static const _negativeKeywords = [
    '跌停',
    '下跌',
    '虧損',
    '衰退',
    '違約',
    '警示',
    '利空',
    '調降',
    '看壞',
    '減產',
    '裁員',
    '營收下滑',
    '產能過剩',
    '需求疲軟',
  ];

  /// Check for recent news mentions with keyword filtering
  ///
  /// Uses cumulative sentiment scoring instead of first-match:
  /// - Counts all positive and negative keywords across all news
  /// - Returns the net sentiment (positive count - negative count)
  /// - Only triggers if there's a clear sentiment direction
  ///
  /// Returns null if news is generic or sentiment is neutral/mixed.
  TriggeredReason? checkNewsRelated(List<NewsItemEntry> news) {
    if (news.isEmpty) return null;

    // Cumulative sentiment scoring
    int positiveCount = 0;
    int negativeCount = 0;
    NewsItemEntry? strongestNews;
    String? strongestKeyword;
    int strongestMatchCount = 0;

    for (final item in news) {
      final title = item.title.toLowerCase();
      int itemPositive = 0;
      int itemNegative = 0;
      String? firstKeyword;

      // Count all positive keywords in this title
      for (final keyword in _positiveKeywords) {
        if (title.contains(keyword)) {
          itemPositive++;
          firstKeyword ??= keyword;
        }
      }

      // Count all negative keywords in this title
      for (final keyword in _negativeKeywords) {
        if (title.contains(keyword)) {
          itemNegative++;
          firstKeyword ??= keyword;
        }
      }

      positiveCount += itemPositive;
      negativeCount += itemNegative;

      // Track the news item with strongest signal (most keyword matches)
      final itemTotal = itemPositive + itemNegative;
      if (itemTotal > strongestMatchCount) {
        strongestMatchCount = itemTotal;
        strongestNews = item;
        strongestKeyword = firstKeyword;
      }
    }

    // No relevant keywords found in any news
    if (positiveCount == 0 && negativeCount == 0) return null;

    // Calculate net sentiment (require clear direction)
    final netSentiment = positiveCount - negativeCount;

    // Neutral/mixed sentiment - don't trigger
    if (netSentiment == 0) return null;

    final isPositive = netSentiment > 0;
    final sentiment = isPositive ? '利多' : '利空';

    // Use the strongest news item for display
    final displayNews = strongestNews ?? news.first;

    return TriggeredReason(
      type: ReasonType.newsRelated,
      score: RuleScores.newsRelated,
      evidence: {
        'source': displayNews.source,
        'title': displayNews.title,
        'url': displayNews.url,
        'published_at': displayNews.publishedAt.toIso8601String(),
        'keyword': strongestKeyword ?? '',
        'sentiment': sentiment,
        'positive_count': positiveCount,
        'negative_count': negativeCount,
        'net_sentiment': netSentiment,
      },
      template: '新聞$sentiment：${displayNews.source} - ${displayNews.title}',
    );
  }

  // ==========================================
  // Helper Methods
  // ==========================================

  /// Find swing low in price history
  double? _findSwingLow(List<DailyPriceEntry> prices) {
    if (prices.isEmpty) return null;

    double? minLow;
    for (final price in prices) {
      final low = price.low;
      if (low != null && (minLow == null || low < minLow)) {
        minLow = low;
      }
    }
    return minLow;
  }

  /// Format volume for display
  String _formatVolume(double volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(2)}億';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(0)}萬';
    }
    return volume.toStringAsFixed(0);
  }

  /// Get reason category for deduplication
  _ReasonCategory _getCategory(ReasonType type) {
    return switch (type) {
      ReasonType.reversalW2S ||
      ReasonType.reversalS2W =>
        _ReasonCategory.reversal,
      ReasonType.techBreakout ||
      ReasonType.techBreakdown =>
        _ReasonCategory.technical,
      ReasonType.volumeSpike => _ReasonCategory.volume,
      ReasonType.priceSpike => _ReasonCategory.price,
      ReasonType.institutionalShift ||
      ReasonType.institutionalBuyStreak ||
      ReasonType.institutionalSellStreak =>
        _ReasonCategory.institutional,
      ReasonType.newsRelated => _ReasonCategory.news,
      ReasonType.kdGoldenCross ||
      ReasonType.kdDeathCross =>
        _ReasonCategory.kdSignal,
      // Candlestick patterns
      ReasonType.patternDoji ||
      ReasonType.patternBullishEngulfing ||
      ReasonType.patternBearishEngulfing ||
      ReasonType.patternHammer ||
      ReasonType.patternHangingMan ||
      ReasonType.patternGapUp ||
      ReasonType.patternGapDown ||
      ReasonType.patternMorningStar ||
      ReasonType.patternEveningStar ||
      ReasonType.patternThreeWhiteSoldiers ||
      ReasonType.patternThreeBlackCrows =>
        _ReasonCategory.pattern,
      // Phase 3 signals
      ReasonType.week52High ||
      ReasonType.week52Low =>
        _ReasonCategory.week52,
      ReasonType.maAlignmentBullish ||
      ReasonType.maAlignmentBearish =>
        _ReasonCategory.maAlignment,
      ReasonType.rsiExtremeOverbought ||
      ReasonType.rsiExtremeOversold =>
        _ReasonCategory.rsiExtreme,
      // Phase 4 signals
      ReasonType.foreignShareholdingIncreasing ||
      ReasonType.foreignShareholdingDecreasing =>
        _ReasonCategory.foreignShareholding,
      ReasonType.dayTradingHigh ||
      ReasonType.dayTradingExtreme =>
        _ReasonCategory.dayTrading,
      ReasonType.concentrationHigh => _ReasonCategory.concentration,
      // Phase 5: Price-volume divergence
      ReasonType.priceVolumeBullishDivergence ||
      ReasonType.priceVolumeBearishDivergence ||
      ReasonType.highVolumeBreakout ||
      ReasonType.lowVolumeAccumulation =>
        _ReasonCategory.priceVolumeDivergence,
      // Phase 6: Fundamental signals
      ReasonType.revenueYoySurge ||
      ReasonType.revenueYoyDecline ||
      ReasonType.revenueMomGrowth =>
        _ReasonCategory.revenue,
      ReasonType.highDividendYield ||
      ReasonType.peUndervalued ||
      ReasonType.peOvervalued ||
      ReasonType.pbrUndervalued =>
        _ReasonCategory.valuation,
    };
  }

  // ==========================================
  // R9: KD_GOLDEN_CROSS +18
  // ==========================================

  /// Check for KD golden cross (bullish signal)
  TriggeredReason? checkKdGoldenCross(AnalysisContext context) {
    final indicators = context.technicalIndicators;
    if (indicators == null) return null;

    if (indicators.isKdGoldenCross) {
      // Check if cross happened FROM oversold zone (using prevKdK, not current)
      // This is more meaningful - cross from low zone is stronger signal
      final isFromOversoldZone = indicators.prevKdK != null &&
          indicators.prevKdK! < RuleParams.kdOversold;

      return TriggeredReason(
        type: ReasonType.kdGoldenCross,
        score: RuleScores.kdGoldenCross,
        evidence: {
          'k': indicators.kdK,
          'd': indicators.kdD,
          'prev_k': indicators.prevKdK,
          'prev_d': indicators.prevKdD,
          'from_oversold_zone': isFromOversoldZone,
        },
        template: isFromOversoldZone
            ? 'KD黃金交叉：低檔翻揚（K=${indicators.prevKdK?.toStringAsFixed(0)}→${indicators.kdK?.toStringAsFixed(0)}）'
            : 'KD黃金交叉：K=${indicators.kdK?.toStringAsFixed(0)}，D=${indicators.kdD?.toStringAsFixed(0)}',
      );
    }

    return null;
  }

  // ==========================================
  // R10: KD_DEATH_CROSS +18
  // ==========================================

  /// Check for KD death cross (bearish signal)
  TriggeredReason? checkKdDeathCross(AnalysisContext context) {
    final indicators = context.technicalIndicators;
    if (indicators == null) return null;

    if (indicators.isKdDeathCross) {
      // Check if cross happened FROM overbought zone (using prevKdK, not current)
      // This is more meaningful - cross from high zone is stronger bearish signal
      final isFromOverboughtZone = indicators.prevKdK != null &&
          indicators.prevKdK! > RuleParams.kdOverbought;

      return TriggeredReason(
        type: ReasonType.kdDeathCross,
        score: RuleScores.kdDeathCross,
        evidence: {
          'k': indicators.kdK,
          'd': indicators.kdD,
          'prev_k': indicators.prevKdK,
          'prev_d': indicators.prevKdD,
          'from_overbought_zone': isFromOverboughtZone,
        },
        template: isFromOverboughtZone
            ? 'KD死亡交叉：高檔反轉（K=${indicators.prevKdK?.toStringAsFixed(0)}→${indicators.kdK?.toStringAsFixed(0)}）'
            : 'KD死亡交叉：K=${indicators.kdK?.toStringAsFixed(0)}，D=${indicators.kdD?.toStringAsFixed(0)}',
      );
    }

    return null;
  }

  // ==========================================
  // R11: INSTITUTIONAL_BUY_STREAK +20
  // R12: INSTITUTIONAL_SELL_STREAK +20
  // ==========================================

  /// Check for institutional consecutive buy/sell streak
  ///
  /// Note: history is expected in chronological order (oldest first).
  /// Uses .reversed to process from most recent day.
  TriggeredReason? checkInstitutionalStreak(
    List<DailyInstitutionalEntry> history,
  ) {
    if (history.length < RuleParams.institutionalStreakDays) return null;

    int buyStreak = 0;
    int sellStreak = 0;
    double totalNet = 0; // Accumulate total net during streak

    // Count consecutive days from most recent
    for (final day in history.reversed) {
      final net = (day.foreignNet ?? 0) +
          (day.investmentTrustNet ?? 0) +
          (day.dealerNet ?? 0);

      if (net > 0) {
        if (sellStreak > 0) break; // Streak broken
        buyStreak++;
        totalNet += net;
      } else if (net < 0) {
        if (buyStreak > 0) break; // Streak broken
        sellStreak++;
        totalNet += net;
      } else {
        break; // Neutral day breaks the streak
      }
    }

    if (buyStreak >= RuleParams.institutionalStreakDays) {
      return TriggeredReason(
        type: ReasonType.institutionalBuyStreak,
        score: RuleScores.institutionalBuyStreak,
        evidence: {
          'streak_days': buyStreak,
          'direction': 'BUY',
          'total_net': totalNet,
        },
        template: '法人連續買超$buyStreak天（累計${_formatAmount(totalNet)}）',
      );
    }

    if (sellStreak >= RuleParams.institutionalStreakDays) {
      return TriggeredReason(
        type: ReasonType.institutionalSellStreak,
        score: RuleScores.institutionalSellStreak,
        evidence: {
          'streak_days': sellStreak,
          'direction': 'SELL',
          'total_net': totalNet,
        },
        template: '法人連續賣超$sellStreak天（累計${_formatAmount(totalNet.abs())}）',
      );
    }

    return null;
  }

  /// Format amount for display (張 or 萬張)
  String _formatAmount(double amount) {
    final absAmount = amount.abs();
    if (absAmount >= 10000) {
      return '${(absAmount / 10000).toStringAsFixed(1)}萬張';
    }
    return '${absAmount.toStringAsFixed(0)}張';
  }

  // ==========================================
  // R13+: CANDLESTICK PATTERNS
  // ==========================================

  /// Pattern service instance
  static final _patternService = PatternService();

  /// Check for candlestick patterns and convert to triggered reasons
  ///
  /// Returns the most significant pattern found (highest confidence).
  /// Only returns one pattern to avoid signal overload.
  List<TriggeredReason> checkCandlePatterns(List<DailyPriceEntry> priceHistory) {
    if (priceHistory.length < 3) return [];

    final patterns = _patternService.detectPatterns(priceHistory);
    if (patterns.isEmpty) return [];

    // Sort by confidence descending
    patterns.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Take top 2 patterns (if they exist and are different categories)
    final results = <TriggeredReason>[];
    var hasBullish = false;
    var hasBearish = false;

    for (final pattern in patterns) {
      if (results.length >= 2) break;

      final isBullish = _isBullishPattern(pattern.type);
      final isBearish = _isBearishPattern(pattern.type);

      // Skip if same direction already added
      if (isBullish && hasBullish) continue;
      if (isBearish && hasBearish) continue;

      final reason = _patternToReason(pattern);
      if (reason != null) {
        results.add(reason);
        if (isBullish) hasBullish = true;
        if (isBearish) hasBearish = true;
      }
    }

    return results;
  }

  /// Check if pattern is bullish
  bool _isBullishPattern(CandlePatternType type) {
    return switch (type) {
      CandlePatternType.bullishEngulfing ||
      CandlePatternType.hammer ||
      CandlePatternType.gapUp ||
      CandlePatternType.morningStar ||
      CandlePatternType.threeWhiteSoldiers =>
        true,
      _ => false,
    };
  }

  /// Check if pattern is bearish
  bool _isBearishPattern(CandlePatternType type) {
    return switch (type) {
      CandlePatternType.bearishEngulfing ||
      CandlePatternType.hangingMan ||
      CandlePatternType.gapDown ||
      CandlePatternType.eveningStar ||
      CandlePatternType.threeBlackCrows =>
        true,
      _ => false,
    };
  }

  // ==========================================
  // R14: WEEK_52_HIGH/LOW +28
  // ==========================================

  /// Check for 52-week high or low
  TriggeredReason? checkWeek52HighLow(List<DailyPriceEntry> priceHistory) {
    if (priceHistory.length < RuleParams.week52Days) return null;

    final today = priceHistory.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    // Get 52-week data (excluding today)
    final week52Data = priceHistory.reversed
        .skip(1)
        .take(RuleParams.week52Days)
        .toList();

    if (week52Data.isEmpty) return null;

    // Find 52-week high and low
    double? week52High;
    double? week52Low;

    for (final price in week52Data) {
      final high = price.high;
      final low = price.low;
      if (high != null && (week52High == null || high > week52High)) {
        week52High = high;
      }
      if (low != null && (week52Low == null || low < week52Low)) {
        week52Low = low;
      }
    }

    if (week52High == null || week52Low == null) return null;

    // Check if today hit new 52-week high
    final todayHigh = today.high ?? todayClose;
    if (todayHigh >= week52High) {
      return TriggeredReason(
        type: ReasonType.week52High,
        score: RuleScores.week52High,
        evidence: {
          'today_high': todayHigh,
          'week52_high': week52High,
          'close': todayClose,
        },
        template: '創52週新高：今日高點 ${todayHigh.toStringAsFixed(2)} 突破前高 ${week52High.toStringAsFixed(2)}',
      );
    }

    // Check if today hit new 52-week low
    final todayLow = today.low ?? todayClose;
    if (todayLow <= week52Low) {
      return TriggeredReason(
        type: ReasonType.week52Low,
        score: RuleScores.week52Low,
        evidence: {
          'today_low': todayLow,
          'week52_low': week52Low,
          'close': todayClose,
        },
        template: '創52週新低：今日低點 ${todayLow.toStringAsFixed(2)} 跌破前低 ${week52Low.toStringAsFixed(2)}',
      );
    }

    // Check if near 52-week high (within threshold)
    final distanceToHigh = (week52High - todayClose) / week52High;
    if (distanceToHigh <= RuleParams.week52NearThreshold && distanceToHigh > 0) {
      return TriggeredReason(
        type: ReasonType.week52High,
        score: (RuleScores.week52High * 0.7).round(), // Reduced score for "near"
        evidence: {
          'today_close': todayClose,
          'week52_high': week52High,
          'distance_pct': distanceToHigh,
        },
        template: '接近52週新高：距離 ${(distanceToHigh * 100).toStringAsFixed(1)}%（${week52High.toStringAsFixed(2)}）',
      );
    }

    // Check if near 52-week low (within threshold)
    final distanceToLow = (todayClose - week52Low) / week52Low;
    if (distanceToLow <= RuleParams.week52NearThreshold && distanceToLow > 0) {
      return TriggeredReason(
        type: ReasonType.week52Low,
        score: (RuleScores.week52Low * 0.7).round(), // Reduced score for "near"
        evidence: {
          'today_close': todayClose,
          'week52_low': week52Low,
          'distance_pct': distanceToLow,
        },
        template: '接近52週新低：距離 ${(distanceToLow * 100).toStringAsFixed(1)}%（${week52Low.toStringAsFixed(2)}）',
      );
    }

    return null;
  }

  // ==========================================
  // R15: MA_ALIGNMENT_BULLISH/BEARISH +22
  // ==========================================

  /// Check for moving average alignment (bullish or bearish)
  TriggeredReason? checkMaAlignment(List<DailyPriceEntry> priceHistory) {
    // Need at least 60 days for MA60
    if (priceHistory.length < 60) return null;

    // Calculate MAs
    final closes = priceHistory.map((p) => p.close).whereType<double>().toList();
    if (closes.length < 60) return null;

    final ma5 = _calculateSma(closes, 5);
    final ma10 = _calculateSma(closes, 10);
    final ma20 = _calculateSma(closes, 20);
    final ma60 = _calculateSma(closes, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // Guard against division by zero (extremely unlikely but defensive)
    if (ma5 <= 0 || ma10 <= 0 || ma20 <= 0 || ma60 <= 0) {
      return null;
    }

    // Check for bullish alignment: 5 > 10 > 20 > 60
    // Also require minimum separation between all adjacent MAs
    final isBullish = ma5 > ma10 &&
        ma10 > ma20 &&
        ma20 > ma60 &&
        (ma5 - ma10) / ma10 >= RuleParams.maMinSeparation &&
        (ma10 - ma20) / ma20 >= RuleParams.maMinSeparation &&
        (ma20 - ma60) / ma60 >= RuleParams.maMinSeparation;

    if (isBullish) {
      return TriggeredReason(
        type: ReasonType.maAlignmentBullish,
        score: RuleScores.maAlignmentBullish,
        evidence: {
          'ma5': ma5,
          'ma10': ma10,
          'ma20': ma20,
          'ma60': ma60,
          'alignment': 'bullish',
        },
        template: '多頭排列：MA5 > MA10 > MA20 > MA60',
      );
    }

    // Check for bearish alignment: 5 < 10 < 20 < 60
    // Also require minimum separation between all adjacent MAs
    final isBearish = ma5 < ma10 &&
        ma10 < ma20 &&
        ma20 < ma60 &&
        (ma10 - ma5) / ma5 >= RuleParams.maMinSeparation &&
        (ma20 - ma10) / ma10 >= RuleParams.maMinSeparation &&
        (ma60 - ma20) / ma20 >= RuleParams.maMinSeparation;

    if (isBearish) {
      return TriggeredReason(
        type: ReasonType.maAlignmentBearish,
        score: RuleScores.maAlignmentBearish,
        evidence: {
          'ma5': ma5,
          'ma10': ma10,
          'ma20': ma20,
          'ma60': ma60,
          'alignment': 'bearish',
        },
        template: '空頭排列：MA5 < MA10 < MA20 < MA60',
      );
    }

    return null;
  }

  /// Calculate Simple Moving Average
  double? _calculateSma(List<double> values, int period) {
    if (values.length < period) return null;
    final subset = values.sublist(values.length - period);
    return subset.reduce((a, b) => a + b) / period;
  }

  // ==========================================
  // R16: RSI_EXTREME_OVERBOUGHT/OVERSOLD +15
  // ==========================================

  /// Check for RSI extreme overbought or oversold conditions
  TriggeredReason? checkRsiExtreme(AnalysisContext context) {
    final indicators = context.technicalIndicators;
    if (indicators == null || indicators.rsi == null) return null;

    final rsi = indicators.rsi!;

    // Check for extreme overbought (RSI >= 80)
    if (rsi >= RuleParams.rsiExtremeOverbought) {
      return TriggeredReason(
        type: ReasonType.rsiExtremeOverbought,
        score: RuleScores.rsiExtremeOverboughtSignal,
        evidence: {
          'rsi': rsi,
          'threshold': RuleParams.rsiExtremeOverbought,
        },
        template: 'RSI極度超買：${rsi.toStringAsFixed(1)}（≥${RuleParams.rsiExtremeOverbought.toInt()}警戒）',
      );
    }

    // Check for extreme oversold (RSI <= 20)
    if (rsi <= RuleParams.rsiExtremeOversold) {
      return TriggeredReason(
        type: ReasonType.rsiExtremeOversold,
        score: RuleScores.rsiExtremeOversoldSignal,
        evidence: {
          'rsi': rsi,
          'threshold': RuleParams.rsiExtremeOversold,
        },
        template: 'RSI極度超賣：${rsi.toStringAsFixed(1)}（≤${RuleParams.rsiExtremeOversold.toInt()}反彈機會）',
      );
    }

    return null;
  }

  // ==========================================
  // R17: FOREIGN_SHAREHOLDING +18
  // ==========================================

  /// Check for foreign shareholding changes
  TriggeredReason? checkForeignShareholding(AnalysisContext context) {
    final marketData = context.marketData;
    if (marketData == null || marketData.foreignSharesRatioChange == null) {
      return null;
    }

    final change = marketData.foreignSharesRatioChange!;
    final ratio = marketData.foreignSharesRatio;

    // Check for significant increase
    if (change >= RuleParams.foreignShareholdingIncreaseThreshold) {
      return TriggeredReason(
        type: ReasonType.foreignShareholdingIncreasing,
        score: RuleScores.foreignShareholdingIncreasing,
        evidence: {
          'ratio': ratio,
          'change': change,
          'threshold': RuleParams.foreignShareholdingIncreaseThreshold,
          'days': RuleParams.foreignShareholdingLookbackDays,
        },
        template: '外資持股增加：${RuleParams.foreignShareholdingLookbackDays}日增加 ${change.toStringAsFixed(2)}%'
            '${ratio != null ? '（持股 ${ratio.toStringAsFixed(1)}%）' : ''}',
      );
    }

    // Check for significant decrease
    if (change <= -RuleParams.foreignShareholdingIncreaseThreshold) {
      return TriggeredReason(
        type: ReasonType.foreignShareholdingDecreasing,
        score: RuleScores.foreignShareholdingDecreasing,
        evidence: {
          'ratio': ratio,
          'change': change,
          'threshold': RuleParams.foreignShareholdingIncreaseThreshold,
          'days': RuleParams.foreignShareholdingLookbackDays,
        },
        template: '外資持股減少：${RuleParams.foreignShareholdingLookbackDays}日減少 ${change.abs().toStringAsFixed(2)}%'
            '${ratio != null ? '（持股 ${ratio.toStringAsFixed(1)}%）' : ''}',
      );
    }

    return null;
  }

  // ==========================================
  // R18: DAY_TRADING_HIGH/EXTREME +12/+15
  // ==========================================

  /// Check for high day trading ratio
  TriggeredReason? checkDayTradingRatio(AnalysisContext context) {
    final marketData = context.marketData;
    if (marketData == null || marketData.dayTradingRatio == null) {
      return null;
    }

    final ratio = marketData.dayTradingRatio!;

    // Check for extreme day trading (higher threshold, higher score)
    if (ratio >= RuleParams.dayTradingExtremeThreshold) {
      return TriggeredReason(
        type: ReasonType.dayTradingExtreme,
        score: RuleScores.dayTradingExtreme,
        evidence: {
          'ratio': ratio,
          'threshold': RuleParams.dayTradingExtremeThreshold,
        },
        template: '極高當沖比例：${ratio.toStringAsFixed(1)}%（≥${RuleParams.dayTradingExtremeThreshold.toInt()}%警戒）',
      );
    }

    // Check for high day trading
    if (ratio >= RuleParams.dayTradingHighThreshold) {
      return TriggeredReason(
        type: ReasonType.dayTradingHigh,
        score: RuleScores.dayTradingHigh,
        evidence: {
          'ratio': ratio,
          'threshold': RuleParams.dayTradingHighThreshold,
        },
        template: '高當沖比例：${ratio.toStringAsFixed(1)}%（短線熱門）',
      );
    }

    return null;
  }

  // ==========================================
  // R19: CONCENTRATION_HIGH +16
  // ==========================================

  /// Check for high concentration ratio (large holder dominance)
  TriggeredReason? checkConcentration(AnalysisContext context) {
    final marketData = context.marketData;
    if (marketData == null || marketData.concentrationRatio == null) {
      return null;
    }

    final ratio = marketData.concentrationRatio!;

    if (ratio >= RuleParams.concentrationHighThreshold) {
      return TriggeredReason(
        type: ReasonType.concentrationHigh,
        score: RuleScores.concentrationHigh,
        evidence: {
          'ratio': ratio,
          'threshold': RuleParams.concentrationHighThreshold,
        },
        template: '籌碼集中：大戶持股 ${ratio.toStringAsFixed(1)}%（400張以上）',
      );
    }

    return null;
  }

  // ==========================================
  // R20: PRICE_VOLUME_DIVERGENCE
  // ==========================================

  /// Analysis service for price-volume calculations
  static final _analysisService = AnalysisService();

  /// Check for price-volume divergence patterns
  ///
  /// Detects:
  /// - Bullish divergence: price up + volume down (warning signal)
  /// - Bearish divergence: price down + volume up (panic signal)
  /// - High volume at high: potential distribution
  /// - Low volume at low: potential accumulation
  TriggeredReason? checkPriceVolumeDivergence(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.priceVolumeLookbackDays + RuleParams.rangeLookback) {
      return null;
    }

    final analysis = _analysisService.analyzePriceVolume(prices);

    return switch (analysis.state) {
      PriceVolumeState.bullishDivergence => TriggeredReason(
          type: ReasonType.priceVolumeBullishDivergence,
          score: RuleScores.priceVolumeBullishDivergence,
          evidence: {
            'price_change': analysis.priceChangePercent,
            'volume_change': analysis.volumeChangePercent,
            'state': 'bullish_divergence',
          },
          template:
              '價漲量縮：價格上漲 ${analysis.priceChangePercent?.toStringAsFixed(1)}%，'
              '但成交量減少 ${analysis.volumeChangePercent?.abs().toStringAsFixed(0)}%（上漲動能不足）',
        ),
      PriceVolumeState.bearishDivergence => TriggeredReason(
          type: ReasonType.priceVolumeBearishDivergence,
          score: RuleScores.priceVolumeBearishDivergence,
          evidence: {
            'price_change': analysis.priceChangePercent,
            'volume_change': analysis.volumeChangePercent,
            'state': 'bearish_divergence',
          },
          template:
              '價跌量增：價格下跌 ${analysis.priceChangePercent?.abs().toStringAsFixed(1)}%，'
              '成交量增加 ${analysis.volumeChangePercent?.toStringAsFixed(0)}%（恐慌賣壓）',
        ),
      PriceVolumeState.highVolumeAtHigh => TriggeredReason(
          type: ReasonType.highVolumeBreakout,
          score: RuleScores.highVolumeBreakout,
          evidence: {
            'price_position': analysis.pricePosition,
            'volume_change': analysis.volumeChangePercent,
            'state': 'high_volume_at_high',
          },
          template:
              '高檔爆量：股價處於相對高位（${((analysis.pricePosition ?? 0) * 100).toStringAsFixed(0)}%），'
              '成交量大增 ${analysis.volumeChangePercent?.toStringAsFixed(0)}%（關注出貨風險）',
        ),
      PriceVolumeState.lowVolumeAtLow => TriggeredReason(
          type: ReasonType.lowVolumeAccumulation,
          score: RuleScores.lowVolumeAccumulation,
          evidence: {
            'price_position': analysis.pricePosition,
            'volume_change': analysis.volumeChangePercent,
            'state': 'low_volume_at_low',
          },
          template:
              '低檔吸籌：股價處於相對低位（${((analysis.pricePosition ?? 0) * 100).toStringAsFixed(0)}%），'
              '成交量萎縮 ${analysis.volumeChangePercent?.abs().toStringAsFixed(0)}%（可能有主力吸籌）',
        ),
      _ => null, // neutral or healthyUptrend - no signal
    };
  }

  // ==========================================
  // R21: REVENUE SIGNALS
  // ==========================================

  /// Check for revenue-related signals
  ///
  /// Detects:
  /// - YoY surge: Revenue YoY growth > 30%
  /// - YoY decline: Revenue YoY decline > 20%
  /// - MoM consecutive growth: MoM positive for 2+ consecutive months
  TriggeredReason? checkRevenueSignals(AnalysisContext context) {
    final fundamentalData = context.fundamentalData;
    if (fundamentalData == null) return null;

    // Check YoY surge first (highest priority)
    final yoyGrowth = fundamentalData.revenueYoyGrowth;
    if (yoyGrowth != null && yoyGrowth >= RuleParams.revenueYoySurgeThreshold) {
      return TriggeredReason(
        type: ReasonType.revenueYoySurge,
        score: RuleScores.revenueYoySurge,
        evidence: {
          'yoy_growth': yoyGrowth,
          'threshold': RuleParams.revenueYoySurgeThreshold,
        },
        template: '營收年增暴增：YoY +${yoyGrowth.toStringAsFixed(1)}%（超過${RuleParams.revenueYoySurgeThreshold.toInt()}%）',
      );
    }

    // Check YoY decline
    if (yoyGrowth != null && yoyGrowth <= -RuleParams.revenueYoyDeclineThreshold) {
      return TriggeredReason(
        type: ReasonType.revenueYoyDecline,
        score: RuleScores.revenueYoyDecline,
        evidence: {
          'yoy_growth': yoyGrowth,
          'threshold': RuleParams.revenueYoyDeclineThreshold,
        },
        template: '營收年減衰退：YoY ${yoyGrowth.toStringAsFixed(1)}%（衰退超過${RuleParams.revenueYoyDeclineThreshold.toInt()}%）',
      );
    }

    // Check MoM consecutive growth
    final momGrowth = fundamentalData.revenueMomGrowth;
    final consecutiveMonths = fundamentalData.revenueMomConsecutiveGrowthMonths;
    if (momGrowth != null &&
        momGrowth >= RuleParams.revenueMomGrowthThreshold &&
        consecutiveMonths != null &&
        consecutiveMonths >= RuleParams.revenueMomConsecutiveMonths) {
      return TriggeredReason(
        type: ReasonType.revenueMomGrowth,
        score: RuleScores.revenueMomGrowth,
        evidence: {
          'mom_growth': momGrowth,
          'consecutive_months': consecutiveMonths,
        },
        template: '營收月增持續：連續$consecutiveMonths個月成長，本月 +${momGrowth.toStringAsFixed(1)}%',
      );
    }

    return null;
  }

  // ==========================================
  // R22: VALUATION SIGNALS
  // ==========================================

  /// Check for valuation-related signals
  ///
  /// Detects:
  /// - High dividend yield: Yield > 5%
  /// - PE undervalued: PE < 10 and > 0
  /// - PE overvalued: PE > 50
  /// - PBR undervalued: PBR < 1 (trading below book value)
  ///
  /// Returns multiple signals (can have both high yield AND low PE)
  List<TriggeredReason> checkValuationSignals(AnalysisContext context) {
    final fundamentalData = context.fundamentalData;
    if (fundamentalData == null) return [];

    final results = <TriggeredReason>[];

    // Check high dividend yield
    final dividendYield = fundamentalData.dividendYield;
    if (dividendYield != null &&
        dividendYield >= RuleParams.highDividendYieldThreshold) {
      results.add(TriggeredReason(
        type: ReasonType.highDividendYield,
        score: RuleScores.highDividendYield,
        evidence: {
          'dividend_yield': dividendYield,
          'threshold': RuleParams.highDividendYieldThreshold,
        },
        template: '高殖利率：${dividendYield.toStringAsFixed(2)}%（超過${RuleParams.highDividendYieldThreshold.toInt()}%）',
      ));
    }

    // Check PE undervalued
    final per = fundamentalData.per;
    if (per != null && per > 0 && per < RuleParams.peUndervaluedThreshold) {
      results.add(TriggeredReason(
        type: ReasonType.peUndervalued,
        score: RuleScores.peUndervalued,
        evidence: {
          'pe': per,
          'threshold': RuleParams.peUndervaluedThreshold,
        },
        template: 'PE低估：本益比 ${per.toStringAsFixed(1)} 倍（低於${RuleParams.peUndervaluedThreshold.toInt()}倍）',
      ));
    }

    // Check PE overvalued (warning signal)
    if (per != null && per > RuleParams.peOvervaluedThreshold) {
      results.add(TriggeredReason(
        type: ReasonType.peOvervalued,
        score: RuleScores.peOvervalued,
        evidence: {
          'pe': per,
          'threshold': RuleParams.peOvervaluedThreshold,
        },
        template: 'PE高估警示：本益比 ${per.toStringAsFixed(1)} 倍（超過${RuleParams.peOvervaluedThreshold.toInt()}倍）',
      ));
    }

    // Check PBR undervalued
    final pbr = fundamentalData.pbr;
    if (pbr != null && pbr > 0 && pbr < RuleParams.pbrUndervaluedThreshold) {
      results.add(TriggeredReason(
        type: ReasonType.pbrUndervalued,
        score: RuleScores.pbrUndervalued,
        evidence: {
          'pbr': pbr,
          'threshold': RuleParams.pbrUndervaluedThreshold,
        },
        template: '股價淨值比低：PBR ${pbr.toStringAsFixed(2)} 倍（低於淨值）',
      ));
    }

    return results;
  }

  /// Convert pattern result to triggered reason
  TriggeredReason? _patternToReason(PatternResult pattern) {
    final (reasonType, score) = switch (pattern.type) {
      CandlePatternType.doji => (
          ReasonType.patternDoji,
          RuleScores.patternDoji,
        ),
      CandlePatternType.bullishEngulfing => (
          ReasonType.patternBullishEngulfing,
          RuleScores.patternEngulfing,
        ),
      CandlePatternType.bearishEngulfing => (
          ReasonType.patternBearishEngulfing,
          RuleScores.patternEngulfing,
        ),
      CandlePatternType.hammer => (
          ReasonType.patternHammer,
          RuleScores.patternHammer,
        ),
      CandlePatternType.hangingMan => (
          ReasonType.patternHangingMan,
          RuleScores.patternHammer,
        ),
      CandlePatternType.gapUp => (
          ReasonType.patternGapUp,
          RuleScores.patternGap,
        ),
      CandlePatternType.gapDown => (
          ReasonType.patternGapDown,
          RuleScores.patternGap,
        ),
      CandlePatternType.morningStar => (
          ReasonType.patternMorningStar,
          RuleScores.patternStar,
        ),
      CandlePatternType.eveningStar => (
          ReasonType.patternEveningStar,
          RuleScores.patternStar,
        ),
      CandlePatternType.threeWhiteSoldiers => (
          ReasonType.patternThreeWhiteSoldiers,
          RuleScores.patternThreeSoldiers,
        ),
      CandlePatternType.threeBlackCrows => (
          ReasonType.patternThreeBlackCrows,
          RuleScores.patternThreeSoldiers,
        ),
    };

    // Apply confidence multiplier to score
    final adjustedScore = (score * pattern.confidence).round();

    return TriggeredReason(
      type: reasonType,
      score: adjustedScore,
      evidence: {
        'pattern': pattern.type.code,
        'confidence': pattern.confidence,
        'description': pattern.description,
      },
      template: pattern.description ?? pattern.type.label,
    );
  }
}

/// Category for reason deduplication
enum _ReasonCategory {
  reversal,
  technical,
  volume,
  price,
  institutional,
  news,
  kdSignal,
  pattern,
  // Phase 3 categories
  week52,
  maAlignment,
  rsiExtreme,
  // Phase 4 categories
  foreignShareholding,
  dayTrading,
  concentration,
  // Phase 5 categories
  priceVolumeDivergence,
  // Phase 6 categories
  revenue,
  valuation,
}

/// Triggered reason from rule evaluation
class TriggeredReason {
  const TriggeredReason({
    required this.type,
    required this.score,
    required this.evidence,
    required this.template,
  });

  final ReasonType type;
  final int score;
  final Map<String, dynamic> evidence;
  final String template;

  /// Convert evidence to JSON string for storage
  String get evidenceJson => jsonEncode(evidence);
}

/// Technical indicators data for a stock
class TechnicalIndicators {
  const TechnicalIndicators({
    this.rsi,
    this.kdK,
    this.kdD,
    this.prevKdK,
    this.prevKdD,
  });

  /// Current RSI value (0-100)
  final double? rsi;

  /// Current Stochastic %K value
  final double? kdK;

  /// Current Stochastic %D value
  final double? kdD;

  /// Previous day's %K value (for cross detection)
  final double? prevKdK;

  /// Previous day's %D value (for cross detection)
  final double? prevKdD;

  /// Check if KD golden cross occurred (K crosses above D)
  bool get isKdGoldenCross {
    if (kdK == null || kdD == null || prevKdK == null || prevKdD == null) {
      return false;
    }
    return prevKdK! <= prevKdD! && kdK! > kdD!;
  }

  /// Check if KD death cross occurred (K crosses below D)
  bool get isKdDeathCross {
    if (kdK == null || kdD == null || prevKdK == null || prevKdD == null) {
      return false;
    }
    return prevKdK! >= prevKdD! && kdK! < kdD!;
  }

  /// Check if RSI is in overbought territory
  bool get isRsiOverbought => rsi != null && rsi! >= RuleParams.rsiOverbought;

  /// Check if RSI is in oversold territory
  bool get isRsiOversold => rsi != null && rsi! <= RuleParams.rsiOversold;
}

/// Context for analysis (support/resistance levels, trend state, technical indicators)
class AnalysisContext {
  const AnalysisContext({
    required this.trendState,
    this.supportLevel,
    this.resistanceLevel,
    this.rangeTop,
    this.rangeBottom,
    this.technicalIndicators,
    this.marketData,
    this.fundamentalData,
  });

  final TrendState trendState;
  final double? supportLevel;
  final double? resistanceLevel;
  final double? rangeTop;
  final double? rangeBottom;

  /// Technical indicators (RSI, KD, etc.)
  final TechnicalIndicators? technicalIndicators;

  /// Extended market data (Phase 4: shareholding, day trading, concentration)
  final MarketDataContext? marketData;

  /// Fundamental data (Phase 6: revenue, valuation)
  final FundamentalDataContext? fundamentalData;
}

/// Extended market data context for Phase 4 signals
class MarketDataContext {
  const MarketDataContext({
    this.foreignSharesRatio,
    this.foreignSharesRatioChange,
    this.dayTradingRatio,
    this.concentrationRatio,
  });

  /// Current foreign shareholding ratio (%)
  final double? foreignSharesRatio;

  /// Foreign shareholding ratio change over N days (%)
  /// Positive = increasing, Negative = decreasing
  final double? foreignSharesRatioChange;

  /// Day trading ratio (%)
  final double? dayTradingRatio;

  /// Large holder concentration ratio (%)
  /// Percentage held by shareholders with 400+ lots
  final double? concentrationRatio;
}

/// Fundamental data context for Phase 6 signals
class FundamentalDataContext {
  const FundamentalDataContext({
    this.revenueYoyGrowth,
    this.revenueMomGrowth,
    this.revenueMomConsecutiveGrowthMonths,
    this.dividendYield,
    this.per,
    this.pbr,
  });

  /// Latest revenue year-over-year growth rate (%)
  final double? revenueYoyGrowth;

  /// Latest revenue month-over-month growth rate (%)
  final double? revenueMomGrowth;

  /// Number of consecutive months with positive MoM growth
  final int? revenueMomConsecutiveGrowthMonths;

  /// Current dividend yield (%)
  final double? dividendYield;

  /// Current price-to-earnings ratio
  final double? per;

  /// Current price-to-book ratio
  final double? pbr;
}
