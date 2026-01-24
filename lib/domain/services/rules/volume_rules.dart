import 'package:afterclose/core/constants/rule_params.dart';

import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

/// 規則：放量異常
///
/// 當成交量超過均量 N 倍且伴隨價格變動時觸發
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

    // 檢查最小價格變動（+/- 1.5%）
    // 單純放量無價格配合的意義較低
    final todayClose = today.close;
    final yesterday = data.prices[data.prices.length - 2];
    final yesterdayClose = yesterday.close;

    if (todayClose != null && yesterdayClose != null && yesterdayClose > 0) {
      final pctChange = ((todayClose - yesterdayClose) / yesterdayClose).abs();
      if (pctChange < RuleParams.minPriceChangeForVolume) return null;
    }

    // 計算 MA20 成交量並處理停牌日
    // 取近 20 日，過濾掉零成交量日（停牌）
    final recentVolumes = data.prices.reversed
        .skip(1) // skip today
        .take(RuleParams.volMa)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0) // 過濾停牌日（成交量 = 0）
        .toList();

    // 要求至少 80% 有效交易日（20 日中至少 16 日）
    // 避免復牌後因基期過低產生假訊號
    final minValidDays = (RuleParams.volMa * 0.8).floor();
    if (recentVolumes.length < minValidDays) return null;

    final avgVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    // 檢查門檻（均量的 4 倍）
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
          'validDays': recentVolumes.length,
        },
      );
    }

    return null;
  }
}

/// 規則：價格異動
///
/// 當單日價格漲跌幅超過門檻時觸發
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

    if (todayClose == null || yesterdayClose == null || yesterdayClose <= 0) {
      return null;
    }

    final pctChange = ((todayClose - yesterdayClose) / yesterdayClose) * 100;

    // 檢查門檻（6%）
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
