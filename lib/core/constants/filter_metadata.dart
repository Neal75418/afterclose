/// Metadata for scan filters - provides condition descriptions and data requirements
///
/// This file contains detailed information about each scan filter to help users
/// understand why a filter might return empty results.
library;

import 'package:afterclose/presentation/providers/scan_provider.dart';

/// Data requirement type for a filter
enum DataRequirement {
  /// Basic daily price data (always available)
  dailyPrice('dataReq.dailyPrice'),

  /// Price history (20+ days)
  priceHistory20('dataReq.priceHistory20'),

  /// Price history (60+ days for MA60)
  priceHistory60('dataReq.priceHistory60'),

  /// Price history (250 days for 52-week high/low)
  priceHistory250('dataReq.priceHistory250'),

  /// Institutional trading data (三大法人)
  institutional('dataReq.institutional'),

  /// Foreign shareholding ratio (外資持股比例)
  foreignShareholding('dataReq.foreignShareholding'),

  /// Day trading ratio (當沖比例)
  dayTrading('dataReq.dayTrading'),

  /// Monthly revenue data (月營收)
  monthlyRevenue('dataReq.monthlyRevenue'),

  /// Valuation data (PE, PBR, dividend yield)
  valuation('dataReq.valuation'),

  /// News data
  news('dataReq.news');

  const DataRequirement(this.labelKey);
  final String labelKey;
}

/// Metadata for a scan filter
class FilterMetadata {
  const FilterMetadata({
    required this.conditionKey,
    required this.dataRequirements,
    this.thresholdInfo,
  });

  /// i18n key for condition description
  final String conditionKey;

  /// Required data types for this filter to work
  final List<DataRequirement> dataRequirements;

  /// Optional threshold information (e.g., "4x average volume")
  final String? thresholdInfo;

  /// Check if this filter only needs basic data (always available)
  bool get isBasicDataOnly =>
      dataRequirements.length == 1 &&
      dataRequirements.first == DataRequirement.dailyPrice;
}

/// Extension to get metadata for each ScanFilter
extension ScanFilterMetadataExtension on ScanFilter {
  /// Get metadata for this filter
  FilterMetadata get metadata => _filterMetadataMap[this] ?? _defaultMetadata;

  static const FilterMetadata _defaultMetadata = FilterMetadata(
    conditionKey: 'filterMeta.default',
    dataRequirements: [DataRequirement.dailyPrice],
  );
}

/// Mapping of ScanFilter to its metadata
const Map<ScanFilter, FilterMetadata> _filterMetadataMap = {
  // All
  ScanFilter.all: FilterMetadata(
    conditionKey: 'filterMeta.all',
    dataRequirements: [DataRequirement.dailyPrice],
  ),

  // === Reversal signals ===
  ScanFilter.reversalW2S: FilterMetadata(
    conditionKey: 'filterMeta.reversalW2S',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '3-7天連續紅K',
  ),
  ScanFilter.reversalS2W: FilterMetadata(
    conditionKey: 'filterMeta.reversalS2W',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '3-7天連續黑K',
  ),

  // === Technical breakout/breakdown ===
  ScanFilter.breakout: FilterMetadata(
    conditionKey: 'filterMeta.breakout',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '突破20日高點',
  ),
  ScanFilter.breakdown: FilterMetadata(
    conditionKey: 'filterMeta.breakdown',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '跌破20日低點',
  ),

  // === Volume signals ===
  ScanFilter.volumeSpike: FilterMetadata(
    conditionKey: 'filterMeta.volumeSpike',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '成交量 ≥ 4倍均量 + 價格變動 ≥ 1.5%',
  ),

  // === Price signals ===
  ScanFilter.priceSpike: FilterMetadata(
    conditionKey: 'filterMeta.priceSpike',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '單日漲跌幅 ≥ 3%',
  ),

  // === KD signals ===
  ScanFilter.kdGoldenCross: FilterMetadata(
    conditionKey: 'filterMeta.kdGoldenCross',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'K線向上穿越D線，且K<30',
  ),
  ScanFilter.kdDeathCross: FilterMetadata(
    conditionKey: 'filterMeta.kdDeathCross',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'K線向下穿越D線，且K>70',
  ),

  // === RSI signals ===
  ScanFilter.rsiOverbought: FilterMetadata(
    conditionKey: 'filterMeta.rsiOverbought',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'RSI ≥ 80',
  ),
  ScanFilter.rsiOversold: FilterMetadata(
    conditionKey: 'filterMeta.rsiOversold',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'RSI ≤ 20',
  ),

  // === Institutional signals ===
  ScanFilter.institutionalShift: FilterMetadata(
    conditionKey: 'filterMeta.institutionalShift',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '法人買賣方向突然轉變',
  ),
  ScanFilter.institutionalBuyStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalBuyStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '連續3天以上法人買超',
  ),
  ScanFilter.institutionalSellStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalSellStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '連續3天以上法人賣超',
  ),

  // === Extended market data signals ===
  ScanFilter.foreignShareholdingIncreasing: FilterMetadata(
    conditionKey: 'filterMeta.foreignShareholdingIncreasing',
    dataRequirements: [DataRequirement.foreignShareholding],
    thresholdInfo: '外資持股比例連續增加',
  ),
  ScanFilter.foreignShareholdingDecreasing: FilterMetadata(
    conditionKey: 'filterMeta.foreignShareholdingDecreasing',
    dataRequirements: [DataRequirement.foreignShareholding],
    thresholdInfo: '外資持股比例連續減少',
  ),
  ScanFilter.dayTradingHigh: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingHigh',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: '當沖比例 ≥ 30%',
  ),
  ScanFilter.dayTradingExtreme: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingExtreme',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: '當沖比例 ≥ 50%',
  ),

  // === News signals ===
  ScanFilter.newsRelated: FilterMetadata(
    conditionKey: 'filterMeta.newsRelated',
    dataRequirements: [DataRequirement.news],
  ),

  // === 52-week signals ===
  ScanFilter.week52High: FilterMetadata(
    conditionKey: 'filterMeta.week52High',
    dataRequirements: [DataRequirement.priceHistory250],
    thresholdInfo: '創52週新高',
  ),
  ScanFilter.week52Low: FilterMetadata(
    conditionKey: 'filterMeta.week52Low',
    dataRequirements: [DataRequirement.priceHistory250],
    thresholdInfo: '創52週新低',
  ),

  // === MA alignment signals ===
  ScanFilter.maAlignmentBullish: FilterMetadata(
    conditionKey: 'filterMeta.maAlignmentBullish',
    dataRequirements: [DataRequirement.priceHistory60],
    thresholdInfo: 'MA5 > MA10 > MA20 > MA60',
  ),
  ScanFilter.maAlignmentBearish: FilterMetadata(
    conditionKey: 'filterMeta.maAlignmentBearish',
    dataRequirements: [DataRequirement.priceHistory60],
    thresholdInfo: 'MA5 < MA10 < MA20 < MA60',
  ),

  // === Candlestick patterns ===
  ScanFilter.patternDoji: FilterMetadata(
    conditionKey: 'filterMeta.patternDoji',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '十字線形態',
  ),
  ScanFilter.patternBullishEngulfing: FilterMetadata(
    conditionKey: 'filterMeta.patternBullishEngulfing',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '陽線吞噬',
  ),
  ScanFilter.patternHammer: FilterMetadata(
    conditionKey: 'filterMeta.patternHammer',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '錘子線',
  ),
  ScanFilter.patternMorningStar: FilterMetadata(
    conditionKey: 'filterMeta.patternMorningStar',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '晨星形態',
  ),
  ScanFilter.patternThreeWhiteSoldiers: FilterMetadata(
    conditionKey: 'filterMeta.patternThreeWhiteSoldiers',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '三白兵',
  ),
  ScanFilter.patternGapUp: FilterMetadata(
    conditionKey: 'filterMeta.patternGapUp',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '跳空缺口向上',
  ),
  ScanFilter.patternBearishEngulfing: FilterMetadata(
    conditionKey: 'filterMeta.patternBearishEngulfing',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '陰線吞噬',
  ),
  ScanFilter.patternHangingMan: FilterMetadata(
    conditionKey: 'filterMeta.patternHangingMan',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '吊人線',
  ),
  ScanFilter.patternEveningStar: FilterMetadata(
    conditionKey: 'filterMeta.patternEveningStar',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '夜星形態',
  ),
  ScanFilter.patternThreeBlackCrows: FilterMetadata(
    conditionKey: 'filterMeta.patternThreeBlackCrows',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '三黑鴉',
  ),
  ScanFilter.patternGapDown: FilterMetadata(
    conditionKey: 'filterMeta.patternGapDown',
    dataRequirements: [DataRequirement.dailyPrice],
    thresholdInfo: '跳空缺口向下',
  ),

  // === Price-volume divergence signals ===
  ScanFilter.priceVolumeBullishDivergence: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeBullishDivergence',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '價跌量縮（多頭背離）',
  ),
  ScanFilter.priceVolumeBearishDivergence: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeBearishDivergence',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '價漲量縮（空頭背離）',
  ),
  ScanFilter.highVolumeBreakout: FilterMetadata(
    conditionKey: 'filterMeta.highVolumeBreakout',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '帶量突破',
  ),
  ScanFilter.lowVolumeAccumulation: FilterMetadata(
    conditionKey: 'filterMeta.lowVolumeAccumulation',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '低量整理',
  ),

  // === Fundamental analysis signals ===
  ScanFilter.revenueYoySurge: FilterMetadata(
    conditionKey: 'filterMeta.revenueYoySurge',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: '營收年增率 ≥ 20%',
  ),
  ScanFilter.revenueYoyDecline: FilterMetadata(
    conditionKey: 'filterMeta.revenueYoyDecline',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: '營收年增率 ≤ -20%',
  ),
  ScanFilter.revenueMomGrowth: FilterMetadata(
    conditionKey: 'filterMeta.revenueMomGrowth',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: '連續2個月營收月增',
  ),
  ScanFilter.highDividendYield: FilterMetadata(
    conditionKey: 'filterMeta.highDividendYield',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '殖利率 ≥ 5%',
  ),
  ScanFilter.peUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.peUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '本益比 ≤ 10',
  ),
  ScanFilter.peOvervalued: FilterMetadata(
    conditionKey: 'filterMeta.peOvervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '本益比 ≥ 30',
  ),
  ScanFilter.pbrUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.pbrUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '股價淨值比 ≤ 1',
  ),
};
