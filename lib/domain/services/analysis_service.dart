import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// Service for technical analysis of stock price data
class AnalysisService {
  const AnalysisService();

  /// Analyze a single stock and return analysis result
  ///
  /// Requires at least [RuleParams.rangeLookback] days of price history
  AnalysisResult? analyzeStock(List<DailyPriceEntry> priceHistory) {
    if (priceHistory.length < RuleParams.swingWindow) {
      return null; // Not enough data
    }

    // Calculate support and resistance
    final (support, resistance) = findSupportResistance(priceHistory);

    // Calculate 60-day range
    final (rangeBottom, rangeTop) = findRange(priceHistory);

    // Detect trend state
    final trendState = detectTrendState(priceHistory);

    // Detect reversal state
    final reversalState = detectReversalState(
      priceHistory,
      trendState: trendState,
      rangeTop: rangeTop,
      rangeBottom: rangeBottom,
      support: support,
    );

    return AnalysisResult(
      trendState: trendState,
      reversalState: reversalState,
      supportLevel: support,
      resistanceLevel: resistance,
      rangeTop: rangeTop,
      rangeBottom: rangeBottom,
    );
  }

  /// Build analysis context for rule engine
  AnalysisContext buildContext(AnalysisResult result) {
    return AnalysisContext(
      trendState: result.trendState,
      supportLevel: result.supportLevel,
      resistanceLevel: result.resistanceLevel,
      rangeTop: result.rangeTop,
      rangeBottom: result.rangeBottom,
    );
  }

  /// Find support and resistance levels using Swing High/Low method
  ///
  /// Returns (support, resistance) tuple
  (double?, double?) findSupportResistance(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) {
      return (null, null);
    }

    // Find swing highs and lows
    final swingHighs = <double>[];
    final swingLows = <double>[];

    // Use half of swing window on each side
    const halfWindow = RuleParams.swingWindow ~/ 2;

    for (var i = halfWindow; i < prices.length - halfWindow; i++) {
      final current = prices[i];
      final high = current.high;
      final low = current.low;

      if (high == null || low == null) continue;

      // Check if this is a swing high
      var isSwingHigh = true;
      var isSwingLow = true;

      for (var j = i - halfWindow; j <= i + halfWindow; j++) {
        if (j == i) continue;
        final other = prices[j];

        if (other.high != null && other.high! >= high) {
          isSwingHigh = false;
        }
        if (other.low != null && other.low! <= low) {
          isSwingLow = false;
        }
      }

      if (isSwingHigh) swingHighs.add(high);
      if (isSwingLow) swingLows.add(low);
    }

    // Get most recent swing high/low as resistance/support
    final resistance = swingHighs.isNotEmpty ? swingHighs.last : null;
    final support = swingLows.isNotEmpty ? swingLows.last : null;

    return (support, resistance);
  }

  /// Find 60-day price range
  ///
  /// Returns (rangeBottom, rangeTop) tuple
  (double?, double?) findRange(List<DailyPriceEntry> prices) {
    final rangePrices = prices.reversed.take(RuleParams.rangeLookback).toList();

    if (rangePrices.isEmpty) return (null, null);

    double? rangeHigh;
    double? rangeLow;

    for (final price in rangePrices) {
      final high = price.high;
      final low = price.low;

      if (high != null && (rangeHigh == null || high > rangeHigh)) {
        rangeHigh = high;
      }
      if (low != null && (rangeLow == null || low < rangeLow)) {
        rangeLow = low;
      }
    }

    return (rangeLow, rangeHigh);
  }

  /// Detect overall trend state
  TrendState detectTrendState(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow) {
      return TrendState.range;
    }

    // Get recent prices for trend analysis
    final recentPrices = prices.reversed.take(RuleParams.swingWindow).toList();

    // Calculate simple trend using closing prices
    final closes = recentPrices
        .map((p) => p.close)
        .whereType<double>()
        .toList();

    if (closes.length < 5) return TrendState.range;

    // Linear regression slope
    final slope = _calculateSlope(closes);

    // Normalize slope by average price (guard against division by zero)
    final avgPrice = closes.reduce((a, b) => a + b) / closes.length;
    if (avgPrice <= 0) return TrendState.range;

    final normalizedSlope = (slope / avgPrice) * 100;

    // Thresholds for trend detection
    const upThreshold = 0.15; // 0.15% per day = ~3% over 20 days
    const downThreshold = -0.15;

    if (normalizedSlope > upThreshold) {
      return TrendState.up;
    } else if (normalizedSlope < downThreshold) {
      return TrendState.down;
    } else {
      return TrendState.range;
    }
  }

  /// Detect reversal state based on trend and price action
  ReversalState detectReversalState(
    List<DailyPriceEntry> prices, {
    required TrendState trendState,
    double? rangeTop,
    double? rangeBottom,
    double? support,
  }) {
    if (prices.length < 2) return ReversalState.none;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return ReversalState.none;

    // Check for weak-to-strong (W2S)
    if (trendState == TrendState.down || trendState == TrendState.range) {
      // Breakout above range top
      if (rangeTop != null) {
        final breakoutLevel = rangeTop * (1 + RuleParams.breakoutBuffer);
        if (todayClose > breakoutLevel) {
          return ReversalState.weakToStrong;
        }
      }

      // Higher low formation
      if (_hasHigherLow(prices)) {
        return ReversalState.weakToStrong;
      }
    }

    // Check for strong-to-weak (S2W)
    if (trendState == TrendState.up || trendState == TrendState.range) {
      // Breakdown below support
      if (support != null) {
        final breakdownLevel = support * (1 - RuleParams.breakoutBuffer);
        if (todayClose < breakdownLevel) {
          return ReversalState.strongToWeak;
        }
      }

      // Breakdown below range bottom
      if (rangeBottom != null) {
        final breakdownLevel = rangeBottom * (1 - RuleParams.breakoutBuffer);
        if (todayClose < breakdownLevel) {
          return ReversalState.strongToWeak;
        }
      }
    }

    return ReversalState.none;
  }

  /// Check for candidate conditions (pre-filter for analysis)
  ///
  /// Returns true if stock meets any candidate criteria:
  /// - Price change >= 5%
  /// - Volume >= 20-day MA * 2
  /// - Near 60-day high/low
  bool isCandidate(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.volMa + 1) return false;

    final today = prices.last;
    final yesterday = prices[prices.length - 2];

    // Check price spike
    final todayClose = today.close;
    final yesterdayClose = yesterday.close;

    if (todayClose != null && yesterdayClose != null && yesterdayClose > 0) {
      final pctChange =
          ((todayClose - yesterdayClose) / yesterdayClose).abs() * 100;
      if (pctChange >= RuleParams.priceSpikePercent) {
        return true;
      }
    }

    // Check volume spike
    final todayVolume = today.volume;
    if (todayVolume != null && todayVolume > 0) {
      final volumeHistory = prices.reversed
          .skip(1)
          .take(RuleParams.volMa)
          .map((p) => p.volume ?? 0)
          .toList();

      if (volumeHistory.isNotEmpty) {
        final volMa20 =
            volumeHistory.reduce((a, b) => a + b) / volumeHistory.length;
        if (volMa20 > 0 &&
            todayVolume >= volMa20 * RuleParams.volumeSpikeMult) {
          return true;
        }
      }
    }

    // Check near 60-day high/low
    if (todayClose != null) {
      final (rangeLow, rangeHigh) = findRange(prices);

      if (rangeHigh != null && rangeHigh > 0) {
        // Within 2% of 60-day high
        if (todayClose >= rangeHigh * 0.98) {
          return true;
        }
      }

      if (rangeLow != null && rangeLow > 0) {
        // Within 2% of 60-day low
        if (todayClose <= rangeLow * 1.02) {
          return true;
        }
      }
    }

    return false;
  }

  // ==========================================
  // Private Helper Methods
  // ==========================================

  /// Calculate linear regression slope
  double _calculateSlope(List<double> values) {
    final n = values.length;
    if (n < 2) return 0;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return 0;

    return (n * sumXY - sumX * sumY) / denominator;
  }

  /// Check for higher low formation (reversal signal)
  bool _hasHigherLow(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) return false;

    // Find recent swing low
    final recentPrices = prices.reversed.take(RuleParams.swingWindow).toList();
    final prevPrices = prices.reversed
        .skip(RuleParams.swingWindow)
        .take(RuleParams.swingWindow)
        .toList();

    final recentLow = _findMinLow(recentPrices);
    final prevLow = _findMinLow(prevPrices);

    if (recentLow == null || prevLow == null) return false;

    // Recent low should be higher than previous low
    return recentLow > prevLow;
  }

  /// Find minimum low in price list
  double? _findMinLow(List<DailyPriceEntry> prices) {
    double? minLow;
    for (final price in prices) {
      final low = price.low;
      if (low != null && (minLow == null || low < minLow)) {
        minLow = low;
      }
    }
    return minLow;
  }
}

/// Result of stock analysis
class AnalysisResult {
  const AnalysisResult({
    required this.trendState,
    required this.reversalState,
    this.supportLevel,
    this.resistanceLevel,
    this.rangeTop,
    this.rangeBottom,
  });

  final TrendState trendState;
  final ReversalState reversalState;
  final double? supportLevel;
  final double? resistanceLevel;
  final double? rangeTop;
  final double? rangeBottom;

  /// Check if this is a potential reversal candidate
  bool get isReversalCandidate => reversalState != ReversalState.none;
}
