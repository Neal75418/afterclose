import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Watchlist Screen State
// ==================================================

/// State for watchlist screen
class WatchlistState {
  const WatchlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<WatchlistItemData> items;
  final bool isLoading;
  final String? error;

  WatchlistState copyWith({
    List<WatchlistItemData>? items,
    bool? isLoading,
    String? error,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Data class for watchlist item
class WatchlistItemData {
  const WatchlistItemData({
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.score,
    this.hasSignal = false,
    this.addedAt,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final String? trendState;
  final double? score;
  final bool hasSignal;
  final DateTime? addedAt;

  String get statusIcon {
    if (hasSignal) return '🔥';
    if (priceChange != null && priceChange!.abs() >= 3) return '👀';
    return '😴';
  }
}

// ==================================================
// Watchlist Notifier
// ==================================================

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier(this._ref) : super(const WatchlistState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Load watchlist data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final today = DateTime.now();
      final normalizedToday = DateTime.utc(today.year, today.month, today.day);
      final historyStart = normalizedToday.subtract(const Duration(days: 5));

      final watchlist = await _db.getWatchlist();
      if (watchlist.isEmpty) {
        state = state.copyWith(items: [], isLoading: false);
        return;
      }

      // Collect all symbols for batch queries
      final symbols = watchlist.map((w) => w.symbol).toList();

      // Batch load all data in parallel
      final results = await Future.wait([
        _db.getStocksBatch(symbols),
        _db.getLatestPricesBatch(symbols),
        _db.getAnalysesBatch(symbols, normalizedToday),
        _db.getReasonsBatch(symbols, normalizedToday),
        _db.getPriceHistoryBatch(
          symbols,
          startDate: historyStart,
          endDate: normalizedToday,
        ),
      ]);

      final stocksMap = results[0] as Map<String, StockMasterEntry>;
      final latestPricesMap = results[1] as Map<String, DailyPriceEntry>;
      final analysesMap = results[2] as Map<String, DailyAnalysisEntry>;
      final reasonsMap = results[3] as Map<String, List<DailyReasonEntry>>;
      final priceHistoriesMap =
          results[4] as Map<String, List<DailyPriceEntry>>;

      // Calculate price changes using utility
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // Build items from batch results
      final items = watchlist.map((item) {
        final stock = stocksMap[item.symbol];
        final latestPrice = latestPricesMap[item.symbol];
        final analysis = analysesMap[item.symbol];
        final reasons = reasonsMap[item.symbol] ?? [];

        return WatchlistItemData(
          symbol: item.symbol,
          stockName: stock?.name,
          latestClose: latestPrice?.close,
          priceChange: priceChanges[item.symbol],
          trendState: analysis?.trendState,
          score: analysis?.score,
          hasSignal: reasons.isNotEmpty,
          addedAt: item.createdAt,
        );
      }).toList();

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add stock to watchlist
  Future<bool> addStock(String symbol) async {
    // Check if stock exists
    final stock = await _db.getStock(symbol);
    if (stock == null) {
      return false;
    }

    await _db.addToWatchlist(symbol);
    await loadData();
    return true;
  }

  /// Remove stock from watchlist
  Future<void> removeStock(String symbol) async {
    await _db.removeFromWatchlist(symbol);

    // Optimistically update the state
    state = state.copyWith(
      items: state.items.where((item) => item.symbol != symbol).toList(),
    );
  }

  /// Restore a removed stock
  Future<void> restoreStock(String symbol) async {
    await _db.addToWatchlist(symbol);
    await loadData();
  }
}

/// Provider for watchlist screen state
final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
      return WatchlistNotifier(ref);
    });
