import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Phase 3: Technical Signal Rules
// ==========================================

/// Rule: 52-Week High Detection
/// Triggers when close price is at or near 52-week high
class Week52HighRule extends StockRule {
  const Week52HighRule();

  @override
  String get id => 'week_52_high';

  @override
  String get name => '52週新高';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.week52Days) return null;

    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    // Calculate 52-week high from price history
    double maxHigh = 0;
    for (final p in data.prices) {
      final high = p.high ?? p.close ?? 0;
      if (high > maxHigh) maxHigh = high;
    }

    if (maxHigh <= 0) return null;

    // Check if current close is at or near 52-week high (within threshold)
    final threshold = maxHigh * (1 - RuleParams.week52NearThreshold);
    if (close >= threshold) {
      final isNewHigh = close >= maxHigh;
      return TriggeredReason(
        type: ReasonType.week52High,
        score: RuleScores.week52High,
        description: isNewHigh ? '創 52 週新高' : '接近 52 週新高',
        evidence: {
          'close': close,
          'week52High': maxHigh,
          'isNewHigh': isNewHigh,
        },
      );
    }

    return null;
  }
}

/// Rule: 52-Week Low Detection
/// Triggers when close price is at or near 52-week low
class Week52LowRule extends StockRule {
  const Week52LowRule();

  @override
  String get id => 'week_52_low';

  @override
  String get name => '52週新低';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.week52Days) return null;

    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    // Calculate 52-week low from price history
    double minLow = double.infinity;
    for (final p in data.prices) {
      final low = p.low ?? p.close ?? double.infinity;
      if (low > 0 && low < minLow) minLow = low;
    }

    if (minLow == double.infinity || minLow <= 0) return null;

    // Check if current close is at or near 52-week low (within threshold)
    final threshold = minLow * (1 + RuleParams.week52NearThreshold);
    if (close <= threshold) {
      final isNewLow = close <= minLow;
      return TriggeredReason(
        type: ReasonType.week52Low,
        score: RuleScores.week52Low,
        description: isNewLow ? '創 52 週新低' : '接近 52 週新低',
        evidence: {'close': close, 'week52Low': minLow, 'isNewLow': isNewLow},
      );
    }

    return null;
  }
}

/// Rule: MA Bullish Alignment (多頭排列)
/// Triggers when MA5 > MA10 > MA20 > MA60
class MAAlignmentBullishRule extends StockRule {
  const MAAlignmentBullishRule();

  @override
  String get id => 'ma_alignment_bullish';

  @override
  String get name => '多頭排列';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // Need at least 60 days of data
    if (data.prices.length < 60) return null;

    final ma5 = _calculateMA(data.prices, 5);
    final ma10 = _calculateMA(data.prices, 10);
    final ma20 = _calculateMA(data.prices, 20);
    final ma60 = _calculateMA(data.prices, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // Check bullish alignment: MA5 > MA10 > MA20 > MA60
    // Also check minimum separation
    const minSep = RuleParams.maMinSeparation;
    if (ma5 > ma10 * (1 + minSep) &&
        ma10 > ma20 * (1 + minSep) &&
        ma20 > ma60 * (1 + minSep)) {
      return TriggeredReason(
        type: ReasonType.maAlignmentBullish,
        score: RuleScores.maAlignmentBullish,
        description: '均線多頭排列 (5>10>20>60)',
        evidence: {'ma5': ma5, 'ma10': ma10, 'ma20': ma20, 'ma60': ma60},
      );
    }

    return null;
  }

  double? _calculateMA(List<dynamic> prices, int period) {
    if (prices.length < period) return null;
    double sum = 0;
    int count = 0;
    for (int i = prices.length - period; i < prices.length; i++) {
      final close = prices[i].close;
      if (close != null) {
        sum += close;
        count++;
      }
    }
    return count == period ? sum / count : null;
  }
}

/// Rule: MA Bearish Alignment (空頭排列)
/// Triggers when MA5 < MA10 < MA20 < MA60
class MAAlignmentBearishRule extends StockRule {
  const MAAlignmentBearishRule();

  @override
  String get id => 'ma_alignment_bearish';

  @override
  String get name => '空頭排列';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 60) return null;

    final ma5 = _calculateMA(data.prices, 5);
    final ma10 = _calculateMA(data.prices, 10);
    final ma20 = _calculateMA(data.prices, 20);
    final ma60 = _calculateMA(data.prices, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // Check bearish alignment: MA5 < MA10 < MA20 < MA60
    const minSep = RuleParams.maMinSeparation;
    if (ma5 < ma10 * (1 - minSep) &&
        ma10 < ma20 * (1 - minSep) &&
        ma20 < ma60 * (1 - minSep)) {
      return TriggeredReason(
        type: ReasonType.maAlignmentBearish,
        score: RuleScores.maAlignmentBearish,
        description: '均線空頭排列 (5<10<20<60)',
        evidence: {'ma5': ma5, 'ma10': ma10, 'ma20': ma20, 'ma60': ma60},
      );
    }

    return null;
  }

  double? _calculateMA(List<dynamic> prices, int period) {
    if (prices.length < period) return null;
    double sum = 0;
    int count = 0;
    for (int i = prices.length - period; i < prices.length; i++) {
      final close = prices[i].close;
      if (close != null) {
        sum += close;
        count++;
      }
    }
    return count == period ? sum / count : null;
  }
}

/// Rule: RSI Extreme Overbought
/// Triggers when RSI > 80
class RSIExtremeOverboughtRule extends StockRule {
  const RSIExtremeOverboughtRule();

  @override
  String get id => 'rsi_extreme_overbought';

  @override
  String get name => 'RSI極度超買';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.rsiPeriod + 1) return null;

    final rsi = _calculateRSI(data.prices, RuleParams.rsiPeriod);
    if (rsi == null) return null;

    if (rsi >= RuleParams.rsiExtremeOverbought) {
      return TriggeredReason(
        type: ReasonType.rsiExtremeOverbought,
        score: RuleScores.rsiExtremeOverboughtSignal,
        description: 'RSI 極度超買 (${rsi.toStringAsFixed(1)})',
        evidence: {'rsi': rsi, 'threshold': RuleParams.rsiExtremeOverbought},
      );
    }

    return null;
  }

  double? _calculateRSI(List<dynamic> prices, int period) {
    if (prices.length < period + 1) return null;

    double gains = 0;
    double losses = 0;

    // Calculate initial average gain/loss
    for (int i = prices.length - period; i < prices.length; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      if (change > 0) {
        gains += change;
      } else {
        losses += -change;
      }
    }

    final avgGain = gains / period;
    final avgLoss = losses / period;

    if (avgLoss == 0) return 100; // All gains, no losses

    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}

/// Rule: RSI Extreme Oversold
/// Triggers when RSI < 20
class RSIExtremeOversoldRule extends StockRule {
  const RSIExtremeOversoldRule();

  @override
  String get id => 'rsi_extreme_oversold';

  @override
  String get name => 'RSI極度超賣';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.rsiPeriod + 1) return null;

    final rsi = _calculateRSI(data.prices, RuleParams.rsiPeriod);
    if (rsi == null) return null;

    if (rsi <= RuleParams.rsiExtremeOversold) {
      return TriggeredReason(
        type: ReasonType.rsiExtremeOversold,
        score: RuleScores.rsiExtremeOversoldSignal,
        description: 'RSI 極度超賣 (${rsi.toStringAsFixed(1)})',
        evidence: {'rsi': rsi, 'threshold': RuleParams.rsiExtremeOversold},
      );
    }

    return null;
  }

  double? _calculateRSI(List<dynamic> prices, int period) {
    if (prices.length < period + 1) return null;

    double gains = 0;
    double losses = 0;

    for (int i = prices.length - period; i < prices.length; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      if (change > 0) {
        gains += change;
      } else {
        losses += -change;
      }
    }

    final avgGain = gains / period;
    final avgLoss = losses / period;

    if (avgLoss == 0) return 100;

    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}
