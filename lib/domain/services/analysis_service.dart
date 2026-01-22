import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

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

  /// Technical indicator service for KD, RSI calculations
  static final _indicatorService = TechnicalIndicatorService();

  /// Build analysis context for rule engine
  AnalysisContext buildContext(
    AnalysisResult result, {
    List<DailyPriceEntry>? priceHistory,
    MarketDataContext? marketData,
  }) {
    TechnicalIndicators? indicators;

    // Calculate technical indicators if price history is provided
    if (priceHistory != null && priceHistory.length >= _minIndicatorDataPoints) {
      indicators = calculateTechnicalIndicators(priceHistory);
    }

    return AnalysisContext(
      trendState: result.trendState,
      supportLevel: result.supportLevel,
      resistanceLevel: result.resistanceLevel,
      rangeTop: result.rangeTop,
      rangeBottom: result.rangeBottom,
      technicalIndicators: indicators,
      marketData: marketData,
    );
  }

  /// Minimum data points required for technical indicators
  /// RSI needs: rsiPeriod + 1 (14 + 1 = 15)
  /// KD needs: kdPeriodK + kdPeriodD - 1 + 1 for prev day (9 + 3 - 1 + 1 = 12)
  /// Use the maximum to ensure both can be calculated
  static final _minIndicatorDataPoints = [
    RuleParams.rsiPeriod + 1,
    RuleParams.kdPeriodK + RuleParams.kdPeriodD,
  ].reduce((a, b) => a > b ? a : b);

  /// Calculate technical indicators from price history
  ///
  /// Returns RSI and KD values for the most recent day,
  /// plus previous day's KD for cross detection.
  TechnicalIndicators? calculateTechnicalIndicators(
    List<DailyPriceEntry> prices,
  ) {
    if (prices.length < _minIndicatorDataPoints) {
      return null;
    }

    // Extract OHLC data
    final closes = <double>[];
    final highs = <double>[];
    final lows = <double>[];

    for (final price in prices) {
      if (price.close != null && price.high != null && price.low != null) {
        closes.add(price.close!);
        highs.add(price.high!);
        lows.add(price.low!);
      }
    }

    if (closes.length < RuleParams.rsiPeriod + 2) {
      return null;
    }

    // Calculate RSI
    final rsiValues = _indicatorService.calculateRSI(
      closes,
      period: RuleParams.rsiPeriod,
    );
    final currentRsi = rsiValues.isNotEmpty ? rsiValues.last : null;

    // Calculate KD
    final kd = _indicatorService.calculateKD(
      highs,
      lows,
      closes,
      kPeriod: RuleParams.kdPeriodK,
      dPeriod: RuleParams.kdPeriodD,
    );

    // Get current and previous day's KD values
    double? currentK, currentD, prevK, prevD;

    if (kd.k.length >= 2 && kd.d.length >= 2) {
      currentK = kd.k.last;
      currentD = kd.d.last;
      prevK = kd.k[kd.k.length - 2];
      prevD = kd.d[kd.d.length - 2];
    } else if (kd.k.isNotEmpty && kd.d.isNotEmpty) {
      currentK = kd.k.last;
      currentD = kd.d.last;
    }

    return TechnicalIndicators(
      rsi: currentRsi,
      kdK: currentK,
      kdD: currentD,
      prevKdK: prevK,
      prevKdD: prevD,
    );
  }

  /// Find support and resistance levels using Swing High/Low clustering
  ///
  /// Improved algorithm:
  /// 1. Find all swing highs and lows
  /// 2. Cluster nearby points into zones (within 2% of each other)
  /// 3. Weight zones by number of touches (more touches = stronger level)
  /// 4. Select the most relevant support below current price and resistance above
  ///
  /// Returns (support, resistance) tuple
  (double?, double?) findSupportResistance(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) {
      return (null, null);
    }

    // Find all swing highs and lows with their indices
    final swingHighs = <_SwingPoint>[];
    final swingLows = <_SwingPoint>[];

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

        // Use strict inequality (>) to allow equal prices to be swing points
        if (isSwingHigh && other.high != null && other.high! > high) {
          isSwingHigh = false;
        }
        if (isSwingLow && other.low != null && other.low! < low) {
          isSwingLow = false;
        }

        // Early exit if neither condition can be met (performance optimization)
        if (!isSwingHigh && !isSwingLow) break;
      }

      if (isSwingHigh) swingHighs.add(_SwingPoint(price: high, index: i));
      if (isSwingLow) swingLows.add(_SwingPoint(price: low, index: i));
    }

    // Get current price for reference
    final currentClose = prices.last.close;
    if (currentClose == null) {
      // Fallback to simple method if no current price
      final resistance = swingHighs.isNotEmpty ? swingHighs.last.price : null;
      final support = swingLows.isNotEmpty ? swingLows.last.price : null;
      return (support, resistance);
    }

    // Cluster swing points and find the most significant levels
    final resistanceZones = _clusterSwingPoints(swingHighs, prices.length);
    final supportZones = _clusterSwingPoints(swingLows, prices.length);

    // Find the nearest resistance above current price (within max distance)
    double? resistance;
    var bestResistanceScore = 0.0;
    final maxResistance =
        currentClose * (1 + RuleParams.maxSupportResistanceDistance);
    for (final zone in resistanceZones) {
      // Only consider resistance within max distance
      if (zone.avgPrice > currentClose && zone.avgPrice <= maxResistance) {
        // Score based on touches and recency
        final score = zone.touches * (1 + zone.recencyWeight);
        if (score > bestResistanceScore) {
          bestResistanceScore = score;
          resistance = zone.avgPrice;
        }
      }
    }

    // Find the nearest support below current price (within max distance)
    // This is critical for BREAKDOWN and S2W signals
    double? support;
    var bestSupportScore = 0.0;
    final minSupport =
        currentClose * (1 - RuleParams.maxSupportResistanceDistance);
    for (final zone in supportZones) {
      // Only consider support within max distance
      if (zone.avgPrice < currentClose && zone.avgPrice >= minSupport) {
        // Score based on touches and recency
        final score = zone.touches * (1 + zone.recencyWeight);
        if (score > bestSupportScore) {
          bestSupportScore = score;
          support = zone.avgPrice;
        }
      }
    }

    // Fallback to most recent swing point ONLY if within max distance
    // Don't fall back to distant levels as they're not actionable
    if (resistance == null && swingHighs.isNotEmpty) {
      final lastHigh = swingHighs.last.price;
      if (lastHigh > currentClose && lastHigh <= maxResistance) {
        resistance = lastHigh;
      }
    }
    if (support == null && swingLows.isNotEmpty) {
      final lastLow = swingLows.last.price;
      if (lastLow < currentClose && lastLow >= minSupport) {
        support = lastLow;
      }
    }

    return (support, resistance);
  }

  /// Cluster swing points into price zones
  ///
  /// Groups points within [_clusterThreshold] (2%) of each other
  List<_PriceZone> _clusterSwingPoints(
    List<_SwingPoint> points,
    int totalDataPoints,
  ) {
    if (points.isEmpty) return [];

    // Sort by price
    final sorted = List<_SwingPoint>.from(points)
      ..sort((a, b) => a.price.compareTo(b.price));

    final zones = <_PriceZone>[];
    var currentZonePoints = <_SwingPoint>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final point = sorted[i];
      final zoneAvg =
          currentZonePoints.map((p) => p.price).reduce((a, b) => a + b) /
          currentZonePoints.length;

      // Check if point is within 2% of zone average
      // Guard against division by zero (though prices should never be 0)
      final isWithinThreshold = zoneAvg > 0
          ? (point.price - zoneAvg).abs() / zoneAvg <= _clusterThreshold
          : true; // If zoneAvg is 0, group all zero-price points together
      if (isWithinThreshold) {
        currentZonePoints.add(point);
      } else {
        // Save current zone and start new one
        zones.add(_createZone(currentZonePoints, totalDataPoints));
        currentZonePoints = [point];
      }
    }

    // Don't forget the last zone
    if (currentZonePoints.isNotEmpty) {
      zones.add(_createZone(currentZonePoints, totalDataPoints));
    }

    return zones;
  }

  /// Create a price zone from a list of swing points
  ///
  /// Precondition: [points] must not be empty
  _PriceZone _createZone(List<_SwingPoint> points, int totalDataPoints) {
    assert(points.isNotEmpty, '_createZone called with empty points list');

    final prices = points.map((p) => p.price);
    final avgPrice = prices.reduce((a, b) => a + b) / points.length;
    final maxIndex = points.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    // Recency weight: more recent = higher weight (0.0 to 1.0)
    final recencyWeight = totalDataPoints > 0
        ? maxIndex / totalDataPoints
        : 0.5;

    return _PriceZone(
      avgPrice: avgPrice,
      touches: points.length,
      recencyWeight: recencyWeight,
    );
  }

  /// Cluster threshold for grouping swing points (2%)
  static const _clusterThreshold = 0.02;

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
    // Note: closes are in newest-to-oldest order from reversed.take(),
    // so we negate the slope to get the actual time-forward slope
    final slope = -_calculateSlope(closes);

    // Normalize slope by average price (guard against division by zero)
    final avgPrice = closes.reduce((a, b) => a + b) / closes.length;
    if (avgPrice <= 0) return TrendState.range;

    final normalizedSlope = (slope / avgPrice) * 100;

    // Thresholds for trend detection (lowered for more signals)
    const upThreshold = 0.08; // 0.08% per day = ~1.6% over 20 days
    const downThreshold = -0.08;

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
    // Uses breakdownBuffer (looser) for easier triggering
    if (trendState == TrendState.up || trendState == TrendState.range) {
      // Breakdown below support
      if (support != null) {
        final breakdownLevel = support * (1 - RuleParams.breakdownBuffer);
        if (todayClose < breakdownLevel) {
          return ReversalState.strongToWeak;
        }
      }

      // Breakdown below range bottom
      if (rangeBottom != null) {
        final breakdownLevel = rangeBottom * (1 - RuleParams.breakdownBuffer);
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
    // Use epsilon comparison for floating point safety
    const epsilon = 1e-10;
    if (denominator.abs() < epsilon) return 0;

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

  /// Analyze price-volume relationship for divergence detection
  ///
  /// Returns a [PriceVolumeAnalysis] with divergence state and context
  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    // Get recent prices (excluding today for comparison base)
    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = prices.reversed.take(lookback + 1).toList();

    // Calculate price change over lookback period
    final todayClose = recentPrices.first.close;
    final startClose = recentPrices.last.close;
    if (todayClose == null || startClose == null || startClose <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final priceChangePercent = ((todayClose - startClose) / startClose) * 100;

    // Calculate volume change (average of recent vs previous period)
    final recentVolumes = recentPrices
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.length < lookback ~/ 2) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final avgRecentVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    // Get previous period volume for comparison
    final prevPrices = prices.reversed
        .skip(lookback)
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (prevPrices.isEmpty) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final avgPrevVolume = prevPrices.reduce((a, b) => a + b) / prevPrices.length;
    if (avgPrevVolume <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final volumeChangePercent =
        ((avgRecentVolume - avgPrevVolume) / avgPrevVolume) * 100;

    // Calculate price position in 60-day range (for high/low detection)
    final (rangeLow, rangeHigh) = findRange(prices);
    double? pricePosition;
    if (rangeLow != null && rangeHigh != null && rangeHigh > rangeLow) {
      pricePosition = (todayClose - rangeLow) / (rangeHigh - rangeLow);
    }

    // Determine divergence state
    const priceThreshold = RuleParams.priceVolumePriceThreshold;
    const volumeThreshold = RuleParams.priceVolumeVolumeThreshold;

    PriceVolumeState state = PriceVolumeState.neutral;

    // Price up + volume down = Bullish divergence (warning)
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      state = PriceVolumeState.bullishDivergence;
    }
    // Price down + volume up = Bearish divergence (panic)
    else if (priceChangePercent <= -priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      state = PriceVolumeState.bearishDivergence;
    }
    // High position + high volume = potential distribution
    else if (pricePosition != null &&
        pricePosition >= RuleParams.highPositionThreshold &&
        volumeChangePercent >= volumeThreshold * 1.5) {
      state = PriceVolumeState.highVolumeAtHigh;
    }
    // Low position + decreasing volume = potential accumulation
    else if (pricePosition != null &&
        pricePosition <= RuleParams.lowPositionThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      state = PriceVolumeState.lowVolumeAtLow;
    }
    // Healthy: price up + volume up
    else if (priceChangePercent >= priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      state = PriceVolumeState.healthyUptrend;
    }

    return PriceVolumeAnalysis(
      state: state,
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChangePercent,
      pricePosition: pricePosition,
    );
  }
}

/// Price-volume relationship states
enum PriceVolumeState {
  /// Neutral - no significant divergence
  neutral,

  /// Price up + volume down - warning signal (上漲無力)
  bullishDivergence,

  /// Price down + volume up - panic selling (恐慌殺盤)
  bearishDivergence,

  /// High price position + high volume - potential distribution (高檔出貨)
  highVolumeAtHigh,

  /// Low price position + low volume - potential accumulation (低檔吸籌)
  lowVolumeAtLow,

  /// Healthy uptrend - price up + volume up (健康上漲)
  healthyUptrend,
}

/// Result of price-volume analysis
class PriceVolumeAnalysis {
  const PriceVolumeAnalysis({
    required this.state,
    this.priceChangePercent,
    this.volumeChangePercent,
    this.pricePosition,
  });

  final PriceVolumeState state;
  final double? priceChangePercent;
  final double? volumeChangePercent;
  final double? pricePosition;

  bool get hasDivergence =>
      state == PriceVolumeState.bullishDivergence ||
      state == PriceVolumeState.bearishDivergence;
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

// ==================================================
// Private Helper Classes
// ==================================================

/// A swing point with price and position index
class _SwingPoint {
  const _SwingPoint({required this.price, required this.index});

  final double price;
  final int index;
}

/// A price zone representing clustered swing points
class _PriceZone {
  const _PriceZone({
    required this.avgPrice,
    required this.touches,
    required this.recencyWeight,
  });

  /// Average price of all points in this zone
  final double avgPrice;

  /// Number of swing points that touched this zone
  final int touches;

  /// Weight based on how recent the touches are (0.0 to 1.0)
  final double recencyWeight;
}
