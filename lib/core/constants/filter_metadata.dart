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

  /// 門檻資訊（如「4 倍平均成交量」）
  final String? thresholdInfo;

  /// 檢查此篩選器是否僅需基本資料（永遠可用）
  bool get isBasicDataOnly =>
      dataRequirements.length == 1 &&
      dataRequirements.first == DataRequirement.dailyPrice;
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
    thresholdInfo: '3-7天連續紅K',
  ),
  ScanFilter.reversalS2W: FilterMetadata(
    conditionKey: 'filterMeta.reversalS2W',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '3-7天連續黑K',
  ),

  // === 技術突破/跌破 ===
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

  // === 成交量訊號 ===
  ScanFilter.volumeSpike: FilterMetadata(
    conditionKey: 'filterMeta.volumeSpike',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '成交量 ≥ 4倍均量 + 價格變動 ≥ 1.5%',
  ),

  // === 價格訊號 ===
  ScanFilter.priceSpike: FilterMetadata(
    conditionKey: 'filterMeta.priceSpike',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '單日漲跌幅 ≥ 7% + 量 ≥ 1.5 倍均量',
  ),

  // === KD 訊號 ===
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

  // === RSI 訊號 ===
  ScanFilter.rsiOverbought: FilterMetadata(
    conditionKey: 'filterMeta.rsiOverbought',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'RSI ≥ 80',
  ),
  ScanFilter.rsiOversold: FilterMetadata(
    conditionKey: 'filterMeta.rsiOversold',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: 'RSI ≤ 30',
  ),

  // === 法人訊號 ===
  ScanFilter.institutionalBuy: FilterMetadata(
    conditionKey: 'filterMeta.institutionalBuy',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '法人當日買超',
  ),
  ScanFilter.institutionalSell: FilterMetadata(
    conditionKey: 'filterMeta.institutionalSell',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '法人當日賣超',
  ),
  ScanFilter.institutionalBuyStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalBuyStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '連續4天以上法人買超',
  ),
  ScanFilter.institutionalSellStreak: FilterMetadata(
    conditionKey: 'filterMeta.institutionalSellStreak',
    dataRequirements: [DataRequirement.institutional],
    thresholdInfo: '連續4天以上法人賣超',
  ),

  // === 延伸市場資料訊號 ===
  ScanFilter.dayTradingHigh: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingHigh',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: '當沖比例 ≥ 50% + 萬張以上',
  ),
  ScanFilter.dayTradingExtreme: FilterMetadata(
    conditionKey: 'filterMeta.dayTradingExtreme',
    dataRequirements: [DataRequirement.dayTrading],
    thresholdInfo: '當沖比例 ≥ 70% + 3萬張以上',
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
    thresholdInfo: '創52週新高',
  ),
  ScanFilter.week52Low: FilterMetadata(
    conditionKey: 'filterMeta.week52Low',
    dataRequirements: [DataRequirement.priceHistory250],
    thresholdInfo: '創52週新低',
  ),

  // === 均線排列訊號 ===
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

  // === K 線型態 ===
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

  // === 價量背離訊號 ===
  ScanFilter.priceVolumeBullishDivergence: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeBullishDivergence',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '價漲 > 5% 且 量縮 > 40%',
  ),
  ScanFilter.priceVolumeBearishDivergence: FilterMetadata(
    conditionKey: 'filterMeta.priceVolumeBearishDivergence',
    dataRequirements: [DataRequirement.priceHistory20],
    thresholdInfo: '價跌 > 3% 且 量增 > 30%',
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

  // === 基本面分析訊號 ===
  ScanFilter.revenueYoySurge: FilterMetadata(
    conditionKey: 'filterMeta.revenueYoySurge',
    dataRequirements: [DataRequirement.monthlyRevenue],
    thresholdInfo: '營收年增率 ≥ 30%',
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
    thresholdInfo: '殖利率 ≥ 5.5%',
  ),
  ScanFilter.peUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.peUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '本益比 ≤ 10',
  ),
  ScanFilter.peOvervalued: FilterMetadata(
    conditionKey: 'filterMeta.peOvervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '本益比 ≥ 100',
  ),
  ScanFilter.pbrUndervalued: FilterMetadata(
    conditionKey: 'filterMeta.pbrUndervalued',
    dataRequirements: [DataRequirement.valuation],
    thresholdInfo: '股價淨值比 ≤ 0.8',
  ),
};
