/// 掃描篩選器的詮釋資料 - 提供條件說明與資料需求
///
/// 此檔案包含每個掃描篩選器的詳細資訊，
/// 協助使用者了解篩選器可能回傳空結果的原因。
library;

import 'package:afterclose/domain/models/scan_models.dart';

/// 篩選器所需資料類型
enum DataRequirement {
  /// 基本每日價格資料（永遠可用）
  dailyPrice('dataReq.dailyPrice'),

  /// 價格歷史（20 天以上）
  priceHistory20('dataReq.priceHistory20'),

  /// 價格歷史（60 天以上，用於 MA60）
  priceHistory60('dataReq.priceHistory60'),

  /// 價格歷史（250 天，用於 52 週高低點）
  priceHistory250('dataReq.priceHistory250'),

  /// 法人買賣資料（三大法人）
  institutional('dataReq.institutional'),

  /// 外資持股比例
  foreignShareholding('dataReq.foreignShareholding'),

  /// 當沖比例
  dayTrading('dataReq.dayTrading'),

  /// 月營收資料
  monthlyRevenue('dataReq.monthlyRevenue'),

  /// 估值資料（本益比、股價淨值比、殖利率）
  valuation('dataReq.valuation'),

  /// 股權分散表（TDCC 集保中心）
  holdingDistribution('dataReq.holdingDistribution'),

  /// 新聞資料
  news('dataReq.news');

  const DataRequirement(this.labelKey);
  final String labelKey;
}

/// 掃描篩選器的詮釋資料
class FilterMetadata {
  const FilterMetadata({
    required this.conditionKey,
    required this.dataRequirements,
    this.thresholdInfo,
  });

  /// 條件說明的 i18n 鍵
  final String conditionKey;

  /// 此篩選器所需的資料類型
  final List<DataRequirement> dataRequirements;

  /// 門檻資訊 i18n key（由 UI 端呼叫 `.tr()` 翻譯）
  final String? thresholdInfo;
}

/// 取得 ScanFilter 詮釋資料的擴充方法
extension ScanFilterMetadataExtension on ScanFilter {
  /// 取得此篩選器的詮釋資料
  FilterMetadata get metadata => _filterMetadataMap[this] ?? _defaultMetadata;

  static const FilterMetadata _defaultMetadata = FilterMetadata(
    conditionKey: 'filterMeta.default',
    dataRequirements: [DataRequirement.dailyPrice],
  );
}

/// ScanFilter 對應詮釋資料的映射表
const Map<ScanFilter, FilterMetadata> _filterMetadataMap = {
  // 全部
  ScanFilter.all: FilterMetadata(
    conditionKey: 'filterMeta.all',
    dataRequirements: [DataRequirement.dailyPrice],
  ),

  // === 反轉訊號 ===
  ScanFilter.reversalW2S: FilterMetadata(
    conditionKey: 'filterMeta.reversalW2S',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.consecutiveRedK',
  ),
  ScanFilter.reversalS2W: FilterMetadata(
    conditionKey: 'filterMeta.reversalS2W',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.consecutiveBlackK',
  ),

  // === 技術突破/跌破 ===
  ScanFilter.breakout: FilterMetadata(
    conditionKey: 'filterMeta.breakout',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.breakout20High',
  ),
  ScanFilter.breakdown: FilterMetadata(
    conditionKey: 'filterMeta.breakdown',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.breakdown20Low',
  ),

  // === 成交量訊號 ===
  ScanFilter.volumeSpike: FilterMetadata(
    conditionKey: 'filterMeta.volumeSpike',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.volumeSpike',
  ),

  // === 價格訊號 ===
  ScanFilter.priceSpike: FilterMetadata(
    conditionKey: 'filterMeta.priceSpike',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.priceSpike',
  ),

  // === KD 訊號 ===
  ScanFilter.kdGoldenCross: FilterMetadata(
    conditionKey: 'filterMeta.kdGoldenCross',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.kdGoldenCross',
  ),
  ScanFilter.kdDeathCross: FilterMetadata(
    conditionKey: 'filterMeta.kdDeathCross',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.kdDeathCross',
  ),

  // === RSI 訊號 ===
  ScanFilter.rsiOverbought: FilterMetadata(
    conditionKey: 'filterMeta.rsiOverbought',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.rsiOverbought',
  ),
  ScanFilter.rsiOversold: FilterMetadata(
    conditionKey: 'filterMeta.rsiOversold',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.rsiOversold',
  ),

  // === 法人訊號 ===
  ScanFilter.institutionalBuy: FilterMetadata(
    conditionKey: 'filterMeta.institutionalBuy',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: 'threshold.instBuy',
  ),
  ScanFilter.institutionalSell: FilterMetadata(
    conditionKey: 'filterMeta.institutionalSell',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: 'threshold.instSell',
  ),
  ScanFilter.institutionalBuyStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalBuyStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: 'threshold.instBuyStreak',
  ),
  ScanFilter.institutionalSellStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalSellStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: 'threshold.instSellStreak',
  ),

  // === 延伸市場資料訊號 ===
  ScanFilter.dayTradingHigh: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingHigh',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: 'threshold.dayTradingHigh',
  ),
  ScanFilter.dayTradingExtreme: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingExtreme',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: 'threshold.dayTradingExtreme',
  ),

  ScanFilter.concentrationHigh: FilterMetadata(
    conditionKey: 'filterMeta.concentrationHigh',
    dataRequirements: [DataRequirement.holdingDistribution],
    thresholdInfo: 'threshold.concentrationHigh',
  ),

  // === 新聞訊號 ===
  ScanFilter.newsRelated: FilterMetadata(
    conditionKey: 'filterMeta.newsRelated',
    dataRequirements: [DataRequirement.news],
  ),

  // === 52 週訊號 ===
  ScanFilter.week52High: FilterMetadata(
    conditionKey: 'filterMeta.week52High',
    dataRequirements: [DataRequirement.priceHistory250],
    thresholdInfo: 'threshold.week52High',
  ),
  ScanFilter.week52Low: FilterMetadata(
    conditionKey: 'filterMeta.week52Low',
    dataRequirements: [DataRequirement.priceHistory250],
    thresholdInfo: 'threshold.week52Low',
  ),

  // === 均線排列訊號 ===
  ScanFilter.maAlignmentBullish: FilterMetadata(
    conditionKey: 'filterMeta.maAlignmentBullish',
    dataRequirements: [DataRequirement.priceHistory60],
    thresholdInfo: 'threshold.maAlignBullish',
  ),
  ScanFilter.maAlignmentBearish: FilterMetadata(
    conditionKey: 'filterMeta.maAlignmentBearish',
    dataRequirements: [DataRequirement.priceHistory60],
    thresholdInfo: 'threshold.maAlignBearish',
  ),

  // === K 線型態 ===
  ScanFilter.patternDoji: FilterMetadata(
    conditionKey: 'filterMeta.patternDoji',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.doji',
  ),
  ScanFilter.patternBullishEngulfing: FilterMetadata(
    conditionKey: 'filterMeta.patternBullishEngulfing',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.bullishEngulfing',
  ),
  ScanFilter.patternHammer: FilterMetadata(
    conditionKey: 'filterMeta.patternHammer',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.hammer',
  ),
  ScanFilter.patternMorningStar: FilterMetadata(
    conditionKey: 'filterMeta.patternMorningStar',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.morningStar',
  ),
  ScanFilter.patternThreeWhiteSoldiers: FilterMetadata(
    conditionKey: 'filterMeta.patternThreeWhiteSoldiers',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.threeWhiteSoldiers',
  ),
  ScanFilter.patternGapUp: FilterMetadata(
    conditionKey: 'filterMeta.patternGapUp',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.gapUp',
  ),
  ScanFilter.patternBearishEngulfing: FilterMetadata(
    conditionKey: 'filterMeta.patternBearishEngulfing',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.bearishEngulfing',
  ),
  ScanFilter.patternHangingMan: FilterMetadata(
    conditionKey: 'filterMeta.patternHangingMan',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.hangingMan',
  ),
  ScanFilter.patternEveningStar: FilterMetadata(
    conditionKey: 'filterMeta.patternEveningStar',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.eveningStar',
  ),
  ScanFilter.patternThreeBlackCrows: FilterMetadata(
    conditionKey: 'filterMeta.patternThreeBlackCrows',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.threeBlackCrows',
  ),
  ScanFilter.patternGapDown: FilterMetadata(
    conditionKey: 'filterMeta.patternGapDown',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: 'threshold.gapDown',
  ),

  // === 價量背離訊號 ===
  ScanFilter.priceVolumeWeakRally: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeWeakRally',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.priceVolumeWeakRally',
  ),
  ScanFilter.priceVolumeBearishDivergence: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeBearishDivergence',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.bearishDivergence',
  ),
  ScanFilter.highVolumeBreakout: FilterMetadata(
    conditionKey: 'filterMeta.highVolumeBreakout',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.volumeBreakout',
  ),
  ScanFilter.lowVolumeAccumulation: FilterMetadata(
    conditionKey: 'filterMeta.lowVolumeAccumulation',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'threshold.lowVolumeAccum',
  ),

  // === 基本面分析訊號 ===
  ScanFilter.revenueYoySurge: FilterMetadata(
    conditionKey: 'filterMeta.revenueYoySurge',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: 'threshold.revenueYoySurge',
  ),
  ScanFilter.revenueYoyDecline: FilterMetadata(
    conditionKey: 'filterMeta.revenueYoyDecline',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: 'threshold.revenueYoyDecline',
  ),
  ScanFilter.revenueMomGrowth: FilterMetadata(
    conditionKey: 'filterMeta.revenueMomGrowth',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: 'threshold.revenueMomGrowth',
  ),
  ScanFilter.revenueNewHigh: FilterMetadata(
    conditionKey: 'filterMeta.revenueNewHigh',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: 'threshold.revenueNewHigh',
  ),
  ScanFilter.highDividendYield: FilterMetadata(
    conditionKey: 'filterMeta.highDividendYield',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: 'threshold.highDividendYield',
  ),
  ScanFilter.peUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.peUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: 'threshold.peUndervalued',
  ),
  ScanFilter.peOvervalued: FilterMetadata(
    conditionKey: 'filterMeta.peOvervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: 'threshold.peOvervalued',
  ),
  ScanFilter.pbrUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.pbrUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: 'threshold.pbrUndervalued',
  ),
};
