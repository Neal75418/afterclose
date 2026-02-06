// Scan screen models: filter/sort enums and the [ScanStockItem] data class.
//
// These live in the domain layer so that both presentation (providers/screens)
// and domain services can reference them without violating layer boundaries.
import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/signal_names.dart';

/// Filter options for scan screen
enum ScanFilter {
  // All
  all('scan.filterAll', null, ScanFilterGroup.all),

  // Reversal signals
  reversalW2S(
    'scan.filterReversalW2S',
    SignalName.reversalW2S,
    ScanFilterGroup.reversal,
  ),
  reversalS2W(
    'scan.filterReversalS2W',
    SignalName.reversalS2W,
    ScanFilterGroup.reversal,
  ),

  // Technical breakout/breakdown
  breakout(
    'scan.filterBreakout',
    SignalName.techBreakout,
    ScanFilterGroup.technical,
  ),
  breakdown(
    'scan.filterBreakdown',
    SignalName.techBreakdown,
    ScanFilterGroup.technical,
  ),

  // Volume signals
  volumeSpike(
    'scan.filterVolumeSpike',
    SignalName.volumeSpike,
    ScanFilterGroup.volume,
  ),

  // Price signals
  priceSpike(
    'scan.filterPriceSpike',
    SignalName.priceSpike,
    ScanFilterGroup.price,
  ),

  // KD signals
  kdGoldenCross(
    'scan.filterKdGoldenCross',
    SignalName.kdGoldenCross,
    ScanFilterGroup.indicator,
  ),
  kdDeathCross(
    'scan.filterKdDeathCross',
    SignalName.kdDeathCross,
    ScanFilterGroup.indicator,
  ),

  // RSI signals
  rsiOverbought(
    'scan.filterRsiOverbought',
    SignalName.rsiExtremeOverbought,
    ScanFilterGroup.indicator,
  ),
  rsiOversold(
    'scan.filterRsiOversold',
    SignalName.rsiExtremeOversold,
    ScanFilterGroup.indicator,
  ),

  // Institutional signals
  institutionalBuy(
    'scan.filterInstitutionalBuy',
    SignalName.institutionalBuy,
    ScanFilterGroup.institutional,
  ),
  institutionalSell(
    'scan.filterInstitutionalSell',
    SignalName.institutionalSell,
    ScanFilterGroup.institutional,
  ),
  institutionalBuyStreak(
    'scan.filterInstitutionalBuyStreak',
    SignalName.institutionalBuyStreak,
    ScanFilterGroup.institutional,
  ),
  institutionalSellStreak(
    'scan.filterInstitutionalSellStreak',
    SignalName.institutionalSellStreak,
    ScanFilterGroup.institutional,
  ),

  // Extended market data signals (Phase 4)
  dayTradingHigh(
    'scan.filterDayTradingHigh',
    SignalName.dayTradingHigh,
    ScanFilterGroup.extendedMarket,
  ),
  dayTradingExtreme(
    'scan.filterDayTradingExtreme',
    SignalName.dayTradingExtreme,
    ScanFilterGroup.extendedMarket,
  ),
  // NOTE: concentrationHigh removed - requires paid API (股權分散表)

  // News signals
  newsRelated(
    'scan.filterNewsRelated',
    SignalName.newsRelated,
    ScanFilterGroup.news,
  ),

  // 52-week signals
  week52High(
    'scan.filterWeek52High',
    SignalName.week52High,
    ScanFilterGroup.week52,
  ),
  week52Low(
    'scan.filterWeek52Low',
    SignalName.week52Low,
    ScanFilterGroup.week52,
  ),

  // MA alignment signals
  maAlignmentBullish(
    'scan.filterMaAlignmentBullish',
    SignalName.maAlignmentBullish,
    ScanFilterGroup.maAlignment,
  ),
  maAlignmentBearish(
    'scan.filterMaAlignmentBearish',
    SignalName.maAlignmentBearish,
    ScanFilterGroup.maAlignment,
  ),

  // Candlestick patterns - neutral
  patternDoji(
    'scan.filterPatternDoji',
    SignalName.patternDoji,
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bullish
  patternBullishEngulfing(
    'scan.filterPatternBullishEngulfing',
    SignalName.patternBullishEngulfing,
    ScanFilterGroup.pattern,
  ),
  patternHammer(
    'scan.filterPatternHammer',
    SignalName.patternHammer,
    ScanFilterGroup.pattern,
  ),
  patternMorningStar(
    'scan.filterPatternMorningStar',
    SignalName.patternMorningStar,
    ScanFilterGroup.pattern,
  ),
  patternThreeWhiteSoldiers(
    'scan.filterPatternThreeWhiteSoldiers',
    SignalName.patternThreeWhiteSoldiers,
    ScanFilterGroup.pattern,
  ),
  patternGapUp(
    'scan.filterPatternGapUp',
    SignalName.patternGapUp,
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bearish
  patternBearishEngulfing(
    'scan.filterPatternBearishEngulfing',
    SignalName.patternBearishEngulfing,
    ScanFilterGroup.pattern,
  ),
  patternHangingMan(
    'scan.filterPatternHangingMan',
    SignalName.patternHangingMan,
    ScanFilterGroup.pattern,
  ),
  patternEveningStar(
    'scan.filterPatternEveningStar',
    SignalName.patternEveningStar,
    ScanFilterGroup.pattern,
  ),
  patternThreeBlackCrows(
    'scan.filterPatternThreeBlackCrows',
    SignalName.patternThreeBlackCrows,
    ScanFilterGroup.pattern,
  ),
  patternGapDown(
    'scan.filterPatternGapDown',
    SignalName.patternGapDown,
    ScanFilterGroup.pattern,
  ),

  // Price-volume divergence signals
  priceVolumeBullishDivergence(
    'scan.filterPriceVolumeBullishDivergence',
    SignalName.priceVolumeBullishDivergence,
    ScanFilterGroup.priceVolume,
  ),
  priceVolumeBearishDivergence(
    'scan.filterPriceVolumeBearishDivergence',
    SignalName.priceVolumeBearishDivergence,
    ScanFilterGroup.priceVolume,
  ),
  highVolumeBreakout(
    'scan.filterHighVolumeBreakout',
    SignalName.highVolumeBreakout,
    ScanFilterGroup.priceVolume,
  ),
  lowVolumeAccumulation(
    'scan.filterLowVolumeAccumulation',
    SignalName.lowVolumeAccumulation,
    ScanFilterGroup.priceVolume,
  ),

  // Fundamental analysis signals (基本面訊號)
  revenueYoySurge(
    'scan.filterRevenueYoySurge',
    SignalName.revenueYoySurge,
    ScanFilterGroup.fundamental,
  ),
  revenueYoyDecline(
    'scan.filterRevenueYoyDecline',
    SignalName.revenueYoyDecline,
    ScanFilterGroup.fundamental,
  ),
  revenueMomGrowth(
    'scan.filterRevenueMomGrowth',
    SignalName.revenueMomGrowth,
    ScanFilterGroup.fundamental,
  ),
  highDividendYield(
    'scan.filterHighDividendYield',
    SignalName.highDividendYield,
    ScanFilterGroup.fundamental,
  ),
  peUndervalued(
    'scan.filterPeUndervalued',
    SignalName.peUndervalued,
    ScanFilterGroup.fundamental,
  ),
  peOvervalued(
    'scan.filterPeOvervalued',
    SignalName.peOvervalued,
    ScanFilterGroup.fundamental,
  ),
  pbrUndervalued(
    'scan.filterPbrUndervalued',
    SignalName.pbrUndervalued,
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
  ScanStockItem({
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

  /// 預計算的 reasonType 列表（避免在 Widget build 中重複轉換）
  late final List<String> reasonTypes = reasons
      .map((r) => r.reasonType)
      .toList();

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
