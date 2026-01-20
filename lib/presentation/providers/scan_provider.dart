import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
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
    this.stocks = const [],
    this.filter = ScanFilter.all,
    this.sort = ScanSort.scoreDesc,
    this.isLoading = false,
    this.error,
  });

  final List<ScanStockItem> stocks;
  final ScanFilter filter;
  final ScanSort sort;
  final bool isLoading;
  final String? error;

  ScanState copyWith({
    List<ScanStockItem>? stocks,
    ScanFilter? filter,
    ScanSort? sort,
    bool? isLoading,
    String? error,
  }) {
    return ScanState(
      stocks: stocks ?? this.stocks,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
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
}

// ==================================================
// Scan Notifier
// ==================================================

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier(this._ref) : super(const ScanState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Load scan data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final today = DateTime.now();
      final normalizedToday = DateTime.utc(today.year, today.month, today.day);

      // Get all analyses for today
      final analyses = await _db.getAnalysisForDate(normalizedToday);

      // Get watchlist for checking
      final watchlist = await _db.getWatchlist();
      final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // Build stock items
      final items = <ScanStockItem>[];

      for (final analysis in analyses) {
        final stock = await _db.getStock(analysis.symbol);
        final latestPrice = await _db.getLatestPrice(analysis.symbol);
        final reasons = await _db.getReasons(analysis.symbol, normalizedToday);

        // Skip if no score
        if (analysis.score <= 0) continue;

        // Calculate price change
        double? priceChange;
        if (latestPrice?.close != null) {
          final history = await _db.getPriceHistory(
            analysis.symbol,
            startDate: normalizedToday.subtract(const Duration(days: 5)),
            endDate: normalizedToday,
          );
          if (history.length >= 2) {
            final prevClose = history[history.length - 2].close;
            if (prevClose != null && prevClose > 0) {
              priceChange =
                  ((latestPrice!.close! - prevClose) / prevClose) * 100;
            }
          }
        }

        items.add(
          ScanStockItem(
            symbol: analysis.symbol,
            score: analysis.score,
            stockName: stock?.name,
            latestClose: latestPrice?.close,
            priceChange: priceChange,
            volume: latestPrice?.volume,
            trendState: analysis.trendState,
            reasons: reasons,
            isInWatchlist: watchlistSymbols.contains(analysis.symbol),
          ),
        );
      }

      // Apply filter and sort
      final filtered = _applyFilter(items, state.filter);
      final sorted = _applySort(filtered, state.sort);

      state = state.copyWith(stocks: sorted, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set filter and reload
  void setFilter(ScanFilter filter) {
    if (filter == state.filter) return;

    final filtered = _applyFilter(state.stocks, filter);
    final sorted = _applySort(filtered, state.sort);

    state = state.copyWith(filter: filter, stocks: sorted);
  }

  /// Set sort and reload
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    final sorted = _applySort(state.stocks, sort);

    state = state.copyWith(sort: sort, stocks: sorted);
  }

  /// Apply filter to stocks
  List<ScanStockItem> _applyFilter(
    List<ScanStockItem> stocks,
    ScanFilter filter,
  ) {
    if (filter == ScanFilter.all || filter.reasonCode == null) {
      return stocks;
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

    // Update state
    final updated = state.stocks.map((s) {
      if (s.symbol == symbol) {
        return ScanStockItem(
          symbol: s.symbol,
          score: s.score,
          stockName: s.stockName,
          latestClose: s.latestClose,
          priceChange: s.priceChange,
          volume: s.volume,
          trendState: s.trendState,
          reasons: s.reasons,
          isInWatchlist: !isInWatchlist,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(stocks: updated);
  }
}

/// Provider for scan screen state
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref);
});
