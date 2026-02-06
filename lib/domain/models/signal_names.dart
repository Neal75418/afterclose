/// Canonical signal name constants used across rule engine, scan filters,
/// confluence detection, and summary generation.
///
/// All signal names are UPPER_SNAKE_CASE strings matching the `reasonType`
/// stored in [DailyReasonEntry].
abstract final class SignalName {
  // ── Reversal ──
  static const reversalW2S = 'REVERSAL_W2S';
  static const reversalS2W = 'REVERSAL_S2W';

  // ── Technical Breakout / Breakdown ──
  static const techBreakout = 'TECH_BREAKOUT';
  static const techBreakdown = 'TECH_BREAKDOWN';

  // ── Volume ──
  static const volumeSpike = 'VOLUME_SPIKE';

  // ── Price ──
  static const priceSpike = 'PRICE_SPIKE';

  // ── KD ──
  static const kdGoldenCross = 'KD_GOLDEN_CROSS';
  static const kdDeathCross = 'KD_DEATH_CROSS';

  // ── RSI ──
  static const rsiExtremeOverbought = 'RSI_EXTREME_OVERBOUGHT';
  static const rsiExtremeOversold = 'RSI_EXTREME_OVERSOLD';

  // ── Institutional ──
  static const institutionalBuy = 'INSTITUTIONAL_BUY';
  static const institutionalSell = 'INSTITUTIONAL_SELL';
  static const institutionalBuyStreak = 'INSTITUTIONAL_BUY_STREAK';
  static const institutionalSellStreak = 'INSTITUTIONAL_SELL_STREAK';

  // ── Extended Market Data ──
  static const dayTradingHigh = 'DAY_TRADING_HIGH';
  static const dayTradingExtreme = 'DAY_TRADING_EXTREME';

  // ── News ──
  static const newsRelated = 'NEWS_RELATED';

  // ── 52-Week ──
  static const week52High = 'WEEK_52_HIGH';
  static const week52Low = 'WEEK_52_LOW';

  // ── MA Alignment ──
  static const maAlignmentBullish = 'MA_ALIGNMENT_BULLISH';
  static const maAlignmentBearish = 'MA_ALIGNMENT_BEARISH';

  // ── Candlestick Patterns ──
  static const patternDoji = 'PATTERN_DOJI';
  static const patternBullishEngulfing = 'PATTERN_BULLISH_ENGULFING';
  static const patternBearishEngulfing = 'PATTERN_BEARISH_ENGULFING';
  static const patternHammer = 'PATTERN_HAMMER';
  static const patternHangingMan = 'PATTERN_HANGING_MAN';
  static const patternGapUp = 'PATTERN_GAP_UP';
  static const patternGapDown = 'PATTERN_GAP_DOWN';
  static const patternMorningStar = 'PATTERN_MORNING_STAR';
  static const patternEveningStar = 'PATTERN_EVENING_STAR';
  static const patternThreeWhiteSoldiers = 'PATTERN_THREE_WHITE_SOLDIERS';
  static const patternThreeBlackCrows = 'PATTERN_THREE_BLACK_CROWS';

  // ── Price-Volume Divergence ──
  static const priceVolumeBullishDivergence = 'PRICE_VOLUME_BULLISH_DIVERGENCE';
  static const priceVolumeBearishDivergence = 'PRICE_VOLUME_BEARISH_DIVERGENCE';
  static const highVolumeBreakout = 'HIGH_VOLUME_BREAKOUT';
  static const lowVolumeAccumulation = 'LOW_VOLUME_ACCUMULATION';

  // ── Fundamental: Revenue ──
  static const revenueYoySurge = 'REVENUE_YOY_SURGE';
  static const revenueYoyDecline = 'REVENUE_YOY_DECLINE';
  static const revenueMomGrowth = 'REVENUE_MOM_GROWTH';

  // ── Fundamental: Valuation ──
  static const highDividendYield = 'HIGH_DIVIDEND_YIELD';
  static const peUndervalued = 'PE_UNDERVALUED';
  static const peOvervalued = 'PE_OVERVALUED';
  static const pbrUndervalued = 'PBR_UNDERVALUED';

  // ── Foreign Shareholding ──
  static const foreignShareholdingIncreasing =
      'FOREIGN_SHAREHOLDING_INCREASING';
  static const foreignShareholdingDecreasing =
      'FOREIGN_SHAREHOLDING_DECREASING';
  static const concentrationHigh = 'CONCENTRATION_HIGH';

  // ── Killer Features ──
  static const tradingWarningAttention = 'TRADING_WARNING_ATTENTION';
  static const tradingWarningDisposal = 'TRADING_WARNING_DISPOSAL';
  static const insiderSellingStreak = 'INSIDER_SELLING_STREAK';
  static const insiderSignificantBuying = 'INSIDER_SIGNIFICANT_BUYING';
  static const highPledgeRatio = 'HIGH_PLEDGE_RATIO';
  static const foreignConcentrationWarning = 'FOREIGN_CONCENTRATION_WARNING';
  static const foreignExodus = 'FOREIGN_EXODUS';

  // ── EPS ──
  static const epsYoySurge = 'EPS_YOY_SURGE';
  static const epsConsecutiveGrowth = 'EPS_CONSECUTIVE_GROWTH';
  static const epsTurnaround = 'EPS_TURNAROUND';
  static const epsDeclineWarning = 'EPS_DECLINE_WARNING';

  // ── ROE ──
  static const roeExcellent = 'ROE_EXCELLENT';
  static const roeImproving = 'ROE_IMPROVING';
  static const roeDeclining = 'ROE_DECLINING';
}
