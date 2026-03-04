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
