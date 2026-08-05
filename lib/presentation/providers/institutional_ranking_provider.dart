import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/dao/institutional_dao.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 法人排行的四個視角(自營刻意不提供——避險盤污染+持續性差,
/// 2026-08-05 設計定稿;雙買 badge 補足「外資投信同買」的共識視角)
enum InstitutionalView { foreignBuy, foreignSell, trustBuy, trustSell }

class InstitutionalRankingState {
  const InstitutionalRankingState({
    this.ranking,
    this.isLoading = false,
    this.error,
    this.view = InstitutionalView.foreignBuy,
  });

  final InstitutionalRanking? ranking;
  final bool isLoading;
  final String? error;
  final InstitutionalView view;

  List<InstitutionalRankingRow> get visibleRows => switch (view) {
    InstitutionalView.foreignBuy => ranking?.foreignBuy ?? const [],
    InstitutionalView.foreignSell => ranking?.foreignSell ?? const [],
    InstitutionalView.trustBuy => ranking?.trustBuy ?? const [],
    InstitutionalView.trustSell => ranking?.trustSell ?? const [],
  };

  bool get isBuyView =>
      view == InstitutionalView.foreignBuy ||
      view == InstitutionalView.trustBuy;

  InstitutionalRankingState copyWith({
    InstitutionalRanking? ranking,
    bool? isLoading,
    String? error,
    bool clearError = false,
    InstitutionalView? view,
  }) {
    return InstitutionalRankingState(
      ranking: ranking ?? this.ranking,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      view: view ?? this.view,
    );
  }
}

class InstitutionalRankingNotifier extends Notifier<InstitutionalRankingState> {
  @override
  InstitutionalRankingState build() => const InstitutionalRankingState();

  Future<void> loadData() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ranking = await ref
          .read(databaseProvider)
          .getInstitutionalRanking();
      state = state.copyWith(ranking: ranking, isLoading: false);
    } catch (e) {
      AppLogger.warning('InstitutionalRankingNotifier', '載入法人排行失敗', e);
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  void setView(InstitutionalView view) => state = state.copyWith(view: view);
}

final institutionalRankingProvider =
    NotifierProvider<InstitutionalRankingNotifier, InstitutionalRankingState>(
      InstitutionalRankingNotifier.new,
    );
