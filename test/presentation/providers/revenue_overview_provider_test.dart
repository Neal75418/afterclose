import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/dao/revenue_dao.dart';
import 'package:afterclose/presentation/providers/revenue_overview_provider.dart';

/// 營收總覽的排序/過濾純函式(2026-08-05)。
///
/// 清單頁的鐵律:過濾是使用者主動選的、排序不裁剪內容——任何 sortBy/
/// filter 組合下,「全部」過濾器的列數必須等於 overview 全量。
void main() {
  RevenueOverviewRow row(
    String symbol, {
    double revenue = 100,
    double? mom,
    double? yoy,
    bool newHigh = false,
    String market = 'TWSE',
  }) => RevenueOverviewRow(
    symbol: symbol,
    name: '測試$symbol',
    market: market,
    revenue: revenue,
    momGrowth: mom,
    yoyGrowth: yoy,
    isNewHigh: newHigh,
  );

  RevenueOverviewState stateWith(
    List<RevenueOverviewRow> rows, {
    RevenueSortBy sortBy = RevenueSortBy.yoy,
    RevenueFilter filter = RevenueFilter.all,
  }) => RevenueOverviewState(
    overview: RevenueOverview(
      year: 2026,
      month: 7,
      rows: rows,
      filedByMarket: const {},
      activeByMarket: const {},
    ),
    sortBy: sortBy,
    filter: filter,
  );

  final rows = [
    row('1111', yoy: 10, mom: -5),
    row('2222', yoy: 700, mom: 20, newHigh: true),
    row('3333', yoy: null, mom: null), // 無前期基準
    row('4444', yoy: -30, mom: 8, newHigh: true),
  ];

  test('🚨 預設(全部+YoY):全量列出、降冪、null 沉底', () {
    final visible = stateWith(rows).visibleRows(const {});

    expect(visible, hasLength(4), reason: '「全部」不得裁剪任何列');
    expect(visible.map((r) => r.symbol).toList(), [
      '2222',
      '1111',
      '4444',
      '3333',
    ]);
  });

  test('營收金額排序', () {
    final sized = [
      row('5555', revenue: 50),
      row('6666', revenue: 900),
      row('7777', revenue: 200),
    ];
    final visible = stateWith(
      sized,
      sortBy: RevenueSortBy.revenue,
    ).visibleRows(const {});
    expect(visible.map((r) => r.symbol).toList(), ['6666', '7777', '5555']);
  });

  test('自選過濾:只留自選,排序仍生效', () {
    final visible = stateWith(
      rows,
      filter: RevenueFilter.watchlist,
    ).visibleRows(const {'1111', '4444'});
    expect(visible.map((r) => r.symbol).toList(), ['1111', '4444']);
  });

  test('創高過濾:純資料口徑的 isNewHigh', () {
    final visible = stateWith(
      rows,
      filter: RevenueFilter.newHigh,
    ).visibleRows(const {});
    expect(visible.map((r) => r.symbol).toSet(), {'2222', '4444'});
  });

  test('overview 為 null → 空列表不炸', () {
    const state = RevenueOverviewState();
    expect(state.visibleRows(const {}), isEmpty);
  });
}
