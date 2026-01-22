import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Phase 5: Price-Volume Divergence Rules
// ==========================================

/// Rule: Bullish Divergence (價漲量縮)
/// Price going up but volume decreasing - warning signal
class PriceVolumeBullishDivergenceRule extends StockRule {
  const PriceVolumeBullishDivergenceRule();

  @override
  String get id => 'price_volume_bullish_divergence';

  @override
  String get name => '價漲量縮';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return null;
    }

    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = data.prices.reversed.take(lookback + 1).toList();

    if (recentPrices.length < lookback + 1) return null;

    final todayClose = recentPrices[0].close;
    final pastClose = recentPrices[lookback].close;
    final todayVolume = recentPrices[0].volume;

    if (todayClose == null || pastClose == null || todayVolume == null) {
      return null;
    }

    // Calculate average volume for lookback period
    double volumeSum = 0;
    int volumeCount = 0;
    for (int i = 1; i <= lookback; i++) {
      final vol = recentPrices[i].volume;
      if (vol != null && vol > 0) {
        volumeSum += vol;
        volumeCount++;
      }
    }
    if (volumeCount == 0) return null;
    final avgVolume = volumeSum / volumeCount;

    // Check for divergence
    final priceChange = (todayClose - pastClose) / pastClose * 100;
    final volumeChange = (todayVolume - avgVolume) / avgVolume * 100;

    // Price up significantly but volume down
    if (priceChange >= RuleParams.priceVolumePriceThreshold &&
        volumeChange <= -RuleParams.priceVolumeVolumeThreshold) {
      return TriggeredReason(
        type: ReasonType.priceVolumeBullishDivergence,
        score: RuleScores.priceVolumeBullishDivergence,
        description: '價漲量縮：價格上漲${priceChange.toStringAsFixed(1)}%，成交量萎縮',
        evidence: {
          'priceChange': priceChange,
          'volumeChange': volumeChange,
          'todayVolume': todayVolume,
          'avgVolume': avgVolume,
        },
      );
    }

    return null;
  }
}

/// Rule: Bearish Divergence (價跌量增)
/// Price going down with volume increasing - panic signal
class PriceVolumeBearishDivergenceRule extends StockRule {
  const PriceVolumeBearishDivergenceRule();

  @override
  String get id => 'price_volume_bearish_divergence';

  @override
  String get name => '價跌量增';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return null;
    }

    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = data.prices.reversed.take(lookback + 1).toList();

    if (recentPrices.length < lookback + 1) return null;

    final todayClose = recentPrices[0].close;
    final pastClose = recentPrices[lookback].close;
    final todayVolume = recentPrices[0].volume;

    if (todayClose == null || pastClose == null || todayVolume == null) {
      return null;
    }

    double volumeSum = 0;
    int volumeCount = 0;
    for (int i = 1; i <= lookback; i++) {
      final vol = recentPrices[i].volume;
      if (vol != null && vol > 0) {
        volumeSum += vol;
        volumeCount++;
      }
    }
    if (volumeCount == 0) return null;
    final avgVolume = volumeSum / volumeCount;

    final priceChange = (todayClose - pastClose) / pastClose * 100;
    final volumeChange = (todayVolume - avgVolume) / avgVolume * 100;

    // Price down significantly with volume up
    if (priceChange <= -RuleParams.priceVolumePriceThreshold &&
        volumeChange >= RuleParams.priceVolumeVolumeThreshold) {
      return TriggeredReason(
        type: ReasonType.priceVolumeBearishDivergence,
        score: RuleScores.priceVolumeBearishDivergence,
        description: '價跌量增：價格下跌${priceChange.abs().toStringAsFixed(1)}%，成交量放大',
        evidence: {
          'priceChange': priceChange,
          'volumeChange': volumeChange,
          'todayVolume': todayVolume,
          'avgVolume': avgVolume,
        },
      );
    }

    return null;
  }
}

/// Rule: High Volume Breakout
/// Price at high position with volume spike
class HighVolumeBreakoutRule extends StockRule {
  const HighVolumeBreakoutRule();

  @override
  String get id => 'high_volume_breakout';

  @override
  String get name => '高檔爆量';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.rangeLookback) return null;

    final today = data.prices.last;
    final close = today.close;
    final volume = today.volume;

    if (close == null || volume == null) return null;

    // Calculate 60-day range
    double maxHigh = 0;
    double minLow = double.infinity;
    double volumeSum = 0;
    int volumeCount = 0;

    for (
      int i = data.prices.length - RuleParams.rangeLookback;
      i < data.prices.length - 1;
      i++
    ) {
      final p = data.prices[i];
      final high = p.high ?? p.close ?? 0;
      final low = p.low ?? p.close ?? double.infinity;
      final vol = p.volume ?? 0;

      if (high > maxHigh) maxHigh = high;
      if (low > 0 && low < minLow) minLow = low;
      if (vol > 0) {
        volumeSum += vol;
        volumeCount++;
      }
    }

    if (maxHigh <= minLow || volumeCount == 0) return null;

    final range = maxHigh - minLow;
    final position = (close - minLow) / range; // 0 = low, 1 = high
    final avgVolume = volumeSum / volumeCount;

    // High position (top 15%) with volume spike (4x)
    if (position >= RuleParams.highPositionThreshold &&
        volume >= avgVolume * RuleParams.volumeSpikeMult) {
      return TriggeredReason(
        type: ReasonType.highVolumeBreakout,
        score: RuleScores.highVolumeBreakout,
        description: '高檔爆量突破',
        evidence: {
          'position': position,
          'volumeMultiple': volume / avgVolume,
          'close': close,
          'rangeHigh': maxHigh,
        },
      );
    }

    return null;
  }
}

/// Rule: Low Volume Accumulation
/// Price at low position with shrinking volume - potential accumulation
class LowVolumeAccumulationRule extends StockRule {
  const LowVolumeAccumulationRule();

  @override
  String get id => 'low_volume_accumulation';

  @override
  String get name => '低檔吸籌';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.rangeLookback) return null;

    final today = data.prices.last;
    final close = today.close;
    final volume = today.volume;

    if (close == null || volume == null) return null;

    double maxHigh = 0;
    double minLow = double.infinity;
    double volumeSum = 0;
    int volumeCount = 0;

    for (
      int i = data.prices.length - RuleParams.rangeLookback;
      i < data.prices.length - 1;
      i++
    ) {
      final p = data.prices[i];
      final high = p.high ?? p.close ?? 0;
      final low = p.low ?? p.close ?? double.infinity;
      final vol = p.volume ?? 0;

      if (high > maxHigh) maxHigh = high;
      if (low > 0 && low < minLow) minLow = low;
      if (vol > 0) {
        volumeSum += vol;
        volumeCount++;
      }
    }

    if (maxHigh <= minLow || volumeCount == 0) return null;

    final range = maxHigh - minLow;
    final position = (close - minLow) / range;
    final avgVolume = volumeSum / volumeCount;

    // Low position (bottom 15%) with low volume (below 50% of avg)
    if (position <= RuleParams.lowPositionThreshold &&
        volume < avgVolume * 0.5) {
      return TriggeredReason(
        type: ReasonType.lowVolumeAccumulation,
        score: RuleScores.lowVolumeAccumulation,
        description: '低檔縮量整理',
        evidence: {
          'position': position,
          'volumeRatio': volume / avgVolume,
          'close': close,
          'rangeLow': minLow,
        },
      );
    }

    return null;
  }
}
