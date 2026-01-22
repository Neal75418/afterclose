import 'package:afterclose/core/constants/rule_params.dart';

import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

class VolumeSpikeRule extends StockRule {
  const VolumeSpikeRule();

  @override
  String get id => 'volume_spike';

  @override
  String get name => '放量異常';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < RuleParams.volMa + 1) return null;

    final today = data.prices.last;
    final todayVolume = today.volume;

    if (todayVolume == null || todayVolume <= 0) return null;

    // Check minimum price change (+/- 1.5%)
    // Volume spike without price action is less significant
    final todayClose = today.close;
    final yesterday = data.prices[data.prices.length - 2];
    final yesterdayClose = yesterday.close;

    if (todayClose != null && yesterdayClose != null && yesterdayClose > 0) {
      final pctChange = ((todayClose - yesterdayClose) / yesterdayClose).abs();
      if (pctChange < RuleParams.minPriceChangeForVolume) return null;
    }

    // Calculate MA20 volume
    final recentVolumes = data.prices.reversed
        .skip(1) // skip today
        .take(RuleParams.volMa)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.isEmpty) return null;

    final avgVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    // Check threshold (4x average)
    if (avgVolume > 0 &&
        todayVolume >= avgVolume * RuleParams.volumeSpikeMult) {
      return TriggeredReason(
        type: ReasonType.volumeSpike,
        score: RuleScores.volumeSpike,
        description: '成交量異常放大 ${RuleParams.volumeSpikeMult} 倍以上',
        evidence: {
          'volume': todayVolume,
          'avgVolume': avgVolume,
          'multiple': todayVolume / avgVolume,
        },
      );
    }

    return null;
  }
}

class PriceSpikeRule extends StockRule {
  const PriceSpikeRule();

  @override
  String get id => 'price_spike';

  @override
  String get name => '價格異動';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];

    final todayClose = today.close;
    final yesterdayClose = yesterday.close;

    if (todayClose == null || yesterdayClose == null || yesterdayClose <= 0)
      return null;

    final pctChange = ((todayClose - yesterdayClose) / yesterdayClose) * 100;

    // Check threshold (6%)
    if (pctChange.abs() >= RuleParams.priceSpikePercent) {
      return TriggeredReason(
        type: ReasonType.priceSpike,
        score: RuleScores.priceSpike,
        description: '股價單日漲跌幅超過 ${RuleParams.priceSpikePercent}%',
        evidence: {
          'pctChange': pctChange,
          'close': todayClose,
          'prevClose': yesterdayClose,
        },
      );
    }

    return null;
  }
}
