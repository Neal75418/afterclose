import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
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
    this.recentNews = const [],
    this.isInWatchlist = false,
    this.isLoading = false,
    this.error,
  });

  final StockMasterEntry? stock;
  final DailyPriceEntry? latestPrice;
  final List<DailyPriceEntry> priceHistory;
  final DailyAnalysisEntry? analysis;
  final List<DailyReasonEntry> reasons;
  final List<DailyInstitutionalEntry> institutionalHistory;
  final List<NewsItemEntry> recentNews;
  final bool isInWatchlist;
  final bool isLoading;
  final String? error;

  StockDetailState copyWith({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry>? reasons,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<NewsItemEntry>? recentNews,
    bool? isInWatchlist,
    bool? isLoading,
    String? error,
  }) {
    return StockDetailState(
      stock: stock ?? this.stock,
      latestPrice: latestPrice ?? this.latestPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      analysis: analysis ?? this.analysis,
      reasons: reasons ?? this.reasons,
      institutionalHistory: institutionalHistory ?? this.institutionalHistory,
      recentNews: recentNews ?? this.recentNews,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
      final instHistory = results[4] as List<DailyInstitutionalEntry>;
      final isInWatchlist = results[5] as bool;

      // Get latest price
      final latestPrice = priceHistory.isNotEmpty ? priceHistory.last : null;

      state = state.copyWith(
        stock: stock,
        latestPrice: latestPrice,
        priceHistory: priceHistory,
        analysis: analysis,
        reasons: reasons,
        institutionalHistory: instHistory,
        isInWatchlist: isInWatchlist,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
}

/// Provider family for stock detail
final stockDetailProvider =
    StateNotifierProvider.family<StockDetailNotifier, StockDetailState, String>(
      (ref, symbol) {
        return StockDetailNotifier(ref, symbol);
      },
    );
