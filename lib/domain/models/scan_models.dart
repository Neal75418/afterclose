// Scan screen models: filter/sort enums and the [ScanStockItem] data class.
//
// These live in the domain layer so that both presentation (providers/screens)
// and domain services can reference them without violating layer boundaries.
import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Filter options for scan screen
enum ScanFilter {
  // All
  all('scan.filterAll', null, ScanFilterGroup.all),

  // Reversal signals
  reversalW2S(
    'scan.filterReversalW2S',
    'REVERSAL_W2S',
    ScanFilterGroup.reversal,
  ),
  reversalS2W(
    'scan.filterReversalS2W',
    'REVERSAL_S2W',
    ScanFilterGroup.reversal,
  ),

  // Technical breakout/breakdown
  breakout('scan.filterBreakout', 'TECH_BREAKOUT', ScanFilterGroup.technical),
  breakdown(
    'scan.filterBreakdown',
    'TECH_BREAKDOWN',
    ScanFilterGroup.technical,
  ),

  // Volume signals
  volumeSpike('scan.filterVolumeSpike', 'VOLUME_SPIKE', ScanFilterGroup.volume),

  // Price signals
  priceSpike('scan.filterPriceSpike', 'PRICE_SPIKE', ScanFilterGroup.price),

  // KD signals
  kdGoldenCross(
    'scan.filterKdGoldenCross',
    'KD_GOLDEN_CROSS',
    ScanFilterGroup.indicator,
  ),
  kdDeathCross(
    'scan.filterKdDeathCross',
    'KD_DEATH_CROSS',
    ScanFilterGroup.indicator,
  ),

  // RSI signals
  rsiOverbought(
    'scan.filterRsiOverbought',
    'RSI_EXTREME_OVERBOUGHT',
    ScanFilterGroup.indicator,
  ),
  rsiOversold(
    'scan.filterRsiOversold',
    'RSI_EXTREME_OVERSOLD',
    ScanFilterGroup.indicator,
  ),

  // Institutional signals
  institutionalBuy(
    'scan.filterInstitutionalBuy',
    'INSTITUTIONAL_BUY',
    ScanFilterGroup.institutional,
  ),
  institutionalSell(
    'scan.filterInstitutionalSell',
    'INSTITUTIONAL_SELL',
    ScanFilterGroup.institutional,
  ),
  institutionalBuyStreak(
    'scan.filterInstitutionalBuyStreak',
    'INSTITUTIONAL_BUY_STREAK',
    ScanFilterGroup.institutional,
  ),
  institutionalSellStreak(
    'scan.filterInstitutionalSellStreak',
    'INSTITUTIONAL_SELL_STREAK',
    ScanFilterGroup.institutional,
  ),

  // Extended market data signals (Phase 4)
  dayTradingHigh(
    'scan.filterDayTradingHigh',
    'DAY_TRADING_HIGH',
    ScanFilterGroup.extendedMarket,
  ),
  dayTradingExtreme(
    'scan.filterDayTradingExtreme',
    'DAY_TRADING_EXTREME',
    ScanFilterGroup.extendedMarket,
  ),
  // NOTE: concentrationHigh removed - requires paid API (股權分散表)

  // News signals
  newsRelated('scan.filterNewsRelated', 'NEWS_RELATED', ScanFilterGroup.news),

  // 52-week signals
  week52High('scan.filterWeek52High', 'WEEK_52_HIGH', ScanFilterGroup.week52),
  week52Low('scan.filterWeek52Low', 'WEEK_52_LOW', ScanFilterGroup.week52),

  // MA alignment signals
  maAlignmentBullish(
    'scan.filterMaAlignmentBullish',
    'MA_ALIGNMENT_BULLISH',
    ScanFilterGroup.maAlignment,
  ),
  maAlignmentBearish(
    'scan.filterMaAlignmentBearish',
    'MA_ALIGNMENT_BEARISH',
    ScanFilterGroup.maAlignment,
  ),

  // Candlestick patterns - neutral
  patternDoji(
    'scan.filterPatternDoji',
    'PATTERN_DOJI',
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bullish
  patternBullishEngulfing(
    'scan.filterPatternBullishEngulfing',
    'PATTERN_BULLISH_ENGULFING',
    ScanFilterGroup.pattern,
  ),
  patternHammer(
    'scan.filterPatternHammer',
    'PATTERN_HAMMER',
    ScanFilterGroup.pattern,
  ),
  patternMorningStar(
    'scan.filterPatternMorningStar',
    'PATTERN_MORNING_STAR',
    ScanFilterGroup.pattern,
  ),
  patternThreeWhiteSoldiers(
    'scan.filterPatternThreeWhiteSoldiers',
    'PATTERN_THREE_WHITE_SOLDIERS',
    ScanFilterGroup.pattern,
  ),
  patternGapUp(
    'scan.filterPatternGapUp',
    'PATTERN_GAP_UP',
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bearish
  patternBearishEngulfing(
    'scan.filterPatternBearishEngulfing',
    'PATTERN_BEARISH_ENGULFING',
    ScanFilterGroup.pattern,
  ),
  patternHangingMan(
    'scan.filterPatternHangingMan',
    'PATTERN_HANGING_MAN',
    ScanFilterGroup.pattern,
  ),
  patternEveningStar(
    'scan.filterPatternEveningStar',
    'PATTERN_EVENING_STAR',
    ScanFilterGroup.pattern,
  ),
  patternThreeBlackCrows(
    'scan.filterPatternThreeBlackCrows',
    'PATTERN_THREE_BLACK_CROWS',
    ScanFilterGroup.pattern,
  ),
  patternGapDown(
    'scan.filterPatternGapDown',
    'PATTERN_GAP_DOWN',
    ScanFilterGroup.pattern,
  ),

  // Price-volume divergence signals
  priceVolumeBullishDivergence(
    'scan.filterPriceVolumeBullishDivergence',
    'PRICE_VOLUME_BULLISH_DIVERGENCE',
    ScanFilterGroup.priceVolume,
  ),
  priceVolumeBearishDivergence(
    'scan.filterPriceVolumeBearishDivergence',
    'PRICE_VOLUME_BEARISH_DIVERGENCE',
    ScanFilterGroup.priceVolume,
  ),
  highVolumeBreakout(
    'scan.filterHighVolumeBreakout',
    'HIGH_VOLUME_BREAKOUT',
    ScanFilterGroup.priceVolume,
  ),
  lowVolumeAccumulation(
    'scan.filterLowVolumeAccumulation',
    'LOW_VOLUME_ACCUMULATION',
    ScanFilterGroup.priceVolume,
  ),

  // Fundamental analysis signals (基本面訊號)
  revenueYoySurge(
    'scan.filterRevenueYoySurge',
    'REVENUE_YOY_SURGE',
    ScanFilterGroup.fundamental,
  ),
  revenueYoyDecline(
    'scan.filterRevenueYoyDecline',
    'REVENUE_YOY_DECLINE',
    ScanFilterGroup.fundamental,
  ),
  revenueMomGrowth(
    'scan.filterRevenueMomGrowth',
    'REVENUE_MOM_GROWTH',
    ScanFilterGroup.fundamental,
  ),
  highDividendYield(
    'scan.filterHighDividendYield',
    'HIGH_DIVIDEND_YIELD',
    ScanFilterGroup.fundamental,
  ),
  peUndervalued(
    'scan.filterPeUndervalued',
    'PE_UNDERVALUED',
    ScanFilterGroup.fundamental,
  ),
  peOvervalued(
    'scan.filterPeOvervalued',
    'PE_OVERVALUED',
    ScanFilterGroup.fundamental,
  ),
  pbrUndervalued(
    'scan.filterPbrUndervalued',
    'PBR_UNDERVALUED',
    ScanFilterGroup.fundamental,
  );

  const ScanFilter(this.labelKey, this.reasonCode, this.group);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;
  final String? reasonCode;
  final ScanFilterGroup group;
}

/// Group for organizing scan filters in UI
enum ScanFilterGroup {
  all('scan.groupAll'),
  reversal('scan.groupReversal'),
  technical('scan.groupTechnical'),
  volume('scan.groupVolume'),
  price('scan.groupPrice'),
  indicator('scan.groupIndicator'),
  institutional('scan.groupInstitutional'),
  extendedMarket('scan.groupExtendedMarket'),
  news('scan.groupNews'),
  week52('scan.groupWeek52'),
  maAlignment('scan.groupMaAlignment'),
  pattern('scan.groupPattern'),
  priceVolume('scan.groupPriceVolume'),
  fundamental('scan.groupFundamental');

  const ScanFilterGroup(this.labelKey);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;

  /// Get all filters in this group
  List<ScanFilter> get filters =>
      ScanFilter.values.where((f) => f.group == this).toList();
}

/// Sort options for scan screen
enum ScanSort {
  scoreDesc('scan.sortScoreDesc'),
  scoreAsc('scan.sortScoreAsc'),
  priceChangeDesc('scan.sortPriceChangeDesc'),
  priceChangeAsc('scan.sortPriceChangeAsc');

  const ScanSort(this.labelKey);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;
}

/// A single stock item displayed in the scan screen.
class ScanStockItem {
  const ScanStockItem({
    required this.symbol,
    required this.score,
    this.stockName,
    this.market,
    this.industry,
    this.latestClose,
    this.priceChange,
    this.volume,
    this.trendState,
    this.reasons = const [],
    this.isInWatchlist = false,
    this.recentPrices,
  });

  final String symbol;
  final double score;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;

  /// 產業類別
  final String? industry;
  final double? latestClose;
  final double? priceChange;
  final double? volume;
  final String? trendState;
  final List<DailyReasonEntry> reasons;
  final bool isInWatchlist;
  final List<double>? recentPrices;

  /// Get trend icon
  String get trendIcon => trendState.trendEmoji;

  /// Create a copy with modified fields
  ScanStockItem copyWith({bool? isInWatchlist}) {
    return ScanStockItem(
      symbol: symbol,
      score: score,
      stockName: stockName,
      market: market,
      industry: industry,
      latestClose: latestClose,
      priceChange: priceChange,
      volume: volume,
      trendState: trendState,
      reasons: reasons,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      recentPrices: recentPrices,
    );
  }
}
