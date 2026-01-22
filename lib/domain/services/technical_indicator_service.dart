import 'dart:math';

/// Service for calculating technical indicators
class TechnicalIndicatorService {
  /// Calculate Simple Moving Average (SMA)
  /// Returns list with same length as input, with null for insufficient data
  List<double?> calculateSMA(List<double> prices, int period) {
    if (prices.isEmpty || period <= 0) return [];

    final result = <double?>[];

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += prices[j];
        }
        result.add(sum / period);
      }
    }

    return result;
  }

  /// Calculate Exponential Moving Average (EMA)
  List<double?> calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty || period <= 0) return [];

    final result = <double?>[];
    final multiplier = 2 / (period + 1);

    // First EMA is SMA
    double? ema;
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else if (i == period - 1) {
        // Calculate initial SMA
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += prices[j];
        }
        ema = sum / period;
        result.add(ema);
      } else {
        // EMA = (Close - EMA(prev)) * multiplier + EMA(prev)
        ema = (prices[i] - ema!) * multiplier + ema;
        result.add(ema);
      }
    }

    return result;
  }

  /// Calculate Relative Strength Index (RSI)
  /// Default period is 14
  List<double?> calculateRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period + 1) {
      return List.filled(prices.length, null);
    }

    final result = <double?>[];

    // Calculate price changes
    final changes = <double>[];
    for (int i = 1; i < prices.length; i++) {
      changes.add(prices[i] - prices[i - 1]);
    }

    // First RSI needs period + 1 data points
    for (int i = 0; i < period; i++) {
      result.add(null);
    }

    // Calculate initial average gain and loss
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 0; i < period; i++) {
      if (changes[i] > 0) {
        avgGain += changes[i];
      } else {
        avgLoss += changes[i].abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    // Calculate first RSI
    // Edge case: if both avgGain and avgLoss are 0, RSI should be neutral (50)
    double rsi;
    if (avgGain == 0 && avgLoss == 0) {
      rsi = 50.0; // Neutral - no price movement
    } else if (avgLoss == 0) {
      rsi = 100.0; // All gains, no losses
    } else {
      final rs = avgGain / avgLoss;
      rsi = 100 - (100 / (1 + rs));
    }
    result.add(rsi);

    // Calculate subsequent RSI using smoothed averages
    for (int i = period; i < changes.length; i++) {
      final change = changes[i];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      // Same edge case handling as initial RSI
      double subsequentRsi;
      if (avgGain == 0 && avgLoss == 0) {
        subsequentRsi = 50.0; // Neutral
      } else if (avgLoss == 0) {
        subsequentRsi = 100.0; // All gains
      } else {
        final rs = avgGain / avgLoss;
        subsequentRsi = 100 - (100 / (1 + rs));
      }
      result.add(subsequentRsi);
    }

    return result;
  }

  /// Calculate Stochastic Oscillator (KD)
  /// Default periods: K=9, D=3
  ({List<double?> k, List<double?> d}) calculateKD(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int kPeriod = 9,
    int dPeriod = 3,
  }) {
    if (highs.length != lows.length || lows.length != closes.length) {
      return (k: [], d: []);
    }

    final length = closes.length;
    final kValues = <double?>[];
    final dValues = <double?>[];

    // Calculate %K
    for (int i = 0; i < length; i++) {
      if (i < kPeriod - 1) {
        kValues.add(null);
      } else {
        // Find highest high and lowest low in period
        double highestHigh = highs[i];
        double lowestLow = lows[i];
        for (int j = i - kPeriod + 1; j <= i; j++) {
          if (highs[j] > highestHigh) highestHigh = highs[j];
          if (lows[j] < lowestLow) lowestLow = lows[j];
        }

        final range = highestHigh - lowestLow;
        if (range == 0) {
          kValues.add(50.0); // Neutral when no range
        } else {
          kValues.add(((closes[i] - lowestLow) / range) * 100);
        }
      }
    }

    // Calculate %D (SMA of %K)
    for (int i = 0; i < length; i++) {
      if (i < kPeriod - 1 + dPeriod - 1 || kValues[i] == null) {
        dValues.add(null);
      } else {
        double sum = 0;
        int count = 0;
        for (int j = i - dPeriod + 1; j <= i; j++) {
          if (kValues[j] != null) {
            sum += kValues[j]!;
            count++;
          }
        }
        dValues.add(count > 0 ? sum / count : null);
      }
    }

    return (k: kValues, d: dValues);
  }

  /// Calculate MACD (Moving Average Convergence Divergence)
  /// Default periods: fast=12, slow=26, signal=9
  ({List<double?> macd, List<double?> signal, List<double?> histogram})
  calculateMACD(
    List<double> prices, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final fastEMA = calculateEMA(prices, fastPeriod);
    final slowEMA = calculateEMA(prices, slowPeriod);

    // MACD Line = Fast EMA - Slow EMA
    final macdLine = <double?>[];
    for (int i = 0; i < prices.length; i++) {
      if (fastEMA[i] == null || slowEMA[i] == null) {
        macdLine.add(null);
      } else {
        macdLine.add(fastEMA[i]! - slowEMA[i]!);
      }
    }

    // Signal Line = EMA of MACD Line
    final nonNullMacd = macdLine.whereType<double>().toList();
    final signalEMA = calculateEMA(nonNullMacd, signalPeriod);

    final signalLine = <double?>[];
    int signalIndex = 0;
    for (int i = 0; i < prices.length; i++) {
      if (macdLine[i] == null) {
        signalLine.add(null);
      } else {
        if (signalIndex < signalEMA.length) {
          signalLine.add(signalEMA[signalIndex]);
          signalIndex++;
        } else {
          signalLine.add(null);
        }
      }
    }

    // Histogram = MACD Line - Signal Line
    final histogram = <double?>[];
    for (int i = 0; i < prices.length; i++) {
      if (macdLine[i] == null || signalLine[i] == null) {
        histogram.add(null);
      } else {
        histogram.add(macdLine[i]! - signalLine[i]!);
      }
    }

    return (macd: macdLine, signal: signalLine, histogram: histogram);
  }

  /// Calculate Bollinger Bands
  /// Default: 20 period SMA with 2 standard deviations
  ({List<double?> upper, List<double?> middle, List<double?> lower})
  calculateBollingerBands(
    List<double> prices, {
    int period = 20,
    double stdDevMultiplier = 2.0,
  }) {
    final middle = calculateSMA(prices, period);
    final upper = <double?>[];
    final lower = <double?>[];

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1 || middle[i] == null) {
        upper.add(null);
        lower.add(null);
      } else {
        // Calculate standard deviation
        double sumSquares = 0;
        for (int j = i - period + 1; j <= i; j++) {
          final diff = prices[j] - middle[i]!;
          sumSquares += diff * diff;
        }
        final stdDev = sqrt(sumSquares / period);

        upper.add(middle[i]! + (stdDevMultiplier * stdDev));
        lower.add(middle[i]! - (stdDevMultiplier * stdDev));
      }
    }

    return (upper: upper, middle: middle, lower: lower);
  }

  /// Calculate Volume Moving Average
  List<double?> calculateVolumeMA(List<double> volumes, int period) {
    return calculateSMA(volumes, period);
  }
}
