import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// ==================================================
// Stock Detail State
// ==================================================

/// State for stock detail screen
class StockDetailState {
  const StockDetailState({
    this.stock,
    this.latestPrice,
    this.priceHistory = const [],
    this.analysis,
    this.reasons = const [],
    this.institutionalHistory = const [],
    this.marginHistory = const [],
    this.revenueHistory = const [],
    this.dividendHistory = const [],
    this.latestPER,
    this.recentNews = const [],
    this.isInWatchlist = false,
    this.isLoading = false,
    this.isLoadingMargin = false,
    this.isLoadingFundamentals = false,
    this.error,
    this.dataDate,
    this.hasDataMismatch = false,
  });

  final StockMasterEntry? stock;
  final DailyPriceEntry? latestPrice;
  final List<DailyPriceEntry> priceHistory;
  final DailyAnalysisEntry? analysis;
  final List<DailyReasonEntry> reasons;
  final List<DailyInstitutionalEntry> institutionalHistory;
  final List<FinMindMarginData> marginHistory;
  final List<FinMindRevenue> revenueHistory;
  final List<FinMindDividend> dividendHistory;
  final FinMindPER? latestPER;
  final List<NewsItemEntry> recentNews;
  final bool isInWatchlist;
  final bool isLoading;
  final bool isLoadingMargin;
  final bool isLoadingFundamentals;
  final String? error;

  /// The synchronized data date - all displayed data should be from this date
  final DateTime? dataDate;

  /// True if price and institutional data dates don't match
  final bool hasDataMismatch;

  StockDetailState copyWith({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry>? reasons,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    FinMindPER? latestPER,
    List<NewsItemEntry>? recentNews,
    bool? isInWatchlist,
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    String? error,
    DateTime? dataDate,
    bool? hasDataMismatch,
  }) {
    return StockDetailState(
      stock: stock ?? this.stock,
      latestPrice: latestPrice ?? this.latestPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      analysis: analysis ?? this.analysis,
      reasons: reasons ?? this.reasons,
      institutionalHistory: institutionalHistory ?? this.institutionalHistory,
      marginHistory: marginHistory ?? this.marginHistory,
      revenueHistory: revenueHistory ?? this.revenueHistory,
      dividendHistory: dividendHistory ?? this.dividendHistory,
      latestPER: latestPER ?? this.latestPER,
      recentNews: recentNews ?? this.recentNews,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMargin: isLoadingMargin ?? this.isLoadingMargin,
      isLoadingFundamentals:
          isLoadingFundamentals ?? this.isLoadingFundamentals,
      error: error,
      dataDate: dataDate ?? this.dataDate,
      hasDataMismatch: hasDataMismatch ?? this.hasDataMismatch,
    );
  }

  /// Price change percentage
  double? get priceChange {
    if (priceHistory.length < 2) return null;
    final today = priceHistory.last.close;
    final yesterday = priceHistory[priceHistory.length - 2].close;
    if (today == null || yesterday == null || yesterday == 0) return null;
    return ((today - yesterday) / yesterday) * 100;
  }

  /// Trend state label
  String get trendLabel {
    return switch (analysis?.trendState) {
      'UP' => '上升趨勢',
      'DOWN' => '下跌趨勢',
      _ => '盤整區間',
    };
  }

  /// Reversal state label
  String? get reversalLabel {
    return switch (analysis?.reversalState) {
      'W2S' => '弱轉強',
      'S2W' => '強轉弱',
      _ => null,
    };
  }

  /// Get reason labels
  List<String> get reasonLabels {
    return reasons.map((r) {
      return ReasonType.values
              .where((rt) => rt.code == r.reasonType)
              .firstOrNull
              ?.label ??
          r.reasonType;
    }).toList();
  }
}

// ==================================================
// Stock Detail Notifier
// ==================================================

class StockDetailNotifier extends StateNotifier<StockDetailState> {
  StockDetailNotifier(this._ref, this._symbol)
    : super(const StockDetailState());

  final Ref _ref;
  final String _symbol;

  AppDatabase get _db => _ref.read(databaseProvider);
  FinMindClient get _finMind => _ref.read(finMindClientProvider);

  /// Synchronize price and institutional data to the same date
  /// Returns the latest price and institutional history that are on the same date
  ({
    DailyPriceEntry? latestPrice,
    List<DailyInstitutionalEntry> institutionalHistory,
    DateTime? dataDate,
    bool hasDataMismatch,
  })
  _synchronizeDataDates(
    List<DailyPriceEntry> priceHistory,
    List<DailyInstitutionalEntry> instHistory,
  ) {
    if (priceHistory.isEmpty) {
      return (
        latestPrice: null,
        institutionalHistory: instHistory,
        dataDate: instHistory.isNotEmpty ? instHistory.last.date : null,
        hasDataMismatch: false,
      );
    }

    if (instHistory.isEmpty) {
      final latestPrice = priceHistory.last;
      return (
        latestPrice: latestPrice,
        institutionalHistory: instHistory,
        dataDate: latestPrice.date,
        hasDataMismatch: false,
      );
    }

    // Get latest dates from each source
    final latestPriceDate = priceHistory.last.date;
    final latestInstDate = instHistory.last.date;

    // Normalize dates for comparison (remove time component)
    final priceDay = DateTime(
      latestPriceDate.year,
      latestPriceDate.month,
      latestPriceDate.day,
    );
    final instDay = DateTime(
      latestInstDate.year,
      latestInstDate.month,
      latestInstDate.day,
    );

    // If dates match, no synchronization needed
    if (priceDay == instDay) {
      return (
        latestPrice: priceHistory.last,
        institutionalHistory: instHistory,
        dataDate: priceDay,
        hasDataMismatch: false,
      );
    }

    // Dates don't match - find common date
    const hasDataMismatch = true;

    // Build sets of available dates
    final priceDates = priceHistory
        .map((p) => DateTime(p.date.year, p.date.month, p.date.day))
        .toSet();
    final instDates = instHistory
        .map((i) => DateTime(i.date.year, i.date.month, i.date.day))
        .toSet();

    // Find common dates
    final commonDates = priceDates.intersection(instDates);

    if (commonDates.isEmpty) {
      // No common dates - use the earlier of the two latest dates
      final dataDate = priceDay.isBefore(instDay) ? priceDay : instDay;

      // Find price for this date
      final matchingPrice = priceHistory.lastWhere(
        (p) =>
            DateTime(
              p.date.year,
              p.date.month,
              p.date.day,
            ).isAtSameMomentAs(dataDate) ||
            DateTime(p.date.year, p.date.month, p.date.day).isBefore(dataDate),
        orElse: () => priceHistory.last,
      );

      return (
        latestPrice: matchingPrice,
        institutionalHistory: instHistory,
        dataDate: dataDate,
        hasDataMismatch: true,
      );
    }

    // Use the latest common date
    final latestCommonDate = commonDates.reduce((a, b) => a.isAfter(b) ? a : b);

    // Find price entry for this date
    final matchingPrice = priceHistory.lastWhere(
      (p) =>
          DateTime(p.date.year, p.date.month, p.date.day) == latestCommonDate,
      orElse: () => priceHistory.last,
    );

    // Filter institutional history up to this date
    final syncedInstHistory = instHistory
        .where(
          (i) =>
              DateTime(
                i.date.year,
                i.date.month,
                i.date.day,
              ).isBefore(latestCommonDate) ||
              DateTime(i.date.year, i.date.month, i.date.day) ==
                  latestCommonDate,
        )
        .toList();

    return (
      latestPrice: matchingPrice,
      institutionalHistory: syncedInstHistory,
      dataDate: latestCommonDate,
      hasDataMismatch: hasDataMismatch,
    );
  }

  /// Load stock detail data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final today = DateTime.now();
      final normalizedToday = DateTime.utc(today.year, today.month, today.day);
      final startDate = normalizedToday.subtract(
        const Duration(days: RuleParams.lookbackPrice),
      );

      // Load all data in parallel
      final stockFuture = _db.getStock(_symbol);
      final priceFuture = _db.getPriceHistory(
        _symbol,
        startDate: startDate,
        endDate: normalizedToday,
      );
      final analysisFuture = _db.getAnalysis(_symbol, normalizedToday);
      final reasonsFuture = _db.getReasons(_symbol, normalizedToday);
      final instFuture = _db.getInstitutionalHistory(
        _symbol,
        startDate: normalizedToday.subtract(const Duration(days: 10)),
        endDate: normalizedToday,
      );
      final watchlistFuture = _db.isInWatchlist(_symbol);

      final results = await Future.wait([
        stockFuture,
        priceFuture,
        analysisFuture,
        reasonsFuture,
        instFuture,
        watchlistFuture,
      ]);

      final stock = results[0] as StockMasterEntry?;
      final priceHistory = results[1] as List<DailyPriceEntry>;
      final analysis = results[2] as DailyAnalysisEntry?;
      final reasons = results[3] as List<DailyReasonEntry>;
      var instHistory = results[4] as List<DailyInstitutionalEntry>;
      final isInWatchlist = results[5] as bool;

      // If no institutional data in DB, fetch from API
      if (instHistory.isEmpty) {
        instHistory = await _fetchInstitutionalFromApi();
      }

      // Synchronize data dates - find common latest date
      final syncResult = _synchronizeDataDates(priceHistory, instHistory);
      final latestPrice = syncResult.latestPrice;
      final syncedInstHistory = syncResult.institutionalHistory;
      final dataDate = syncResult.dataDate;
      final hasDataMismatch = syncResult.hasDataMismatch;

      state = state.copyWith(
        stock: stock,
        latestPrice: latestPrice,
        priceHistory: priceHistory,
        analysis: analysis,
        reasons: reasons,
        institutionalHistory: syncedInstHistory,
        isInWatchlist: isInWatchlist,
        isLoading: false,
        dataDate: dataDate,
        hasDataMismatch: hasDataMismatch,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetch institutional data directly from FinMind API
  Future<List<DailyInstitutionalEntry>> _fetchInstitutionalFromApi() async {
    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));
      final dateFormat = DateFormat('yyyy-MM-dd');

      final data = await _finMind.getInstitutionalData(
        stockId: _symbol,
        startDate: dateFormat.format(startDate),
        endDate: dateFormat.format(today),
      );

      // Convert to DailyInstitutionalEntry format
      return data.map((item) {
        return DailyInstitutionalEntry(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: item.foreignNet,
          investmentTrustNet: item.investmentTrustNet,
          dealerNet: item.dealerNet,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch institutional data from API: $e');
      return [];
    }
  }

  /// Toggle watchlist - also syncs with global watchlistProvider
  Future<void> toggleWatchlist() async {
    final watchlistNotifier = _ref.read(watchlistProvider.notifier);

    if (state.isInWatchlist) {
      // Use watchlistProvider to ensure global state sync
      await watchlistNotifier.removeStock(_symbol);
    } else {
      await watchlistNotifier.addStock(_symbol);
    }

    // Update local state
    state = state.copyWith(isInWatchlist: !state.isInWatchlist);
  }

  /// Load margin trading data (融資融券) from FinMind API
  Future<void> loadMarginData() async {
    // Skip if already loading or already loaded
    if (state.isLoadingMargin || state.marginHistory.isNotEmpty) return;

    state = state.copyWith(isLoadingMargin: true);

    try {
      // Load margin data for the past 20 days
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));
      final dateFormat = DateFormat('yyyy-MM-dd');

      final marginData = await _finMind.getMarginData(
        stockId: _symbol,
        startDate: dateFormat.format(startDate),
        endDate: dateFormat.format(today),
      );

      state = state.copyWith(marginHistory: marginData, isLoadingMargin: false);
    } catch (e, stackTrace) {
      // Log error for debugging - margin data is optional
      debugPrint('Failed to load margin data for $_symbol: $e');
      debugPrint(stackTrace.toString());
      state = state.copyWith(isLoadingMargin: false);
    }
  }

  /// Load fundamentals data (營收/股利/本益比) from FinMind API
  Future<void> loadFundamentals() async {
    // Skip if already loading or already loaded
    if (state.isLoadingFundamentals ||
        state.revenueHistory.isNotEmpty ||
        state.dividendHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingFundamentals: true);

    try {
      final today = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd');

      // Load revenue for past 24 months (need 2 years for YoY calculation)
      final revenueStartDate = DateTime(today.year - 2, today.month, 1);

      // Load PER for past 5 days (to get latest)
      final perStartDate = today.subtract(const Duration(days: 5));

      // Load all data in parallel
      final results = await Future.wait([
        _finMind.getMonthlyRevenue(
          stockId: _symbol,
          startDate: dateFormat.format(revenueStartDate),
          endDate: dateFormat.format(today),
        ),
        _finMind.getDividends(stockId: _symbol),
        _finMind.getPERData(
          stockId: _symbol,
          startDate: dateFormat.format(perStartDate),
          endDate: dateFormat.format(today),
        ),
      ]);

      var revenueData = results[0] as List<FinMindRevenue>;
      final dividendData = results[1] as List<FinMindDividend>;
      final perData = results[2] as List<FinMindPER>;

      // Calculate MoM and YoY growth rates for revenue
      if (revenueData.isNotEmpty) {
        revenueData = FinMindRevenue.calculateGrowthRates(revenueData);
      }

      // Get latest PER
      FinMindPER? latestPER;
      if (perData.isNotEmpty) {
        perData.sort((a, b) => b.date.compareTo(a.date));
        latestPER = perData.first;
      }

      state = state.copyWith(
        revenueHistory: revenueData,
        dividendHistory: dividendData,
        latestPER: latestPER,
        isLoadingFundamentals: false,
      );
    } catch (e, stackTrace) {
      // Log error for debugging - fundamentals data is optional
      debugPrint('Failed to load fundamentals for $_symbol: $e');
      debugPrint(stackTrace.toString());
      state = state.copyWith(isLoadingFundamentals: false);
    }
  }
}

/// Provider family for stock detail
final stockDetailProvider =
    StateNotifierProvider.family<StockDetailNotifier, StockDetailState, String>(
      (ref, symbol) {
        return StockDetailNotifier(ref, symbol);
      },
    );
