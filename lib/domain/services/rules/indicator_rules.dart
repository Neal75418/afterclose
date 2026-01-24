import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 第 3 階段：技術訊號規則
// ==========================================

/// 規則：52 週新高偵測
///
/// 當收盤價處於或接近 52 週高點時觸發
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

    // 從「過去」的價格歷史計算 52 週高點（排除今日）
    // 避免前瞻偏差（每次新高都會觸發）
    double maxHigh = 0;
    for (int i = 0; i < data.prices.length - 1; i++) {
      final p = data.prices[i];
      final high = p.high ?? p.close ?? 0;
      if (high > maxHigh) maxHigh = high;
    }

    if (maxHigh <= 0) return null;

    // 檢查當前收盤是否處於或接近 52 週高點（在門檻範圍內）
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

/// 規則：52 週新低偵測
///
/// 當收盤價處於或接近 52 週低點時觸發
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

    // 從「過去」的價格歷史計算 52 週低點（排除今日）
    // 避免前瞻偏差
    double minLow = double.infinity;
    for (int i = 0; i < data.prices.length - 1; i++) {
      final p = data.prices[i];
      final low = p.low ?? p.close ?? double.infinity;
      if (low > 0 && low < minLow) minLow = low;
    }

    if (minLow == double.infinity || minLow <= 0) return null;

    // 檢查當前收盤是否處於或接近 52 週低點（在門檻範圍內）
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

/// 規則：均線多頭排列
///
/// 當 MA5 > MA10 > MA20 > MA60 時觸發
class MAAlignmentBullishRule extends StockRule {
  const MAAlignmentBullishRule();

  @override
  String get id => 'ma_alignment_bullish';

  @override
  String get name => '多頭排列';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // 至少需要 60 天資料
    if (data.prices.length < 60) return null;

    final ma5 = _calculateMA(data.prices, 5);
    final ma10 = _calculateMA(data.prices, 10);
    final ma20 = _calculateMA(data.prices, 20);
    final ma60 = _calculateMA(data.prices, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // 檢查多頭排列：MA5 > MA10 > MA20 > MA60
    // 並檢查最小間距
    const minSep = RuleParams.maMinSeparation;
    if (ma5 > ma10 * (1 + minSep) &&
        ma10 > ma20 * (1 + minSep) &&
        ma20 > ma60 * (1 + minSep)) {
      // 過濾條件：收盤 > MA5 且乖離率 < 5%
      // 備註：台股常有「量縮上漲」現象
      // 因此將成交量要求從 2.0 倍放寬至 1.3 倍
      final today = data.prices.last;
      final close = today.close;
      final vol = today.volume;
      if (close == null || vol == null) return null;

      if (close <= ma5) return null;
      if ((close - ma5) / ma5 >= 0.05) return null; // 離 MA5 過遠（從 3% 放寬至 5%）

      double volSum = 0;
      int count = 0;
      for (
        int i = data.prices.length - 1;
        i >= 0 && i >= data.prices.length - 20;
        i--
      ) {
        if (data.prices[i].volume != null) {
          volSum += data.prices[i].volume!;
          count++;
        }
      }
      final volMA20 = count > 0 ? volSum / count : 0;
      // 放寬：1.3 倍成交量（原 2.0 倍）- 台股常有低量反彈
      if (vol <= volMA20 * 1.3) return null;

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

/// 規則：均線空頭排列
///
/// 當 MA5 < MA10 < MA20 < MA60 時觸發
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

    // 檢查空頭排列：MA5 < MA10 < MA20 < MA60
    const minSep = RuleParams.maMinSeparation;
    if (ma5 < ma10 * (1 - minSep) &&
        ma10 < ma20 * (1 - minSep) &&
        ma20 < ma60 * (1 - minSep)) {
      // 過濾條件：收盤 < MA5 且乖離率 > -5% 且成交量 > MA20
      final today = data.prices.last;
      final close = today.close;
      final vol = today.volume;
      if (close == null || vol == null) return null;

      if (close >= ma5) return null;
      if ((close - ma5) / ma5 <= -0.05) return null; // 離 MA5 過遠（超賣）

      double volSum = 0;
      int count = 0;
      for (
        int i = data.prices.length - 1;
        i >= 0 && i >= data.prices.length - 20;
        i--
      ) {
        if (data.prices[i].volume != null) {
          volSum += data.prices[i].volume!;
          count++;
        }
      }
      final volMA20 = count > 0 ? volSum / count : 0;
      if (vol <= volMA20) return null;

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

/// 規則：RSI 極度超買
///
/// 當 RSI > 80 時觸發
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

  /// 使用 Wilder's 平滑法（EMA 方式）計算 RSI
  ///
  /// 此方法對台股快速波動提供更靈敏的訊號
  double? _calculateRSI(List<dynamic> prices, int period) {
    // 至少需要 period + 1 天資料以進行初始計算與平滑
    if (prices.length < period + 1) return null;

    // 步驟 1：計算初始平均漲跌幅（前 'period' 個變化）
    double initialGains = 0;
    double initialLosses = 0;
    int validCount = 0;

    final startIdx = prices.length - period - 1;
    for (int i = startIdx + 1; i <= startIdx + period; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      if (change > 0) {
        initialGains += change;
      } else {
        initialLosses += -change;
      }
      validCount++;
    }

    if (validCount < period ~/ 2) return null; // 有效資料不足

    double avgGain = initialGains / period;
    double avgLoss = initialLosses / period;

    // 步驟 2：對剩餘資料點套用 Wilder's 平滑
    // 公式：avgGain = (prevAvgGain * (period - 1) + currentGain) / period
    for (int i = startIdx + period + 1; i < prices.length; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      final currentGain = change > 0 ? change : 0.0;
      final currentLoss = change < 0 ? -change : 0.0;

      // Wilder's 平滑（指數移動平均）
      avgGain = (avgGain * (period - 1) + currentGain) / period;
      avgLoss = (avgLoss * (period - 1) + currentLoss) / period;
    }

    if (avgLoss == 0) return 100; // 全為上漲，無下跌

    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}

/// 規則：RSI 極度超賣
///
/// 當 RSI < 20 時觸發
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

  /// 使用 Wilder's 平滑法計算 RSI
  double? _calculateRSI(List<dynamic> prices, int period) {
    if (prices.length < period + 1) return null;

    // 步驟 1：計算初始平均漲跌幅
    double initialGains = 0;
    double initialLosses = 0;
    int validCount = 0;

    final startIdx = prices.length - period - 1;
    for (int i = startIdx + 1; i <= startIdx + period; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      if (change > 0) {
        initialGains += change;
      } else {
        initialLosses += -change;
      }
      validCount++;
    }

    if (validCount < period ~/ 2) return null;

    double avgGain = initialGains / period;
    double avgLoss = initialLosses / period;

    // 步驟 2：對剩餘資料點套用 Wilder's 平滑
    for (int i = startIdx + period + 1; i < prices.length; i++) {
      final current = prices[i].close;
      final previous = prices[i - 1].close;
      if (current == null || previous == null) continue;

      final change = current - previous;
      final currentGain = change > 0 ? change : 0.0;
      final currentLoss = change < 0 ? -change : 0.0;

      avgGain = (avgGain * (period - 1) + currentGain) / period;
      avgLoss = (avgLoss * (period - 1) + currentLoss) / period;
    }

    if (avgLoss == 0) return 100;

    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}

/// 規則：KD 黃金交叉
///
/// 當 K 線向上穿越 D 線時觸發，最佳情況為超賣區
class KDGoldenCrossRule extends StockRule {
  const KDGoldenCrossRule();

  @override
  String get id => 'kd_golden_cross';

  @override
  String get name => 'KD 黃金交叉';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final ind = context.indicators;
    if (ind == null ||
        ind.kdK == null ||
        ind.kdD == null ||
        ind.prevKdK == null ||
        ind.prevKdD == null) {
      return null;
    }

    final k = ind.kdK!;
    final d = ind.kdD!;
    final prevK = ind.prevKdK!;
    final prevD = ind.prevKdD!;

    // 黃金交叉：昨日 K < D，今日 K > D
    if (prevK < prevD && k > d) {
      // 過濾 1：僅在低檔區觸發（K < 30）
      if (prevK >= 30.0) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 過濾掉低量弱反彈
      if (data.prices.length >= 5) {
        final todayVol = data.prices.last.volume;
        if (todayVol != null) {
          // Calculate 5-day volume MA (including today)
          double volSum = 0;
          int count = 0;
          for (
            var i = data.prices.length - 1;
            i >= data.prices.length - 5;
            i--
          ) {
            final v = data.prices[i].volume;
            if (v != null) {
              volSum += v;
              count++;
            }
          }
          if (count > 0) {
            final volMA5 = volSum / count;
            // 若今日成交量未超過均值則跳過
            if (todayVol <= volMA5) return null;
          }
        }
      }

      // 過濾 3：價格強度（漲幅 > 1%）
      // 確認黃金交叉有實際價格動能支撐
      if (data.prices.length >= 2) {
        final today = data.prices.last;
        final prev = data.prices[data.prices.length - 2];
        if (today.close != null && prev.close != null && prev.close! > 0) {
          final changePct = (today.close! - prev.close!) / prev.close!;
          if (changePct < 0.01) return null; // 漲幅不足 1%
        }
      }

      final isOversold = prevK < RuleParams.kdOversold;

      return TriggeredReason(
        type: ReasonType.kdGoldenCross,
        score: RuleScores.kdGoldenCross,
        description: isOversold ? '低檔 KD 黃金交叉 (量增價漲)' : 'KD 黃金交叉 (低檔量增價漲)',
        evidence: {'k': k, 'd': d, 'prevK': prevK, 'prevD': prevD},
      );
    }

    return null;
  }
}

/// 規則：KD 死亡交叉
class KDDeathCrossRule extends StockRule {
  const KDDeathCrossRule();

  @override
  String get id => 'kd_death_cross';

  @override
  String get name => 'KD 死亡交叉';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final ind = context.indicators;
    if (ind == null ||
        ind.kdK == null ||
        ind.kdD == null ||
        ind.prevKdK == null ||
        ind.prevKdD == null) {
      return null;
    }

    final k = ind.kdK!;
    final d = ind.kdD!;
    final prevK = ind.prevKdK!;
    final prevD = ind.prevKdD!;

    // 死亡交叉：昨日 K > D，今日 K < D
    if (prevK > prevD && k < d) {
      // 過濾 1：僅在高檔區觸發（K > 70）
      if (prevK <= 70.0) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 確認有賣壓（量增下跌）
      if (data.prices.length >= 5) {
        final todayVol = data.prices.last.volume;
        if (todayVol != null) {
          double volSum = 0;
          int count = 0;
          for (
            var i = data.prices.length - 1;
            i >= data.prices.length - 5;
            i--
          ) {
            final v = data.prices[i].volume;
            if (v != null) {
              volSum += v;
              count++;
            }
          }
          if (count > 0) {
            final volMA5 = volSum / count;
            // 若今日成交量未超過均值則跳過
            if (todayVol <= volMA5) return null;
          }
        }
      }

      final isOverbought = prevK > RuleParams.kdOverbought;

      return TriggeredReason(
        type: ReasonType.kdDeathCross,
        score: RuleScores.kdDeathCross,
        description: isOverbought ? '高檔 KD 死亡交叉 (量增)' : 'KD 死亡交叉 (高檔量增)',
        evidence: {'k': k, 'd': d, 'prevK': prevK, 'prevD': prevD},
      );
    }
    return null;
  }
}
