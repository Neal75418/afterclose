import 'dart:convert';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';

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

    // Sort by score descending
    reasons.sort((a, b) => b.score.compareTo(a.score));

    return reasons;
  }

  /// Calculate final score with bonuses and cooldown
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

    // Cooldown penalty
    if (wasRecentlyRecommended) {
      score = (score * RuleParams.cooldownMultiplier).round();
    }

    return score;
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
            template: '強轉弱：大幅跌破昨日低點 ${yesterdayLow.toStringAsFixed(2)}（跌${(dropPercent * 100).toStringAsFixed(1)}%）',
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
          template: '技術跌破：跌破近10日低點 ${swingLow10.toStringAsFixed(2)}（破${(breakPercent * 100).toStringAsFixed(1)}%）',
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
      ReasonType.reversalS2W => _ReasonCategory.reversal,
      ReasonType.techBreakout ||
      ReasonType.techBreakdown => _ReasonCategory.technical,
      ReasonType.volumeSpike => _ReasonCategory.volume,
      ReasonType.priceSpike => _ReasonCategory.price,
      ReasonType.institutionalShift => _ReasonCategory.institutional,
      ReasonType.newsRelated => _ReasonCategory.news,
    };
  }
}

/// Category for reason deduplication
enum _ReasonCategory { reversal, technical, volume, price, institutional, news }

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

/// Context for analysis (support/resistance levels, trend state)
class AnalysisContext {
  const AnalysisContext({
    required this.trendState,
    this.supportLevel,
    this.resistanceLevel,
    this.rangeTop,
    this.rangeBottom,
  });

  final TrendState trendState;
  final double? supportLevel;
  final double? resistanceLevel;
  final double? rangeTop;
  final double? rangeBottom;
}
