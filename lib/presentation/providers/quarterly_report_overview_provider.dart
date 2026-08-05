import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/dao/quarterly_report_dao.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 季報總覽的排序鍵。
///
/// epsGrowth 以**差值(元)**排序而非比率——累計制 EPS 的年增率在去年
/// 趨近零時會爆表(0.01→1.00 = +9900%),差值才是穩健的排序鍵;UI 同時
/// 顯示本期與去年同期兩欄,比率留給讀者心算。
enum QuarterlySortBy { epsGrowth, eps, netIncome }

/// 季報總覽的過濾器(預設「全部」不裁剪——清單完整性是本頁的存在理由,
/// 設計沿 2026-08-05 營收總覽的定案)
enum QuarterlyFilter { all, watchlist, turnaround }

class QuarterlyReportOverviewState {
  const QuarterlyReportOverviewState({
    this.overview,
    this.isLoading = false,
    this.error,
    this.sortBy = QuarterlySortBy.epsGrowth,
    this.filter = QuarterlyFilter.all,
  });

  final QuarterlyReportOverview? overview;
  final bool isLoading;
  final String? error;
  final QuarterlySortBy sortBy;
  final QuarterlyFilter filter;

  QuarterlyReportOverviewState copyWith({
    QuarterlyReportOverview? overview,
    bool? isLoading,
    String? error,
    bool clearError = false,
    QuarterlySortBy? sortBy,
    QuarterlyFilter? filter,
  }) {
    return QuarterlyReportOverviewState(
      overview: overview ?? this.overview,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sortBy: sortBy ?? this.sortBy,
      filter: filter ?? this.filter,
    );
  }

  /// 套用過濾+排序後的可見列(純函式,單元測試直接驗)。
  ///
  /// 排序皆為降冪;排序鍵為 null(缺本期值或缺去年基準)一律沉底,
  /// 不與有值者混排;同 null 以 symbol 穩定排序。
  List<QuarterlyReportOverviewRow> visibleRows(Set<String> watchlistSymbols) {
    final o = overview;
    if (o == null) return const [];

    var rows = switch (filter) {
      QuarterlyFilter.all => o.rows,
      QuarterlyFilter.watchlist =>
        o.rows.where((r) => watchlistSymbols.contains(r.symbol)).toList(),
      QuarterlyFilter.turnaround =>
        o.rows.where((r) => r.isTurnaround).toList(),
    };

    double? keyOf(QuarterlyReportOverviewRow r) => switch (sortBy) {
      QuarterlySortBy.epsGrowth => r.epsYoyDelta,
      QuarterlySortBy.eps => r.eps,
      QuarterlySortBy.netIncome => r.netIncome,
    };

    rows = List.of(rows)
      ..sort((a, b) {
        final ka = keyOf(a);
        final kb = keyOf(b);
        if (ka == null && kb == null) return a.symbol.compareTo(b.symbol);
        if (ka == null) return 1;
        if (kb == null) return -1;
        return kb.compareTo(ka);
      });
    return rows;
  }
}

class QuarterlyReportOverviewNotifier
    extends Notifier<QuarterlyReportOverviewState> {
  @override
  QuarterlyReportOverviewState build() => const QuarterlyReportOverviewState();

  Future<void> loadData() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final overview = await ref
          .read(databaseProvider)
          .getQuarterlyReportOverview();
      state = state.copyWith(overview: overview, isLoading: false);
    } catch (e) {
      AppLogger.warning('QuarterlyReportOverviewNotifier', '載入季報總覽失敗', e);
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  void setSortBy(QuarterlySortBy sortBy) =>
      state = state.copyWith(sortBy: sortBy);

  void setFilter(QuarterlyFilter filter) =>
      state = state.copyWith(filter: filter);
}

final quarterlyReportOverviewProvider =
    NotifierProvider<
      QuarterlyReportOverviewNotifier,
      QuarterlyReportOverviewState
    >(QuarterlyReportOverviewNotifier.new);
