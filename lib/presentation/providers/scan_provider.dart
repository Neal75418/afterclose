import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Scan Screen State
// ==================================================

/// Filter options for scan screen
enum ScanFilter {
  all('全部', null),
  reversalW2S('弱轉強', 'REVERSAL_W2S'),
  reversalS2W('強轉弱', 'REVERSAL_S2W'),
  breakout('突破', 'TECH_BREAKOUT'),
  breakdown('跌破', 'TECH_BREAKDOWN'),
  volumeSpike('放量', 'VOLUME_SPIKE');

  const ScanFilter(this.label, this.reasonCode);

  final String label;
  final String? reasonCode;
}

/// Sort options for scan screen
enum ScanSort {
  scoreDesc('分數高→低'),
  scoreAsc('分數低→高'),
  priceChangeDesc('漲幅高→低'),
  priceChangeAsc('漲幅低→高');

  const ScanSort(this.label);

  final String label;
}

/// State for scan screen
class ScanState {
  const ScanState({
    this.allStocks = const [], // Original unfiltered data
    this.stocks = const [], // Filtered/sorted view
    this.filter = ScanFilter.all,
    this.sort = ScanSort.scoreDesc,
    this.dataDate,
    this.isLoading = false,
    this.error,
  });

  final List<ScanStockItem> allStocks;
  final List<ScanStockItem> stocks;
  final ScanFilter filter;
  final ScanSort sort;

  /// The actual date of the data being displayed
  final DateTime? dataDate;
  final bool isLoading;
  final String? error;

  ScanState copyWith({
    List<ScanStockItem>? allStocks,
    List<ScanStockItem>? stocks,
    ScanFilter? filter,
    ScanSort? sort,
    DateTime? dataDate,
    bool? isLoading,
    String? error,
  }) {
    return ScanState(
      allStocks: allStocks ?? this.allStocks,
      stocks: stocks ?? this.stocks,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      dataDate: dataDate ?? this.dataDate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Stock item in scan list
class ScanStockItem {
  const ScanStockItem({
    required this.symbol,
    required this.score,
    this.stockName,
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
  final double? latestClose;
  final double? priceChange;
  final double? volume;
  final String? trendState;
  final List<DailyReasonEntry> reasons;
  final bool isInWatchlist;
  final List<double>? recentPrices;

  /// Get main reason label
  String? get mainReasonLabel {
    if (reasons.isEmpty) return null;
    return ReasonType.values
        .where((r) => r.code == reasons.first.reasonType)
        .firstOrNull
        ?.label;
  }

  /// Get trend icon
  String get trendIcon {
    return switch (trendState) {
      'UP' => '📈',
      'DOWN' => '📉',
      _ => '➡️',
    };
  }

  /// Create a copy with modified fields
  ScanStockItem copyWith({bool? isInWatchlist}) {
    return ScanStockItem(
      symbol: symbol,
      score: score,
      stockName: stockName,
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

// ==================================================
// Scan Notifier
// ==================================================

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier(this._ref) : super(const ScanState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);

  /// Load scan data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use today's date for querying (update_service stores with this date)
      final dateCtx = DateContext.now();

      // Get all analyses for today (with score > 0)
      final analyses = await _db.getAnalysisForDate(dateCtx.today);

      // Get actual data dates for display purposes (not for querying)
      final latestPriceDate = await _db.getLatestDataDate();
      final latestInstDate = await _db.getLatestInstitutionalDate();

      // Calculate dataDate for display - use the earlier of the two dates
      final dataDate = DateContext.earlierOf(latestPriceDate, latestInstDate);

      final validAnalyses = analyses.where((a) => a.score > 0).toList();

      if (validAnalyses.isEmpty) {
        state = state.copyWith(
          allStocks: [],
          stocks: [],
          dataDate: dataDate,
          isLoading: false,
        );
        return;
      }

      // Get watchlist for checking
      final watchlist = await _db.getWatchlist();
      final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // Collect all symbols
      final symbols = validAnalyses.map((a) => a.symbol).toList();

      // Type-safe batch load using Dart 3 Records (no manual casting needed)
      final data = await _cachedDb.loadScanData(
        symbols: symbols,
        analysisDate: dateCtx.today,
        historyStart: dateCtx.historyStart,
      );

      // Destructure Record fields - compile-time type safety!
      final stocksMap = data.stocks;
      final latestPricesMap = data.latestPrices;
      final reasonsMap = data.reasons;
      final priceHistoriesMap = data.priceHistories;

      // Calculate price changes using utility
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // Build stock items
      final items = validAnalyses.map((analysis) {
        final latestPrice = latestPricesMap[analysis.symbol];
        final priceHistory = priceHistoriesMap[analysis.symbol];
        // Extract close prices for sparkline (last 7 days)
        final recentPrices = priceHistory
            ?.map((p) => p.close)
            .whereType<double>()
            .toList();
        return ScanStockItem(
          symbol: analysis.symbol,
          score: analysis.score,
          stockName: stocksMap[analysis.symbol]?.name,
          latestClose: latestPrice?.close,
          priceChange: priceChanges[analysis.symbol],
          volume: latestPrice?.volume,
          trendState: analysis.trendState,
          reasons: reasonsMap[analysis.symbol] ?? [],
          isInWatchlist: watchlistSymbols.contains(analysis.symbol),
          recentPrices: recentPrices,
        );
      }).toList();

      // Apply filter and sort
      final filtered = _applyFilter(items, state.filter);
      final sorted = _applySort(filtered, state.sort);

      state = state.copyWith(
        allStocks: items,
        stocks: sorted,
        dataDate: dataDate,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set filter - filters from original data, not already-filtered data
  void setFilter(ScanFilter filter) {
    if (filter == state.filter) return;

    // Filter from original unfiltered data
    final filtered = _applyFilter(state.allStocks, filter);
    final sorted = _applySort(filtered, state.sort);

    state = state.copyWith(filter: filter, stocks: sorted);
  }

  /// Set sort
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    // Re-filter then sort to ensure consistent state
    final filtered = _applyFilter(state.allStocks, state.filter);
    final sorted = _applySort(filtered, sort);

    state = state.copyWith(sort: sort, stocks: sorted);
  }

  /// Apply filter to stocks
  List<ScanStockItem> _applyFilter(
    List<ScanStockItem> stocks,
    ScanFilter filter,
  ) {
    if (filter == ScanFilter.all || filter.reasonCode == null) {
      return List.from(stocks);
    }

    return stocks
        .where((s) => s.reasons.any((r) => r.reasonType == filter.reasonCode))
        .toList();
  }

  /// Apply sort to stocks
  List<ScanStockItem> _applySort(List<ScanStockItem> stocks, ScanSort sort) {
    final sorted = List<ScanStockItem>.from(stocks);

    switch (sort) {
      case ScanSort.scoreDesc:
        sorted.sort((a, b) => b.score.compareTo(a.score));
      case ScanSort.scoreAsc:
        sorted.sort((a, b) => a.score.compareTo(b.score));
      case ScanSort.priceChangeDesc:
        sorted.sort((a, b) {
          final aChange = a.priceChange ?? double.negativeInfinity;
          final bChange = b.priceChange ?? double.negativeInfinity;
          return bChange.compareTo(aChange);
        });
      case ScanSort.priceChangeAsc:
        sorted.sort((a, b) {
          final aChange = a.priceChange ?? double.infinity;
          final bChange = b.priceChange ?? double.infinity;
          return aChange.compareTo(bChange);
        });
    }

    return sorted;
  }

  /// Toggle watchlist for a stock
  Future<void> toggleWatchlist(String symbol) async {
    final isInWatchlist = await _db.isInWatchlist(symbol);

    if (isInWatchlist) {
      await _db.removeFromWatchlist(symbol);
    } else {
      await _db.addToWatchlist(symbol);
    }

    // Update both allStocks and stocks using copyWith
    final updatedAll = state.allStocks.map((s) {
      if (s.symbol == symbol) return s.copyWith(isInWatchlist: !isInWatchlist);
      return s;
    }).toList();

    final updatedFiltered = state.stocks.map((s) {
      if (s.symbol == symbol) return s.copyWith(isInWatchlist: !isInWatchlist);
      return s;
    }).toList();

    state = state.copyWith(allStocks: updatedAll, stocks: updatedFiltered);
  }
}

/// Provider for scan screen state
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref);
});
