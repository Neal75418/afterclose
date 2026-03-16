import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/data/models/tpex/tpex_short_sell_ranking.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Short Sell Ranking State
// ==================================================

/// 融券賣出排行狀態
class ShortSellRankingState {
  const ShortSellRankingState({
    this.rankings = const [],
    this.isLoading = false,
    this.error,
  });

  final List<TpexShortSellRanking> rankings;
  final bool isLoading;
  final String? error;

  ShortSellRankingState copyWith({
    List<TpexShortSellRanking>? rankings,
    bool? isLoading,
    String? error,
  }) {
    return ShortSellRankingState(
      rankings: rankings ?? this.rankings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================================================
// Notifier
// ==================================================

class ShortSellRankingNotifier extends Notifier<ShortSellRankingState> {
  @override
  ShortSellRankingState build() => const ShortSellRankingState();

  /// 從 TPEX API 載入融券排行資料
  Future<void> loadData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final tpex = ref.read(tpexClientProvider);
      final rankings = await tpex.getShortSellRanking();

      state = state.copyWith(rankings: rankings, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: ErrorDisplay.message(e), isLoading: false);
    }
  }
}

// ==================================================
// Provider
// ==================================================

final shortSellRankingProvider =
    NotifierProvider<ShortSellRankingNotifier, ShortSellRankingState>(
      ShortSellRankingNotifier.new,
    );
