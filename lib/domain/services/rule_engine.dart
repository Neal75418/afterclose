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

    // R1: REVERSAL_W2S (Weak to Strong)
    final r1 = checkWeakToStrong(priceHistory, context);
    if (r1 != null) reasons.add(r1);

    // R2: REVERSAL_S2W (Strong to Weak)
    final r2 = checkStrongToWeak(priceHistory, context);
    if (r2 != null) reasons.add(r2);

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
    if (context.rangeTop != null) {
      final breakoutLevel = context.rangeTop! * (1 + RuleParams.breakoutBuffer);
      if (todayClose > breakoutLevel && context.trendState == TrendState.down) {
        return TriggeredReason(
          type: ReasonType.reversalW2S,
          score: RuleScores.reversalW2S,
          evidence: {
            'trigger': 'breakout_range_top',
            'range_top': context.rangeTop,
            'close': todayClose,
            'buffer': RuleParams.breakoutBuffer,
          },
          template: '弱轉強：突破盤整區上緣 ${context.rangeTop?.toStringAsFixed(2)}',
        );
      }
    }

    // Check: Downtrend structure broken (no new low + higher low)
    if (context.trendState == TrendState.down) {
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
    if (context.supportLevel != null) {
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakoutBuffer);
      if (todayClose < breakdownLevel && context.trendState == TrendState.up) {
        return TriggeredReason(
          type: ReasonType.reversalS2W,
          score: RuleScores.reversalS2W,
          evidence: {
            'trigger': 'breakdown_support',
            'support': context.supportLevel,
            'close': todayClose,
            'buffer': RuleParams.breakoutBuffer,
          },
          template: '強轉弱：跌破關鍵支撐 ${context.supportLevel?.toStringAsFixed(2)}',
        );
      }
    }

    // Check: Breakdown below range bottom
    if (context.rangeBottom != null) {
      final breakdownLevel =
          context.rangeBottom! * (1 - RuleParams.breakoutBuffer);
      if (todayClose < breakdownLevel &&
          context.trendState != TrendState.down) {
        return TriggeredReason(
          type: ReasonType.reversalS2W,
          score: RuleScores.reversalS2W,
          evidence: {
            'trigger': 'breakdown_range_bottom',
            'range_bottom': context.rangeBottom,
            'close': todayClose,
            'buffer': RuleParams.breakoutBuffer,
          },
          template: '強轉弱：跌破盤整區下緣 ${context.rangeBottom?.toStringAsFixed(2)}',
        );
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
    if (context.supportLevel == null) return null;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return null;

    final breakdownLevel =
        context.supportLevel! * (1 - RuleParams.breakoutBuffer);

    if (todayClose < breakdownLevel) {
      return TriggeredReason(
        type: ReasonType.techBreakdown,
        score: RuleScores.techBreakdown,
        evidence: {
          'support': context.supportLevel,
          'close': todayClose,
          'buffer': RuleParams.breakoutBuffer,
        },
        template: '技術跌破：收盤跌破支撐 ${context.supportLevel?.toStringAsFixed(2)}',
      );
    }

    return null;
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

    if (volumeMult >= RuleParams.volumeSpikeMult) {
      return TriggeredReason(
        type: ReasonType.volumeSpike,
        score: RuleScores.volumeSpike,
        evidence: {'vol': todayVolume, 'vol_ma20': volMa20, 'mult': volumeMult},
        template:
            '放量：成交量 ${_formatVolume(todayVolume)}（約為20日均量的 ${volumeMult.toStringAsFixed(1)}x）',
      );
    }

    return null;
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

    // Check for direction reversal
    final todayDir = todayNet > 0 ? 'buy' : (todayNet < 0 ? 'sell' : 'neutral');
    final prevDir = prev3Net > 0 ? 'buy' : (prev3Net < 0 ? 'sell' : 'neutral');

    if ((todayDir == 'buy' && prevDir == 'sell') ||
        (todayDir == 'sell' && prevDir == 'buy')) {
      return TriggeredReason(
        type: ReasonType.institutionalShift,
        score: RuleScores.institutionalShift,
        evidence: {
          'foreign_net': today.foreignNet,
          'dir_prev3': prevDir,
          'dir_today': todayDir,
          'today_net': todayNet,
          'prev3_net': prev3Net,
        },
        template: '法人變化：方向反轉（$prevDir → $todayDir）',
      );
    }

    return null;
  }

  // ==========================================
  // R8: NEWS_RELATED +8
  // ==========================================

  /// Check for recent news mentions
  TriggeredReason? checkNewsRelated(List<NewsItemEntry> news) {
    if (news.isEmpty) return null;

    // Get the most recent news item
    final latestNews = news.first;

    return TriggeredReason(
      type: ReasonType.newsRelated,
      score: RuleScores.newsRelated,
      evidence: {
        'source': latestNews.source,
        'title': latestNews.title,
        'url': latestNews.url,
        'published_at': latestNews.publishedAt.toIso8601String(),
      },
      template: '新聞關聯：${latestNews.source} - ${latestNews.title}',
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
