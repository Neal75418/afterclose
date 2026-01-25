import 'package:afterclose/core/constants/rule_params.dart';
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

    // 價格上漲（> 2.0%）但成交量下降（< -20%）
    // 針對台股放寬門檻，因背離常較早出現
    // 原先：5% 價格 / -40% 成交量（過於嚴格，觸發率 < 2%）
    // 目前：2% 價格 / -20% 成交量（更符合台股實際情況）
    if (priceChange >= 2.0 && volumeChange <= -20.0) {
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

    // 價格下跌（< -2.0%）且成交量上升（> 20%）
    // 放寬門檻：台股常在較小跌幅時出現恐慌賣壓
    // 原先：-3% 價格 / +30% 成交量
    // 目前：-2% 價格 / +20% 成交量
    if (priceChange <= -2.0 && volumeChange >= 20.0) {
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

    // 低檔位置（後 15%）且成交量低迷（低於平均的 50%）
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
