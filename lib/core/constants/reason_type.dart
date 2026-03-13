import 'package:afterclose/core/constants/rule_scores.dart';

/// 推薦理由類型
enum ReasonType {
  reversalW2S('REVERSAL_W2S'),
  reversalS2W('REVERSAL_S2W'),
  techBreakout('TECH_BREAKOUT'),
  techBreakdown('TECH_BREAKDOWN'),
  volumeSpike('VOLUME_SPIKE'),
  priceSpike('PRICE_SPIKE'),
  institutionalBuy('INSTITUTIONAL_BUY'),
  institutionalSell('INSTITUTIONAL_SELL'),
  newsRelated('NEWS_RELATED'),
  // 技術指標訊號
  kdGoldenCross('KD_GOLDEN_CROSS'),
  kdDeathCross('KD_DEATH_CROSS'),
  institutionalBuyStreak('INSTITUTIONAL_BUY_STREAK'),
  institutionalSellStreak('INSTITUTIONAL_SELL_STREAK'),
  // K 線型態訊號
  patternDoji('PATTERN_DOJI'),
  patternDojiBearish('PATTERN_DOJI_BEARISH'),
  patternBullishEngulfing('PATTERN_BULLISH_ENGULFING'),
  patternBearishEngulfing('PATTERN_BEARISH_ENGULFING'),
  patternHammer('PATTERN_HAMMER'),
  patternHangingMan('PATTERN_HANGING_MAN'),
  patternGapUp('PATTERN_GAP_UP'),
  patternGapDown('PATTERN_GAP_DOWN'),
  patternMorningStar('PATTERN_MORNING_STAR'),
  patternEveningStar('PATTERN_EVENING_STAR'),
  patternThreeWhiteSoldiers('PATTERN_THREE_WHITE_SOLDIERS'),
  patternThreeBlackCrows('PATTERN_THREE_BLACK_CROWS'),
  // 第三階段：掃描/提醒訊號
  week52High('WEEK_52_HIGH'),
  week52Low('WEEK_52_LOW'),
  maAlignmentBullish('MA_ALIGNMENT_BULLISH'),
  maAlignmentBearish('MA_ALIGNMENT_BEARISH'),
  rsiExtremeOverbought('RSI_EXTREME_OVERBOUGHT'),
  rsiExtremeOversold('RSI_EXTREME_OVERSOLD'),
  // 第四階段：延伸市場資料訊號
  foreignShareholdingIncreasing('FOREIGN_SHAREHOLDING_INCREASING'),
  foreignShareholdingDecreasing('FOREIGN_SHAREHOLDING_DECREASING'),
  dayTradingHigh('DAY_TRADING_HIGH'),
  dayTradingExtreme('DAY_TRADING_EXTREME'),
  concentrationHigh('CONCENTRATION_HIGH'),
  // 第五階段：價量背離訊號
  priceVolumeBullishDivergence('PRICE_VOLUME_BULLISH_DIVERGENCE'),
  priceVolumeBearishDivergence('PRICE_VOLUME_BEARISH_DIVERGENCE'),
  highVolumeBreakout('HIGH_VOLUME_BREAKOUT'),
  lowVolumeAccumulation('LOW_VOLUME_ACCUMULATION'),
  // 第六階段：基本面分析訊號
  revenueYoySurge('REVENUE_YOY_SURGE'),
  revenueYoyDecline('REVENUE_YOY_DECLINE'),
  revenueMomGrowth('REVENUE_MOM_GROWTH'),
  revenueNewHigh('REVENUE_NEW_HIGH'),
  highDividendYield('HIGH_DIVIDEND_YIELD'),
  peUndervalued('PE_UNDERVALUED'),
  peOvervalued('PE_OVERVALUED'),
  pbrUndervalued('PBR_UNDERVALUED'),
  // Killer Features 訊號
  tradingWarningAttention('TRADING_WARNING_ATTENTION'),
  tradingWarningDisposal('TRADING_WARNING_DISPOSAL'),
  insiderSellingStreak('INSIDER_SELLING_STREAK'),
  insiderSignificantBuying('INSIDER_SIGNIFICANT_BUYING'),
  highPledgeRatio('HIGH_PLEDGE_RATIO'),
  foreignConcentrationWarning('FOREIGN_CONCENTRATION_WARNING'),
  foreignExodus('FOREIGN_EXODUS'),
  // EPS 訊號
  epsYoYSurge('EPS_YOY_SURGE'),
  epsConsecutiveGrowth('EPS_CONSECUTIVE_GROWTH'),
  epsTurnaround('EPS_TURNAROUND'),
  epsDeclineWarning('EPS_DECLINE_WARNING'),

  // ROE 訊號
  roeExcellent('ROE_EXCELLENT'),
  roeImproving('ROE_IMPROVING'),
  roeDeclining('ROE_DECLINING');

  const ReasonType(this.code);

  final String code;

  int get score => switch (this) {
    ReasonType.reversalW2S => RuleScores.reversalW2S,
    ReasonType.reversalS2W => RuleScores.reversalS2W,
    ReasonType.techBreakout => RuleScores.techBreakout,
    ReasonType.techBreakdown => RuleScores.techBreakdown,
    ReasonType.volumeSpike => RuleScores.volumeSpike,
    ReasonType.priceSpike => RuleScores.priceSpike,

    ReasonType.institutionalBuy => RuleScores.institutionalShift,
    ReasonType.institutionalSell => RuleScores.institutionalShiftSell,
    ReasonType.newsRelated => RuleScores.newsRelated,
    ReasonType.kdGoldenCross => RuleScores.kdGoldenCross,
    ReasonType.kdDeathCross => RuleScores.kdDeathCross,
    ReasonType.institutionalBuyStreak => RuleScores.institutionalBuyStreak,
    ReasonType.institutionalSellStreak => RuleScores.institutionalSellStreak,
    // K 線型態（多空分離）
    ReasonType.patternDoji => RuleScores.patternDoji,
    ReasonType.patternDojiBearish => RuleScores.patternDojiBearish,
    ReasonType.patternBullishEngulfing => RuleScores.patternEngulfingBullish,
    ReasonType.patternBearishEngulfing => RuleScores.patternEngulfingBearish,
    ReasonType.patternHammer => RuleScores.patternHammerBullish,
    ReasonType.patternHangingMan => RuleScores.patternHammerBearish,
    ReasonType.patternGapUp => RuleScores.patternGapUp,
    ReasonType.patternGapDown => RuleScores.patternGapDown,
    ReasonType.patternMorningStar => RuleScores.patternMorningStar,
    ReasonType.patternEveningStar => RuleScores.patternEveningStar,
    ReasonType.patternThreeWhiteSoldiers =>
      RuleScores.patternThreeWhiteSoldiers,
    ReasonType.patternThreeBlackCrows => RuleScores.patternThreeBlackCrows,
    // 第三階段訊號
    ReasonType.week52High => RuleScores.week52High,
    ReasonType.week52Low => RuleScores.week52Low,
    ReasonType.maAlignmentBullish => RuleScores.maAlignmentBullish,
    ReasonType.maAlignmentBearish => RuleScores.maAlignmentBearish,
    ReasonType.rsiExtremeOverbought => RuleScores.rsiExtremeOverboughtSignal,
    ReasonType.rsiExtremeOversold => RuleScores.rsiExtremeOversoldSignal,
    // 第四階段訊號
    ReasonType.foreignShareholdingIncreasing =>
      RuleScores.foreignShareholdingIncreasing,
    ReasonType.foreignShareholdingDecreasing =>
      RuleScores.foreignShareholdingDecreasing,
    ReasonType.dayTradingHigh => RuleScores.dayTradingHigh,
    ReasonType.dayTradingExtreme => RuleScores.dayTradingExtreme,
    ReasonType.concentrationHigh => RuleScores.concentrationHigh,
    // 第五階段訊號
    ReasonType.priceVolumeBullishDivergence =>
      RuleScores.priceVolumeBullishDivergence,
    ReasonType.priceVolumeBearishDivergence =>
      RuleScores.priceVolumeBearishDivergence,
    ReasonType.highVolumeBreakout => RuleScores.highVolumeBreakout,
    ReasonType.lowVolumeAccumulation => RuleScores.lowVolumeAccumulation,
    // 第六階段訊號
    ReasonType.revenueYoySurge => RuleScores.revenueYoySurge,
    ReasonType.revenueYoyDecline => RuleScores.revenueYoyDecline,
    ReasonType.revenueMomGrowth => RuleScores.revenueMomGrowth,
    ReasonType.revenueNewHigh => RuleScores.revenueNewHigh,
    ReasonType.highDividendYield => RuleScores.highDividendYield,
    ReasonType.peUndervalued => RuleScores.peUndervalued,
    ReasonType.peOvervalued => RuleScores.peOvervalued,
    ReasonType.pbrUndervalued => RuleScores.pbrUndervalued,
    // Killer Features 訊號
    ReasonType.tradingWarningAttention => RuleScores.tradingWarningAttention,
    ReasonType.tradingWarningDisposal => RuleScores.tradingWarningDisposal,
    ReasonType.insiderSellingStreak => RuleScores.insiderSellingStreak,
    ReasonType.insiderSignificantBuying => RuleScores.insiderSignificantBuying,
    ReasonType.highPledgeRatio => RuleScores.highPledgeRatio,
    ReasonType.foreignConcentrationWarning =>
      RuleScores.foreignConcentrationWarning,
    ReasonType.foreignExodus => RuleScores.foreignExodus,
    // EPS 訊號
    ReasonType.epsYoYSurge => RuleScores.epsYoYSurge,
    ReasonType.epsConsecutiveGrowth => RuleScores.epsConsecutiveGrowth,
    ReasonType.epsTurnaround => RuleScores.epsTurnaround,
    ReasonType.epsDeclineWarning => RuleScores.epsDeclineWarning,
    ReasonType.roeExcellent => RuleScores.roeExcellent,
    ReasonType.roeImproving => RuleScores.roeImproving,
    ReasonType.roeDeclining => RuleScores.roeDeclining,
  };
}

/// i18n 鍵擴充：將 ReasonType 對應到翻譯鍵
extension ReasonTypeI18n on ReasonType {
  /// 取得理由標籤的 i18n 鍵
  String get i18nLabelKey => switch (this) {
    ReasonType.reversalW2S => 'reasons.reversalW2S',
    ReasonType.reversalS2W => 'reasons.reversalS2W',
    ReasonType.techBreakout => 'reasons.breakout',
    ReasonType.techBreakdown => 'reasons.breakdown',
    ReasonType.volumeSpike => 'reasons.volumeSpike',
    ReasonType.priceSpike => 'reasons.priceSpike',
    ReasonType.institutionalBuy => 'reasons.institutionalBuy',
    ReasonType.institutionalSell => 'reasons.institutionalSell',
    ReasonType.newsRelated => 'reasons.news',
    ReasonType.kdGoldenCross => 'reasons.kdGoldenCross',
    ReasonType.kdDeathCross => 'reasons.kdDeathCross',
    ReasonType.institutionalBuyStreak => 'reasons.institutionalBuyStreak',
    ReasonType.institutionalSellStreak => 'reasons.institutionalSellStreak',
    // K 線型態
    ReasonType.patternDoji => 'reasons.patternDoji',
    ReasonType.patternDojiBearish => 'reasons.patternDojiBearish',
    ReasonType.patternBullishEngulfing => 'reasons.patternBullishEngulfing',
    ReasonType.patternBearishEngulfing => 'reasons.patternBearishEngulfing',
    ReasonType.patternHammer => 'reasons.patternHammer',
    ReasonType.patternHangingMan => 'reasons.patternHangingMan',
    ReasonType.patternGapUp => 'reasons.patternGapUp',
    ReasonType.patternGapDown => 'reasons.patternGapDown',
    ReasonType.patternMorningStar => 'reasons.patternMorningStar',
    ReasonType.patternEveningStar => 'reasons.patternEveningStar',
    ReasonType.patternThreeWhiteSoldiers => 'reasons.patternThreeWhiteSoldiers',
    ReasonType.patternThreeBlackCrows => 'reasons.patternThreeBlackCrows',
    // 52 週高低點與均線排列
    ReasonType.week52High => 'reasons.week52High',
    ReasonType.week52Low => 'reasons.week52Low',
    ReasonType.maAlignmentBullish => 'reasons.maAlignmentBullish',
    ReasonType.maAlignmentBearish => 'reasons.maAlignmentBearish',
    ReasonType.rsiExtremeOverbought => 'reasons.rsiExtremeOverbought',
    ReasonType.rsiExtremeOversold => 'reasons.rsiExtremeOversold',
    // 擴展市場資料
    ReasonType.foreignShareholdingIncreasing =>
      'reasons.foreignShareholdingIncreasing',
    ReasonType.foreignShareholdingDecreasing =>
      'reasons.foreignShareholdingDecreasing',
    ReasonType.dayTradingHigh => 'reasons.dayTradingHigh',
    ReasonType.dayTradingExtreme => 'reasons.dayTradingExtreme',
    ReasonType.concentrationHigh => 'reasons.concentrationHigh',
    // 量價背離
    ReasonType.priceVolumeBullishDivergence =>
      'reasons.priceVolumeBullishDivergence',
    ReasonType.priceVolumeBearishDivergence =>
      'reasons.priceVolumeBearishDivergence',
    ReasonType.highVolumeBreakout => 'reasons.highVolumeBreakout',
    ReasonType.lowVolumeAccumulation => 'reasons.lowVolumeAccumulation',
    // 基本面訊號
    ReasonType.revenueYoySurge => 'reasons.revenueYoySurge',
    ReasonType.revenueYoyDecline => 'reasons.revenueYoyDecline',
    ReasonType.revenueMomGrowth => 'reasons.revenueMomGrowth',
    ReasonType.revenueNewHigh => 'reasons.revenueNewHigh',
    ReasonType.highDividendYield => 'reasons.highDividendYield',
    ReasonType.peUndervalued => 'reasons.peUndervalued',
    ReasonType.peOvervalued => 'reasons.peOvervalued',
    ReasonType.pbrUndervalued => 'reasons.pbrUndervalued',
    // EPS 分析
    ReasonType.epsYoYSurge => 'reasons.epsYoYSurge',
    ReasonType.epsConsecutiveGrowth => 'reasons.epsConsecutiveGrowth',
    ReasonType.epsTurnaround => 'reasons.epsTurnaround',
    ReasonType.epsDeclineWarning => 'reasons.epsDeclineWarning',
    // ROE 分析
    ReasonType.roeExcellent => 'reasons.roeExcellent',
    ReasonType.roeImproving => 'reasons.roeImproving',
    ReasonType.roeDeclining => 'reasons.roeDeclining',
    // 警示與內部人訊號
    ReasonType.tradingWarningAttention => 'reasons.tradingWarningAttention',
    ReasonType.tradingWarningDisposal => 'reasons.tradingWarningDisposal',
    ReasonType.insiderSellingStreak => 'reasons.insiderSellingStreak',
    ReasonType.insiderSignificantBuying => 'reasons.insiderSignificantBuying',
    ReasonType.highPledgeRatio => 'reasons.highPledgeRatio',
    ReasonType.foreignConcentrationWarning =>
      'reasons.foreignConcentrationWarning',
    ReasonType.foreignExodus => 'reasons.foreignExodus',
  };

  /// 取得理由說明的 i18n 鍵（用於 tooltip），無對應則回傳 null
  String? get i18nTooltipKey => switch (this) {
    ReasonType.reversalW2S => 'summary.reversalW2S',
    ReasonType.reversalS2W => 'summary.reversalS2W',
    ReasonType.techBreakout => 'summary.breakout',
    ReasonType.techBreakdown => 'summary.breakdown',
    ReasonType.volumeSpike => 'reasonTip.volumeSpike',
    ReasonType.priceSpike => 'reasonTip.priceSpike',
    ReasonType.institutionalBuy => 'reasonTip.institutional',
    ReasonType.institutionalSell => 'reasonTip.institutional',
    ReasonType.newsRelated => 'reasonTip.news',
    ReasonType.kdGoldenCross => 'summary.kdGoldenCross',
    ReasonType.kdDeathCross => 'summary.kdDeathCross',
    ReasonType.institutionalBuyStreak => 'summary.institutionalBuyStreak',
    ReasonType.institutionalSellStreak => 'summary.institutionalSellStreak',
    // K 線型態
    ReasonType.patternDoji => 'summary.patternDoji',
    ReasonType.patternDojiBearish => 'reasonTip.patternDojiBearish',
    ReasonType.patternBullishEngulfing => 'summary.patternBullishEngulfing',
    ReasonType.patternBearishEngulfing => 'summary.patternBearishEngulfing',
    ReasonType.patternHammer => 'summary.patternHammer',
    ReasonType.patternHangingMan => 'summary.patternHangingMan',
    ReasonType.patternMorningStar => 'summary.patternMorningStar',
    ReasonType.patternEveningStar => 'summary.patternEveningStar',
    ReasonType.patternThreeWhiteSoldiers => 'summary.patternThreeWhiteSoldiers',
    ReasonType.patternThreeBlackCrows => 'summary.patternThreeBlackCrows',
    ReasonType.patternGapUp => 'summary.patternGapUp',
    ReasonType.patternGapDown => 'summary.patternGapDown',
    // 52 週高低點與均線排列
    ReasonType.week52High => 'summary.week52High',
    ReasonType.week52Low => 'summary.week52Low',
    ReasonType.maAlignmentBullish => 'summary.maAlignmentBullish',
    ReasonType.maAlignmentBearish => 'summary.maAlignmentBearish',
    ReasonType.rsiExtremeOverbought => 'reasonTip.rsiOverbought',
    ReasonType.rsiExtremeOversold => 'reasonTip.rsiOversold',
    // 擴展市場資料
    ReasonType.foreignShareholdingIncreasing => 'reasonTip.foreignIncreasing',
    ReasonType.foreignShareholdingDecreasing => 'reasonTip.foreignDecreasing',
    ReasonType.dayTradingHigh => 'reasonTip.dayTradingHigh',
    ReasonType.dayTradingExtreme => 'reasonTip.dayTradingHigh',
    ReasonType.concentrationHigh => 'reasonTip.concentrationHigh',
    // 量價背離
    ReasonType.priceVolumeBullishDivergence => 'reasonTip.bullishDivergence',
    ReasonType.priceVolumeBearishDivergence => 'reasonTip.bearishDivergence',
    ReasonType.highVolumeBreakout => 'reasonTip.highVolumeBreakout',
    ReasonType.lowVolumeAccumulation => 'reasonTip.lowVolumeAccumulation',
    // 基本面訊號
    ReasonType.revenueYoySurge => 'reasonTip.revenueYoySurge',
    ReasonType.revenueYoyDecline => 'reasonTip.revenueYoyDecline',
    ReasonType.revenueMomGrowth => 'reasonTip.revenueMomGrowth',
    ReasonType.revenueNewHigh => 'reasonTip.revenueNewHigh',
    ReasonType.highDividendYield => 'reasonTip.highDividendYield',
    ReasonType.peUndervalued => 'reasonTip.peUndervalued',
    ReasonType.peOvervalued => 'reasonTip.peOvervalued',
    ReasonType.pbrUndervalued => 'reasonTip.pbrUndervalued',
    // EPS 分析
    ReasonType.epsYoYSurge => 'reasonTip.epsYoYSurge',
    ReasonType.epsConsecutiveGrowth => 'reasonTip.epsConsecutiveGrowth',
    ReasonType.epsTurnaround => 'reasonTip.epsTurnaround',
    ReasonType.epsDeclineWarning => 'reasonTip.epsDecline',
    // ROE 分析
    ReasonType.roeExcellent => 'reasonTip.roeExcellent',
    ReasonType.roeImproving => 'reasonTip.roeImproving',
    ReasonType.roeDeclining => 'reasonTip.roeDeclining',
    // 警示與內部人訊號
    ReasonType.tradingWarningAttention => 'summary.warningAttention',
    ReasonType.tradingWarningDisposal => 'summary.warningDisposal',
    ReasonType.insiderSellingStreak => 'reasonTip.insiderSelling',
    ReasonType.insiderSignificantBuying => 'summary.insiderBuying',
    ReasonType.highPledgeRatio => 'summary.highPledge',
    ReasonType.foreignConcentrationWarning => 'reasonTip.foreignConcentration',
    ReasonType.foreignExodus => 'reasonTip.foreignExodus',
  };
}

/// 從原因代碼字串查找對應的 [ReasonType]
///
/// 支援 SNAKE_CASE（DB 原始碼）、camelCase（JSON 格式）及歷史別名。
final _reasonCodeMap = <String, ReasonType>{
  for (final rt in ReasonType.values) ...<String, ReasonType>{
    rt.code: rt,
    rt.name: rt,
  },
  // Legacy aliases
  'INSTITUTIONAL_SHIFT': ReasonType.institutionalBuy,
  'institutionalShift': ReasonType.institutionalBuy,
};

ReasonType? reasonTypeFromCode(String code) => _reasonCodeMap[code];
