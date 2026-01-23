/// Rule Engine Parameters v1
/// These are fixed values for v1, will be configurable in v2
abstract final class RuleParams {
  /// Analysis window in days
  static const int lookbackPrice = 120;

  /// Extra buffer days for historical data (ensures enough data for analysis edge cases)
  static const int historyBufferDays = 30;

  /// Total required historical data days (lookbackPrice + buffer)
  static const int historyRequiredDays = lookbackPrice + historyBufferDays;

  /// Institutional data lookback days
  static const int institutionalLookbackDays = 10;

  /// Moving average days for volume calculation
  static const int volMa = 20;

  /// Days for range (support/resistance) detection
  static const int rangeLookback = 60;

  /// Window for Swing High/Low detection
  static const int swingWindow = 20;

  /// Price spike threshold percentage
  static const double priceSpikePercent = 3.0;

  /// Volume spike multiplier (vs 20-day average)
  /// 4.0x is highly selective - only exceptional volume anomalies
  /// Also requires price movement (see minPriceChangeForVolume)
  static const double volumeSpikeMult = 4.0;

  /// Minimum absolute price change required for volume spike signal
  /// Filters out volume spikes without meaningful price action
  /// 1.5% ensures the volume came with actual price movement
  static const double minPriceChangeForVolume = 0.015;

  /// Breakout buffer tolerance (1% for cleaner signals)
  /// Was 0.3% which triggered too many false positives
  static const double breakoutBuffer = 0.01;

  /// Breakdown buffer tolerance (0.5% - easier to trigger than breakout)
  /// Separate from breakout to allow more breakdown/S2W signals
  static const double breakdownBuffer = 0.005;

  /// Maximum distance for support/resistance to be considered relevant
  /// Support/resistance beyond this distance from current price is ignored
  /// 8% allows detecting nearby levels while filtering out irrelevant ones
  static const double maxSupportResistanceDistance = 0.08;

  // ==========================================
  // NewsRule Keywords (Configurable)
  // ==========================================

  /// Positive keywords for news sentiment analysis
  static const List<String> newsPositiveKeywords = [
    // 營收相關
    '營收創新高',
    '營收成長',
    '業績亮眼',
    '獲利創高',
    '毛利率上升',
    // 訂單/產能
    '訂單',
    '大單',
    '擴產',
    '產能滿載',
    '拿下',
    '接獲',
    // 法人動態
    '法說會',
    '外資買超',
    '投信買超',
    // 市場動態
    '利多',
    '漲停',
    '調升',
    '目標價',
    '看好',
    '突破',
    // 產業趨勢
    'AI',
    '人工智慧',
    '電動車',
    '半導體',
  ];

  /// Negative keywords for news sentiment analysis
  static const List<String> newsNegativeKeywords = [
    // 營收相關
    '營收衰退',
    '營收下滑',
    '獲利下滑',
    '虧損',
    '毛利率下降',
    // 訂單/產能
    '砍單',
    '減產',
    '庫存',
    '去化',
    // 市場動態
    '利空',
    '跌停',
    '調降',
    '下修',
    // 公司治理
    '減資',
    '違約',
    '掏空',
    '解任',
  ];

  /// Cooldown days for repeated recommendations
  static const int cooldownDays = 2;

  /// Cooldown score multiplier
  static const double cooldownMultiplier = 0.7;

  /// Maximum reasons per stock
  static const int maxReasonsPerStock = 2;

  /// Daily top N recommendations
  static const int dailyTopN = 10;

  /// Maximum stocks per industry in daily recommendations (v2)
  static const int maxPerIndustry = 3;

  // ==========================================
  // Technical Indicator Parameters
  // ==========================================

  /// RSI period (default 14)
  static const int rsiPeriod = 14;

  /// RSI overbought threshold (avoid buying when RSI > this)
  static const double rsiOverbought = 70.0;

  /// RSI oversold threshold (avoid selling when RSI < this)
  static const double rsiOversold = 30.0;

  /// RSI extreme overbought (very high risk zone)
  static const double rsiExtremeOverbought = 80.0;

  /// RSI extreme oversold (potential bounce zone)
  static const double rsiExtremeOversold = 20.0;

  /// KD period for %K calculation
  static const int kdPeriodK = 9;

  /// KD period for %D smoothing
  static const int kdPeriodD = 3;

  /// KD overbought threshold
  static const double kdOverbought = 80.0;

  /// KD oversold threshold
  static const double kdOversold = 20.0;

  /// Institutional consecutive days threshold for streak signal
  static const int institutionalStreakDays = 3;

  // ==========================================
  // 52-Week High/Low Parameters
  // ==========================================

  /// Trading days in a year (approximately 52 weeks * 5 days)
  static const int week52Days = 250;

  /// Buffer percentage for near 52-week high/low detection
  /// Within 2% of 52-week high/low triggers signal
  static const double week52NearThreshold = 0.02;

  // ==========================================
  // Moving Average Alignment Parameters
  // ==========================================

  /// MA periods for alignment check
  static const List<int> maAlignmentPeriods = [5, 10, 20, 60];

  /// Minimum separation between MAs for valid alignment (0.5%)
  static const double maMinSeparation = 0.005;

  // ==========================================
  // Phase 4: Extended Market Data Parameters
  // ==========================================

  /// Foreign shareholding increase threshold (%)
  /// Triggers when foreign ownership increases by this % over N days
  static const double foreignShareholdingIncreaseThreshold = 0.5;

  /// Days to look back for foreign shareholding change
  static const int foreignShareholdingLookbackDays = 5;

  /// High day trading ratio threshold (%)
  /// Stocks with day trading ratio above this are considered "hot"
  static const double dayTradingHighThreshold = 30.0;

  /// Extreme day trading ratio threshold (%)
  /// Very high day trading - speculative warning
  static const double dayTradingExtremeThreshold = 40.0;

  /// Large holder concentration threshold (%)
  /// Stocks with this % held by large shareholders (400+ lots)
  static const double concentrationHighThreshold = 60.0;

  // ==========================================
  // Phase 5: Price-Volume Divergence Parameters
  // ==========================================

  /// Days to analyze for price-volume divergence
  static const int priceVolumeLookbackDays = 5;

  /// Minimum price change threshold for divergence detection (%)
  /// Price must have moved at least this much for divergence to be meaningful
  static const double priceVolumePriceThreshold = 2.0;

  /// Volume change threshold for divergence detection (%)
  /// Volume change must be at least this much for divergence
  static const double priceVolumeVolumeThreshold = 20.0;

  /// High position threshold for "high volume breakout" signal (percentile)
  /// Price must be in top X% of 60-day range to be considered "high"
  static const double highPositionThreshold = 0.85;

  /// Low position threshold for "low volume accumulation" signal (percentile)
  /// Price must be in bottom X% of 60-day range to be considered "low"
  static const double lowPositionThreshold = 0.15;

  // ==========================================
  // Phase 6: Fundamental Analysis Parameters
  // ==========================================

  /// Revenue YoY growth surge threshold (%)
  /// Triggers when YoY growth exceeds this value
  static const double revenueYoySurgeThreshold = 30.0;

  /// Revenue YoY decline threshold (%)
  /// Triggers warning when YoY decline exceeds this value
  static const double revenueYoyDeclineThreshold = 20.0;

  /// Revenue MoM consecutive growth months
  /// Triggers when MoM is positive for N consecutive months
  /// NOTE: Set to 1 because TWSE Open Data only provides latest month
  static const int revenueMomConsecutiveMonths = 1;

  /// Revenue MoM growth threshold (%)
  /// Minimum MoM growth rate to be considered meaningful
  /// Lowered from 10% to 5% for broader signal coverage
  static const double revenueMomGrowthThreshold = 5.0;

  /// High dividend yield threshold (%)
  /// Stocks with yield above this are considered high yield
  static const double highDividendYieldThreshold = 5.0;

  /// PE undervalued threshold
  /// PE below this value (and > 0) is considered undervalued
  static const double peUndervaluedThreshold = 10.0;

  /// PE overvalued threshold
  /// PE above this value is considered overvalued
  static const double peOvervaluedThreshold = 50.0;

  /// PBR undervalued threshold
  /// PBR below 1.0 means trading below book value
  static const double pbrUndervaluedThreshold = 1.0;
}

/// Rule scores for each recommendation type
///
/// Score hierarchy reflects signal reliability:
/// - Reversal signals (35): Highest - trend change is most actionable
/// - Technical signals (25): Medium - support/resistance breaks
/// - Volume spike (22): Medium - now requires 4x vol + 1.5% price move
/// - Price spike (15): Lower - could be noise without volume
/// - Institutional (18): Important for Taiwan market - institutional flow drives prices
/// - News (8): Supplementary - context only
///
/// Maximum score is capped at 80 to prevent score inflation from multiple signals.
abstract final class RuleScores {
  /// Maximum score cap to prevent inflation
  static const int maxScore = 80;
  static const int reversalW2S = 35;
  static const int reversalS2W = 35;
  static const int techBreakout = 25;
  static const int techBreakdown = 25;
  static const int volumeSpike = 22; // Was 18, raised due to stricter criteria
  static const int priceSpike = 15;
  static const int institutionalShift = 18;
  static const int newsRelated = 8;

  /// Bonus: BREAKOUT + VOLUME_SPIKE
  static const int breakoutVolumeBonus = 6;

  /// Bonus: REVERSAL_* + VOLUME_SPIKE
  static const int reversalVolumeBonus = 6;

  /// Bonus: PATTERN (engulfing/star/soldiers) + VOLUME_SPIKE
  /// Strong candlestick patterns confirmed by volume are highly significant
  static const int patternVolumeBonus = 5;

  /// KD Golden Cross score
  static const int kdGoldenCross = 18;

  /// KD Death Cross score
  static const int kdDeathCross = 18;

  /// Institutional consecutive buy streak score
  static const int institutionalBuyStreak = 20;

  /// Institutional consecutive sell streak score
  static const int institutionalSellStreak = 20;

  // ==========================================
  // Candlestick Pattern Scores
  // ==========================================

  /// Doji pattern score (indecision)
  static const int patternDoji = 10;

  /// Engulfing pattern score (strong reversal)
  static const int patternEngulfing = 22;

  /// Hammer/Hanging Man score
  static const int patternHammer = 18;

  /// Gap pattern score
  static const int patternGap = 20;

  /// Morning/Evening Star score (3-candle reversal)
  static const int patternStar = 25;

  /// Three Soldiers/Crows score (strong trend)
  static const int patternThreeSoldiers = 22;

  // ==========================================
  // New Signal Scores (Phase 3)
  // ==========================================

  /// 52-week high score (strong bullish)
  static const int week52High = 28;

  /// 52-week low score (potential reversal or continuation down)
  /// Lower than 52-week high because catching falling knives is riskier
  static const int week52Low = 22;

  /// MA bullish alignment score (5>10>20>60)
  static const int maAlignmentBullish = 22;

  /// MA bearish alignment score (5<10<20<60)
  static const int maAlignmentBearish = 22;

  /// RSI extreme overbought score (warning signal)
  static const int rsiExtremeOverboughtSignal = 15;

  /// RSI extreme oversold score (potential bounce)
  static const int rsiExtremeOversoldSignal = 15;

  // ==========================================
  // Phase 4: Extended Market Data Scores
  // ==========================================

  /// Foreign shareholding increasing score
  static const int foreignShareholdingIncreasing = 18;

  /// Foreign shareholding decreasing score
  static const int foreignShareholdingDecreasing = 18;

  /// High day trading ratio score (hot stock)
  static const int dayTradingHigh = 12;

  /// Extreme day trading ratio score (speculative)
  static const int dayTradingExtreme = 15;

  /// High concentration ratio score
  static const int concentrationHigh = 16;

  // ==========================================
  // Phase 5: Price-Volume Divergence Scores
  // ==========================================

  /// Price up + volume down divergence (warning signal)
  static const int priceVolumeBullishDivergence = 15;

  /// Price down + volume up divergence (panic signal)
  static const int priceVolumeBearishDivergence = 18;

  /// High volume breakout at resistance (strong bullish)
  static const int highVolumeBreakout = 22;

  /// Low volume accumulation near support (potential reversal)
  static const int lowVolumeAccumulation = 16;

  // ==========================================
  // Phase 6: Fundamental Analysis Scores
  // ==========================================

  /// Revenue YoY surge score (strong fundamental)
  static const int revenueYoySurge = 20;

  /// Revenue YoY decline score (warning)
  static const int revenueYoyDecline = 15;

  /// Revenue MoM consecutive growth score
  static const int revenueMomGrowth = 15;

  /// High dividend yield score
  static const int highDividendYield = 18;

  /// PE undervalued score
  static const int peUndervalued = 15;

  /// PE overvalued score (warning)
  static const int peOvervalued = 10;

  /// PBR undervalued score
  static const int pbrUndervalued = 12;
}

/// Reason types enum
enum ReasonType {
  reversalW2S('REVERSAL_W2S', '弱轉強'),
  reversalS2W('REVERSAL_S2W', '強轉弱'),
  techBreakout('TECH_BREAKOUT', '技術突破'),
  techBreakdown('TECH_BREAKDOWN', '技術跌破'),
  volumeSpike('VOLUME_SPIKE', '放量異常'),
  priceSpike('PRICE_SPIKE', '價格異常'),
  institutionalShift('INSTITUTIONAL_SHIFT', '法人異常'),
  newsRelated('NEWS_RELATED', '新聞關聯'),
  // New technical indicator signals
  kdGoldenCross('KD_GOLDEN_CROSS', 'KD黃金交叉'),
  kdDeathCross('KD_DEATH_CROSS', 'KD死亡交叉'),
  institutionalBuyStreak('INSTITUTIONAL_BUY_STREAK', '法人連買'),
  institutionalSellStreak('INSTITUTIONAL_SELL_STREAK', '法人連賣'),
  // Candlestick pattern signals
  patternDoji('PATTERN_DOJI', '十字線'),
  patternBullishEngulfing('PATTERN_BULLISH_ENGULFING', '多頭吞噬'),
  patternBearishEngulfing('PATTERN_BEARISH_ENGULFING', '空頭吞噬'),
  patternHammer('PATTERN_HAMMER', '錘子線'),
  patternHangingMan('PATTERN_HANGING_MAN', '吊人線'),
  patternGapUp('PATTERN_GAP_UP', '跳空上漲'),
  patternGapDown('PATTERN_GAP_DOWN', '跳空下跌'),
  patternMorningStar('PATTERN_MORNING_STAR', '晨星'),
  patternEveningStar('PATTERN_EVENING_STAR', '暮星'),
  patternThreeWhiteSoldiers('PATTERN_THREE_WHITE_SOLDIERS', '三白兵'),
  patternThreeBlackCrows('PATTERN_THREE_BLACK_CROWS', '三黑鴉'),
  // Phase 3: New scan/alert signals
  week52High('WEEK_52_HIGH', '52週新高'),
  week52Low('WEEK_52_LOW', '52週新低'),
  maAlignmentBullish('MA_ALIGNMENT_BULLISH', '多頭排列'),
  maAlignmentBearish('MA_ALIGNMENT_BEARISH', '空頭排列'),
  rsiExtremeOverbought('RSI_EXTREME_OVERBOUGHT', 'RSI極度超買'),
  rsiExtremeOversold('RSI_EXTREME_OVERSOLD', 'RSI極度超賣'),
  // Phase 4: Extended market data signals
  foreignShareholdingIncreasing('FOREIGN_SHAREHOLDING_INCREASING', '外資持股增加'),
  foreignShareholdingDecreasing('FOREIGN_SHAREHOLDING_DECREASING', '外資持股減少'),
  dayTradingHigh('DAY_TRADING_HIGH', '高當沖比例'),
  dayTradingExtreme('DAY_TRADING_EXTREME', '極高當沖比例'),
  concentrationHigh('CONCENTRATION_HIGH', '籌碼集中'),
  // Phase 5: Price-volume divergence signals
  priceVolumeBullishDivergence('PRICE_VOLUME_BULLISH_DIVERGENCE', '價漲量縮'),
  priceVolumeBearishDivergence('PRICE_VOLUME_BEARISH_DIVERGENCE', '價跌量增'),
  highVolumeBreakout('HIGH_VOLUME_BREAKOUT', '高檔爆量'),
  lowVolumeAccumulation('LOW_VOLUME_ACCUMULATION', '低檔吸籌'),
  // Phase 6: Fundamental analysis signals
  revenueYoySurge('REVENUE_YOY_SURGE', '營收年增暴增'),
  revenueYoyDecline('REVENUE_YOY_DECLINE', '營收年減衰退'),
  revenueMomGrowth('REVENUE_MOM_GROWTH', '營收月增持續'),
  highDividendYield('HIGH_DIVIDEND_YIELD', '高殖利率'),
  peUndervalued('PE_UNDERVALUED', 'PE低估'),
  peOvervalued('PE_OVERVALUED', 'PE高估'),
  pbrUndervalued('PBR_UNDERVALUED', '股價淨值比低');

  const ReasonType(this.code, this.label);

  final String code;
  final String label;

  int get score => switch (this) {
    ReasonType.reversalW2S => RuleScores.reversalW2S,
    ReasonType.reversalS2W => RuleScores.reversalS2W,
    ReasonType.techBreakout => RuleScores.techBreakout,
    ReasonType.techBreakdown => RuleScores.techBreakdown,
    ReasonType.volumeSpike => RuleScores.volumeSpike,
    ReasonType.priceSpike => RuleScores.priceSpike,
    ReasonType.institutionalShift => RuleScores.institutionalShift,
    ReasonType.newsRelated => RuleScores.newsRelated,
    ReasonType.kdGoldenCross => RuleScores.kdGoldenCross,
    ReasonType.kdDeathCross => RuleScores.kdDeathCross,
    ReasonType.institutionalBuyStreak => RuleScores.institutionalBuyStreak,
    ReasonType.institutionalSellStreak => RuleScores.institutionalSellStreak,
    // Candlestick patterns
    ReasonType.patternDoji => RuleScores.patternDoji,
    ReasonType.patternBullishEngulfing => RuleScores.patternEngulfing,
    ReasonType.patternBearishEngulfing => RuleScores.patternEngulfing,
    ReasonType.patternHammer => RuleScores.patternHammer,
    ReasonType.patternHangingMan => RuleScores.patternHammer,
    ReasonType.patternGapUp => RuleScores.patternGap,
    ReasonType.patternGapDown => RuleScores.patternGap,
    ReasonType.patternMorningStar => RuleScores.patternStar,
    ReasonType.patternEveningStar => RuleScores.patternStar,
    ReasonType.patternThreeWhiteSoldiers => RuleScores.patternThreeSoldiers,
    ReasonType.patternThreeBlackCrows => RuleScores.patternThreeSoldiers,
    // Phase 3 signals
    ReasonType.week52High => RuleScores.week52High,
    ReasonType.week52Low => RuleScores.week52Low,
    ReasonType.maAlignmentBullish => RuleScores.maAlignmentBullish,
    ReasonType.maAlignmentBearish => RuleScores.maAlignmentBearish,
    ReasonType.rsiExtremeOverbought => RuleScores.rsiExtremeOverboughtSignal,
    ReasonType.rsiExtremeOversold => RuleScores.rsiExtremeOversoldSignal,
    // Phase 4 signals
    ReasonType.foreignShareholdingIncreasing =>
      RuleScores.foreignShareholdingIncreasing,
    ReasonType.foreignShareholdingDecreasing =>
      RuleScores.foreignShareholdingDecreasing,
    ReasonType.dayTradingHigh => RuleScores.dayTradingHigh,
    ReasonType.dayTradingExtreme => RuleScores.dayTradingExtreme,
    ReasonType.concentrationHigh => RuleScores.concentrationHigh,
    // Phase 5 signals
    ReasonType.priceVolumeBullishDivergence =>
      RuleScores.priceVolumeBullishDivergence,
    ReasonType.priceVolumeBearishDivergence =>
      RuleScores.priceVolumeBearishDivergence,
    ReasonType.highVolumeBreakout => RuleScores.highVolumeBreakout,
    ReasonType.lowVolumeAccumulation => RuleScores.lowVolumeAccumulation,
    // Phase 6 signals
    ReasonType.revenueYoySurge => RuleScores.revenueYoySurge,
    ReasonType.revenueYoyDecline => RuleScores.revenueYoyDecline,
    ReasonType.revenueMomGrowth => RuleScores.revenueMomGrowth,
    ReasonType.highDividendYield => RuleScores.highDividendYield,
    ReasonType.peUndervalued => RuleScores.peUndervalued,
    ReasonType.peOvervalued => RuleScores.peOvervalued,
    ReasonType.pbrUndervalued => RuleScores.pbrUndervalued,
  };
}

/// Trend state for analysis
enum TrendState {
  up('UP', '上升'),
  down('DOWN', '下跌'),
  range('RANGE', '盤整');

  const TrendState(this.code, this.label);

  final String code;
  final String label;
}

/// Reversal state for analysis
enum ReversalState {
  none('NONE', '無'),
  weakToStrong('W2S', '弱轉強'),
  strongToWeak('S2W', '強轉弱');

  const ReversalState(this.code, this.label);

  final String code;
  final String label;
}

/// News category
enum NewsCategory {
  earnings('EARNINGS', '財報'),
  policy('POLICY', '政策'),
  industry('INDUSTRY', '產業'),
  companyEvent('COMPANY_EVENT', '公司事件'),
  other('OTHER', '其他');

  const NewsCategory(this.code, this.label);

  final String code;
  final String label;
}

/// Update run status
enum UpdateStatus {
  success('SUCCESS'),
  failed('FAILED'),
  partial('PARTIAL');

  const UpdateStatus(this.code);

  final String code;
}

/// Stock market type
enum StockMarket {
  twse('TWSE', '上市'),
  tpex('TPEx', '上櫃');

  const StockMarket(this.code, this.label);

  final String code;
  final String label;
}
