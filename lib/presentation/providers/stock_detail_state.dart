import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/domain/models/stock_summary.dart';

// ==================================================
// 子狀態類別
// ==================================================

/// 價格相關狀態：股票資訊、價格、歷史、分析
class StockPriceState {
  const StockPriceState({
    this.stock,
    this.latestPrice,
    this.previousPrice,
    this.priceHistory = const [],
    this.analysis,
  });

  final StockMasterEntry? stock;
  final DailyPriceEntry? latestPrice;
  final DailyPriceEntry? previousPrice;
  final List<DailyPriceEntry> priceHistory;
  final DailyAnalysisEntry? analysis;

  /// 漲跌幅百分比
  ///
  /// 委託給 PriceCalculator，優先使用 API 漲跌價差，回退到歷史收盤價
  double? get priceChange {
    return PriceCalculator.calculatePriceChange(priceHistory, latestPrice);
  }

  StockPriceState copyWith({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
  }) {
    return StockPriceState(
      stock: stock ?? this.stock,
      latestPrice: latestPrice ?? this.latestPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      analysis: analysis ?? this.analysis,
    );
  }
}

/// 基本面狀態：營收、股利、本益比、EPS、季度指標
class FundamentalsState {
  const FundamentalsState({
    this.revenueHistory = const [],
    this.dividendHistory = const [],
    this.latestPER,
    this.latestQuarterMetrics = const {},
    this.epsHistory = const [],
  });

  final List<FinMindRevenue> revenueHistory;
  final List<FinMindDividend> dividendHistory;
  final FinMindPER? latestPER;
  final Map<String, double> latestQuarterMetrics;
  final List<FinancialDataEntry> epsHistory;

  FundamentalsState copyWith({
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    FinMindPER? latestPER,
    Map<String, double>? latestQuarterMetrics,
    List<FinancialDataEntry>? epsHistory,
  }) {
    return FundamentalsState(
      revenueHistory: revenueHistory ?? this.revenueHistory,
      dividendHistory: dividendHistory ?? this.dividendHistory,
      latestPER: latestPER ?? this.latestPER,
      latestQuarterMetrics: latestQuarterMetrics ?? this.latestQuarterMetrics,
      epsHistory: epsHistory ?? this.epsHistory,
    );
  }
}

/// 籌碼分析狀態：法人進出、融資融券、當沖、持股比例等
class ChipAnalysisState {
  const ChipAnalysisState({
    this.institutionalHistory = const [],
    this.marginHistory = const [],
    this.marginTradingHistory = const [],
    this.dayTradingHistory = const [],
    this.shareholdingHistory = const [],
    this.holdingDistribution = const [],
    this.insiderHistory = const [],
    this.chipStrength,
    this.hasInstitutionalError = false,
  });

  final List<DailyInstitutionalEntry> institutionalHistory;
  final List<FinMindMarginData> marginHistory;
  final List<MarginTradingEntry> marginTradingHistory;
  final List<DayTradingEntry> dayTradingHistory;
  final List<ShareholdingEntry> shareholdingHistory;
  final List<HoldingDistributionEntry> holdingDistribution;
  final List<InsiderHoldingEntry> insiderHistory;
  final ChipStrengthResult? chipStrength;

  /// 法人資料載入時是否發生錯誤（部分錯誤，不影響主要資料）
  final bool hasInstitutionalError;

  ChipAnalysisState copyWith({
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<MarginTradingEntry>? marginTradingHistory,
    List<DayTradingEntry>? dayTradingHistory,
    List<ShareholdingEntry>? shareholdingHistory,
    List<HoldingDistributionEntry>? holdingDistribution,
    List<InsiderHoldingEntry>? insiderHistory,
    ChipStrengthResult? chipStrength,
    bool? hasInstitutionalError,
  }) {
    return ChipAnalysisState(
      institutionalHistory: institutionalHistory ?? this.institutionalHistory,
      marginHistory: marginHistory ?? this.marginHistory,
      marginTradingHistory: marginTradingHistory ?? this.marginTradingHistory,
      dayTradingHistory: dayTradingHistory ?? this.dayTradingHistory,
      shareholdingHistory: shareholdingHistory ?? this.shareholdingHistory,
      holdingDistribution: holdingDistribution ?? this.holdingDistribution,
      insiderHistory: insiderHistory ?? this.insiderHistory,
      chipStrength: chipStrength ?? this.chipStrength,
      hasInstitutionalError:
          hasInstitutionalError ?? this.hasInstitutionalError,
    );
  }
}

/// 各區塊載入狀態旗標
class LoadingState {
  const LoadingState({
    this.isLoading = false,
    this.isLoadingMargin = false,
    this.isLoadingFundamentals = false,
    this.isLoadingInsider = false,
    this.isLoadingChip = false,
  });

  final bool isLoading;
  final bool isLoadingMargin;
  final bool isLoadingFundamentals;
  final bool isLoadingInsider;
  final bool isLoadingChip;

  LoadingState copyWith({
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    bool? isLoadingInsider,
    bool? isLoadingChip,
  }) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMargin: isLoadingMargin ?? this.isLoadingMargin,
      isLoadingFundamentals:
          isLoadingFundamentals ?? this.isLoadingFundamentals,
      isLoadingInsider: isLoadingInsider ?? this.isLoadingInsider,
      isLoadingChip: isLoadingChip ?? this.isLoadingChip,
    );
  }
}

// ==================================================
// 股票詳情狀態
// ==================================================

/// 股票詳情頁面狀態
class StockDetailState {
  const StockDetailState({
    this.price = const StockPriceState(),
    this.fundamentals = const FundamentalsState(),
    this.chip = const ChipAnalysisState(),
    this.loading = const LoadingState(),
    this.isInWatchlist = false,
    this.error,
    this.dataDate,
    this.hasDataMismatch = false,
    this.reasons = const [],
    this.aiSummary,
    this.recentNews = const [],
  });

  final StockPriceState price;
  final FundamentalsState fundamentals;
  final ChipAnalysisState chip;
  final LoadingState loading;

  // 其他直接欄位
  final bool isInWatchlist;
  final String? error;

  /// 同步後的資料日期 — 所有顯示資料應來自此日期
  final DateTime? dataDate;

  /// 價格與法人資料日期不一致時為 true
  final bool hasDataMismatch;

  final List<DailyReasonEntry> reasons;
  final StockSummary? aiSummary;
  final List<NewsItemEntry> recentNews;

  // 便捷存取 — 減少 header / tab 的鏈式存取

  double? get priceChange => price.priceChange;
  String? get stockName => price.stock?.name;
  String? get stockMarket => price.stock?.market;
  String? get stockIndustry => price.stock?.industry;
  double? get latestClose => price.latestPrice?.close;
  String get trendLabel => S.getTrendLabel(price.analysis?.trendState);
  String? get reversalLabel =>
      S.getReversalLabel(price.analysis?.reversalState);

  StockDetailState copyWith({
    // Price fields
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
    // Fundamentals fields
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    FinMindPER? latestPER,
    Map<String, double>? latestQuarterMetrics,
    List<FinancialDataEntry>? epsHistory,
    // Chip fields
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<MarginTradingEntry>? marginTradingHistory,
    List<DayTradingEntry>? dayTradingHistory,
    List<ShareholdingEntry>? shareholdingHistory,
    List<HoldingDistributionEntry>? holdingDistribution,
    List<InsiderHoldingEntry>? insiderHistory,
    ChipStrengthResult? chipStrength,
    bool? hasInstitutionalError,
    // Loading fields
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    bool? isLoadingInsider,
    bool? isLoadingChip,
    // Direct fields
    bool? isInWatchlist,
    Object? error = sentinel,
    DateTime? dataDate,
    bool? hasDataMismatch,
    List<DailyReasonEntry>? reasons,
    StockSummary? aiSummary,
    List<NewsItemEntry>? recentNews,
  }) {
    // Only create new sub-state objects when their fields are being updated
    final needsPriceUpdate =
        stock != null ||
        latestPrice != null ||
        previousPrice != null ||
        priceHistory != null ||
        analysis != null;

    final needsFundamentalsUpdate =
        revenueHistory != null ||
        dividendHistory != null ||
        latestPER != null ||
        latestQuarterMetrics != null ||
        epsHistory != null;

    final needsChipUpdate =
        institutionalHistory != null ||
        marginHistory != null ||
        marginTradingHistory != null ||
        dayTradingHistory != null ||
        shareholdingHistory != null ||
        holdingDistribution != null ||
        insiderHistory != null ||
        chipStrength != null ||
        hasInstitutionalError != null;

    final needsLoadingUpdate =
        isLoading != null ||
        isLoadingMargin != null ||
        isLoadingFundamentals != null ||
        isLoadingInsider != null ||
        isLoadingChip != null;

    return StockDetailState(
      price: needsPriceUpdate
          ? price.copyWith(
              stock: stock,
              latestPrice: latestPrice,
              previousPrice: previousPrice,
              priceHistory: priceHistory,
              analysis: analysis,
            )
          : price,
      fundamentals: needsFundamentalsUpdate
          ? fundamentals.copyWith(
              revenueHistory: revenueHistory,
              dividendHistory: dividendHistory,
              latestPER: latestPER,
              latestQuarterMetrics: latestQuarterMetrics,
              epsHistory: epsHistory,
            )
          : fundamentals,
      chip: needsChipUpdate
          ? chip.copyWith(
              institutionalHistory: institutionalHistory,
              marginHistory: marginHistory,
              marginTradingHistory: marginTradingHistory,
              dayTradingHistory: dayTradingHistory,
              shareholdingHistory: shareholdingHistory,
              holdingDistribution: holdingDistribution,
              insiderHistory: insiderHistory,
              chipStrength: chipStrength,
              hasInstitutionalError: hasInstitutionalError,
            )
          : chip,
      loading: needsLoadingUpdate
          ? loading.copyWith(
              isLoading: isLoading,
              isLoadingMargin: isLoadingMargin,
              isLoadingFundamentals: isLoadingFundamentals,
              isLoadingInsider: isLoadingInsider,
              isLoadingChip: isLoadingChip,
            )
          : loading,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      error: error == sentinel ? this.error : error as String?,
      dataDate: dataDate ?? this.dataDate,
      hasDataMismatch: hasDataMismatch ?? this.hasDataMismatch,
      reasons: reasons ?? this.reasons,
      aiSummary: aiSummary ?? this.aiSummary,
      recentNews: recentNews ?? this.recentNews,
    );
  }
}
