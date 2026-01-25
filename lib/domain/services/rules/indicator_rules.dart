import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

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
    // 診斷：資料不足時記錄
    if (data.prices.length < RuleParams.week52Days) {
      if (data.prices.length >= 200) {
        AppLogger.debug(
          'Week52High',
          '${data.symbol}: 資料不足 (${data.prices.length}/${RuleParams.week52Days})',
        );
      }
      return null;
    }

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
      AppLogger.debug(
        'Week52High',
        '${data.symbol}: 收盤=${close.toStringAsFixed(2)}, 52週高=${maxHigh.toStringAsFixed(2)}, 新高=$isNewHigh',
      );
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
    // 診斷：資料不足時記錄
    if (data.prices.length < RuleParams.week52Days) {
      if (data.prices.length >= 200) {
        AppLogger.debug(
          'Week52Low',
          '${data.symbol}: 資料不足 (${data.prices.length}/${RuleParams.week52Days})',
        );
      }
      return null;
    }

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
      AppLogger.debug(
        'Week52Low',
        '${data.symbol}: 收盤=${close.toStringAsFixed(2)}, 52週低=${minLow.toStringAsFixed(2)}, 新低=$isNewLow',
      );
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
    // 至少需要最大均線週期的資料
    final maxPeriod = RuleParams.maAlignmentPeriods.reduce(
      (a, b) => a > b ? a : b,
    );
    if (data.prices.length < maxPeriod) return null;

    final ma5 = TechnicalIndicatorService.latestSMA(data.prices, 5);
    final ma10 = TechnicalIndicatorService.latestSMA(data.prices, 10);
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final ma60 = TechnicalIndicatorService.latestSMA(data.prices, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // 檢查多頭排列：MA5 > MA10 > MA20 > MA60
    // 並檢查最小間距
    const minSep = RuleParams.maMinSeparation;
    if (ma5 > ma10 * (1 + minSep) &&
        ma10 > ma20 * (1 + minSep) &&
        ma20 > ma60 * (1 + minSep)) {
      // 過濾條件：收盤 > MA5 且乖離率不超過門檻
      // 備註：台股常有「量縮上漲」現象
      final today = data.prices.last;
      final close = today.close;
      final vol = today.volume;
      if (close == null || vol == null) return null;

      if (close <= ma5) return null;
      if ((close - ma5) / ma5 >= RuleParams.maDeviationThreshold) return null;

      final volResult = TechnicalIndicatorService.latestVolumeMA(
        data.prices,
        20,
      );
      final volMA20 = volResult.volumeMA ?? 0;
      if (vol <= volMA20 * RuleParams.maAlignmentVolumeMultiplier) return null;

      return TriggeredReason(
        type: ReasonType.maAlignmentBullish,
        score: RuleScores.maAlignmentBullish,
        description: '均線多頭排列 (5>10>20>60)',
        evidence: {'ma5': ma5, 'ma10': ma10, 'ma20': ma20, 'ma60': ma60},
      );
    }

    return null;
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
    // 至少需要最大均線週期的資料
    final maxPeriod = RuleParams.maAlignmentPeriods.reduce(
      (a, b) => a > b ? a : b,
    );
    if (data.prices.length < maxPeriod) return null;

    final ma5 = TechnicalIndicatorService.latestSMA(data.prices, 5);
    final ma10 = TechnicalIndicatorService.latestSMA(data.prices, 10);
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final ma60 = TechnicalIndicatorService.latestSMA(data.prices, 60);

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // 檢查空頭排列：MA5 < MA10 < MA20 < MA60
    const minSep = RuleParams.maMinSeparation;
    if (ma5 < ma10 * (1 - minSep) &&
        ma10 < ma20 * (1 - minSep) &&
        ma20 < ma60 * (1 - minSep)) {
      // 過濾條件：收盤 < MA5 且乖離率不超過門檻 且成交量 > MA20
      final today = data.prices.last;
      final close = today.close;
      final vol = today.volume;
      if (close == null || vol == null) return null;

      if (close >= ma5) return null;
      if ((close - ma5) / ma5 <= -RuleParams.maDeviationThreshold) return null;

      final volResult = TechnicalIndicatorService.latestVolumeMA(
        data.prices,
        20,
      );
      final volMA20 = volResult.volumeMA ?? 0;
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

    final rsi = TechnicalIndicatorService.latestRSI(
      data.prices,
      period: RuleParams.rsiPeriod,
    );
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

    final rsi = TechnicalIndicatorService.latestRSI(
      data.prices,
      period: RuleParams.rsiPeriod,
    );
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
      // 過濾 1：僅在低檔區觸發
      if (prevK >= RuleParams.kdGoldenCrossZone) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 使用 PriceCalculator 統一計算，排除今日以正確比較
      if (!PriceCalculator.isVolumeAboveAverage(data.prices, days: 5)) {
        return null;
      }

      // 過濾 3：價格強度
      // 確認黃金交叉有實際價格動能支撐
      if (data.prices.length >= 2) {
        final today = data.prices.last;
        final prev = data.prices[data.prices.length - 2];
        if (today.close != null && prev.close != null && prev.close! > 0) {
          final changePct = (today.close! - prev.close!) / prev.close!;
          if (changePct < RuleParams.kdCrossPriceChangeThreshold) return null;
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
      // 過濾 1：僅在高檔區觸發
      if (prevK <= RuleParams.kdDeathCrossZone) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 使用 PriceCalculator 統一計算，排除今日以正確比較
      if (!PriceCalculator.isVolumeAboveAverage(data.prices, days: 5)) {
        return null;
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
