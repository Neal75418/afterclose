import 'dart:math';

/// 技術指標計算服務
///
/// 提供各種技術分析指標的計算方法，包含 SMA、EMA、RSI、KD、MACD、布林通道等
class TechnicalIndicatorService {
  /// 計算簡單移動平均線 (SMA)
  ///
  /// 回傳與輸入相同長度的列表，資料不足的位置為 null
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

  /// 計算指數移動平均線 (EMA)
  List<double?> calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty || period <= 0) return [];

    final result = <double?>[];
    final multiplier = 2 / (period + 1);

    // 第一個 EMA 使用 SMA 計算
    double? ema;
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else if (i == period - 1) {
        // 計算初始 SMA
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

  /// 計算相對強弱指標 (RSI)
  ///
  /// [period] 預設為 14 日
  List<double?> calculateRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period + 1) {
      return List.filled(prices.length, null);
    }

    final result = <double?>[];

    // 計算價格變動
    final changes = <double>[];
    for (int i = 1; i < prices.length; i++) {
      changes.add(prices[i] - prices[i - 1]);
    }

    // 第一個 RSI 需要 period + 1 個資料點
    for (int i = 0; i < period; i++) {
      result.add(null);
    }

    // 計算初始平均漲跌幅
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

    // 計算第一個 RSI
    // 邊界情況：若漲跌幅皆為 0，RSI 應為中性值 (50)
    double rsi;
    if (avgGain == 0 && avgLoss == 0) {
      rsi = 50.0; // 中性 - 無價格變動
    } else if (avgLoss == 0) {
      rsi = 100.0; // 全部上漲，無下跌
    } else {
      final rs = avgGain / avgLoss;
      rsi = 100 - (100 / (1 + rs));
    }
    result.add(rsi);

    // 使用平滑平均計算後續 RSI
    for (int i = period; i < changes.length; i++) {
      final change = changes[i];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      // 與初始 RSI 相同的邊界情況處理
      double subsequentRsi;
      if (avgGain == 0 && avgLoss == 0) {
        subsequentRsi = 50.0; // 中性
      } else if (avgLoss == 0) {
        subsequentRsi = 100.0; // 全部上漲
      } else {
        final rs = avgGain / avgLoss;
        subsequentRsi = 100 - (100 / (1 + rs));
      }
      result.add(subsequentRsi);
    }

    return result;
  }

  /// 計算隨機震盪指標 (KD)
  ///
  /// [kPeriod] K 值週期，預設 9 日
  /// [dPeriod] D 值週期，預設 3 日
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

    // 計算 %K
    for (int i = 0; i < length; i++) {
      if (i < kPeriod - 1) {
        kValues.add(null);
      } else {
        // 找出週期內最高價與最低價
        double highestHigh = highs[i];
        double lowestLow = lows[i];
        for (int j = i - kPeriod + 1; j <= i; j++) {
          if (highs[j] > highestHigh) highestHigh = highs[j];
          if (lows[j] < lowestLow) lowestLow = lows[j];
        }

        final range = highestHigh - lowestLow;
        if (range == 0) {
          kValues.add(50.0); // 無價格區間時為中性值
        } else {
          kValues.add(((closes[i] - lowestLow) / range) * 100);
        }
      }
    }

    // 計算 %D（%K 的 SMA）
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

  /// 計算 MACD 指標
  ///
  /// [fastPeriod] 快線週期，預設 12 日
  /// [slowPeriod] 慢線週期，預設 26 日
  /// [signalPeriod] 訊號線週期，預設 9 日
  ({List<double?> macd, List<double?> signal, List<double?> histogram})
  calculateMACD(
    List<double> prices, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final fastEMA = calculateEMA(prices, fastPeriod);
    final slowEMA = calculateEMA(prices, slowPeriod);

    // MACD 線 = 快線 EMA - 慢線 EMA
    final macdLine = <double?>[];
    for (int i = 0; i < prices.length; i++) {
      if (fastEMA[i] == null || slowEMA[i] == null) {
        macdLine.add(null);
      } else {
        macdLine.add(fastEMA[i]! - slowEMA[i]!);
      }
    }

    // 訊號線 = MACD 線的 EMA
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

    // 柱狀圖 = MACD 線 - 訊號線
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

  /// 計算布林通道
  ///
  /// [period] 週期，預設 20 日
  /// [stdDevMultiplier] 標準差倍數，預設 2 倍
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
        // 計算標準差
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

  /// 計算成交量移動平均線
  List<double?> calculateVolumeMA(List<double> volumes, int period) {
    return calculateSMA(volumes, period);
  }
}
