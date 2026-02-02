import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 第 5 階段：價量背離規則
// ==========================================

/// 規則：價漲量縮
///
/// 價格上漲但成交量萎縮 - 警示訊號
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

    if (todayClose == null ||
        pastClose == null ||
        pastClose == 0 ||
        todayVolume == null) {
      return null;
    }

    // 計算回溯期間的平均成交量
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

    // 檢查背離
    final priceChange = (todayClose - pastClose) / pastClose * 100;
    final volumeChange = (todayVolume - avgVolume) / avgVolume * 100;

    // 價格上漲但成交量下降
    // v0.1.2：大幅放寬門檻，解決 0 觸發問題
    // 原先：1.5% 價格 / -15% 成交量（仍過於嚴格）
    // 目前：1.0% 價格 / -10% 成交量
    if (priceChange >= RuleParams.divergencePriceThreshold &&
        volumeChange <= -RuleParams.divergenceVolumeThreshold) {
      AppLogger.debug(
        'PriceVolumeBullishDivergence',
        '${data.symbol}: 價漲${priceChange.toStringAsFixed(1)}%, 量縮${volumeChange.toStringAsFixed(1)}%',
      );
      return TriggeredReason(
        type: ReasonType.priceVolumeBullishDivergence,
        score: RuleScores.priceVolumeBullishDivergence,
        description:
            '價漲量縮：價格上漲${priceChange.toStringAsFixed(1)}%，成交量萎縮${volumeChange.abs().toStringAsFixed(0)}%',
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

/// 規則：價跌量增
///
/// 價格下跌且成交量增加 - 恐慌訊號
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

    if (todayClose == null ||
        pastClose == null ||
        pastClose == 0 ||
        todayVolume == null) {
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

    // 價格下跌且成交量上升
    // v0.1.2：大幅放寬門檻，解決 0 觸發問題
    // 原先：-1.5% 價格 / +15% 成交量（仍過於嚴格）
    // 目前：-1.0% 價格 / +10% 成交量
    if (priceChange <= -RuleParams.divergencePriceThreshold &&
        volumeChange >= RuleParams.divergenceVolumeThreshold) {
      AppLogger.debug(
        'PriceVolumeBearishDivergence',
        '${data.symbol}: 價跌${priceChange.toStringAsFixed(1)}%, 量增${volumeChange.toStringAsFixed(1)}%',
      );
      return TriggeredReason(
        type: ReasonType.priceVolumeBearishDivergence,
        score: RuleScores.priceVolumeBearishDivergence,
        description:
            '價跌量增：價格下跌${priceChange.abs().toStringAsFixed(1)}%，成交量放大${volumeChange.toStringAsFixed(0)}%',
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

/// 規則：高檔爆量
///
/// 價格處於高檔且成交量暴增
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

    // 計算 60 日區間
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
    final position = (close - minLow) / range; // 0 = 低點, 1 = 高點
    final avgVolume = volumeSum / volumeCount;

    // 高檔位置（前 15%）且成交量暴增（4 倍）
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

/// 規則：低檔吸籌
///
/// 價格處於低檔且成交量萎縮 - 可能正在吸籌
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

    // 低檔位置（後 25%）且成交量低迷（低於平均的 60%）
    // v0.1.1：放寬門檻，解決 0 觸發問題
    if (position <= RuleParams.lowPositionThreshold &&
        volume < avgVolume * RuleParams.lowAccumulationVolumeRatio) {
      AppLogger.debug(
        'LowVolumeAccumulation',
        '${data.symbol}: 位置=${(position * 100).toStringAsFixed(1)}%, 量比=${(volume / avgVolume * 100).toStringAsFixed(0)}%',
      );
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
