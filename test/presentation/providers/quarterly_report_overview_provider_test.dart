import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/database/dao/quarterly_report_dao.dart';
import 'package:daredevil/presentation/providers/quarterly_report_overview_provider.dart';

/// 季報總覽的過濾+排序純函式(2026-08-06)。
///
/// 契約沿營收總覽 visibleRows:排序皆降冪、null 鍵一律沉底(不與有值
/// 者混排)、同 null 以 symbol 穩定排序;過濾是使用者主動選的,預設
/// 「全部」不裁剪。EPS 年增以**差值(元)**排序——累計制 EPS 的比率
/// 在去年趨近零時會爆表,差值才是穩健的排序鍵。
void main() {
  QuarterlyReportOverviewRow row(
    String symbol, {
    double? eps,
    double? priorEps,
    double? netIncome,
  }) => QuarterlyReportOverviewRow(
    symbol: symbol,
    name: '測試$symbol',
    market: 'TWSE',
    eps: eps,
    netIncome: netIncome,
    revenue: null,
    priorEps: priorEps,
  );

  QuarterlyReportOverviewState stateWith(
    List<QuarterlyReportOverviewRow> rows, {
    QuarterlySortBy sortBy = QuarterlySortBy.epsGrowth,
    QuarterlyFilter filter = QuarterlyFilter.all,
  }) => QuarterlyReportOverviewState(
    overview: QuarterlyReportOverview(
      year: 2026,
      quarter: 2,
      rows: rows,
      filedByMarket: const {'TWSE': 3},
    ),
    sortBy: sortBy,
    filter: filter,
  );

  test('🚨 epsGrowth 排序=差值降冪,缺 prior/eps 沉底', () {
    final state = stateWith([
      row('1111', eps: 1.0, priorEps: 0.5), // +0.5
      row('2222', eps: 5.0, priorEps: 1.0), // +4.0
      row('3333', eps: 9.9), // 無 prior → 沉底
      row('4444', eps: 2.0, priorEps: 3.0), // -1.0
    ]);

    expect(state.visibleRows(const {}).map((r) => r.symbol).toList(), [
      '2222',
      '1111',
      '4444',
      '3333',
    ]);
  });

  test('eps/netIncome 排序降冪,null 沉底', () {
    final rows = [
      row('1111', eps: 1.0, netIncome: 300),
      row('2222', eps: 3.0),
      row('3333', netIncome: 900),
    ];

    expect(
      stateWith(
        rows,
        sortBy: QuarterlySortBy.eps,
      ).visibleRows(const {}).map((r) => r.symbol).toList(),
      ['2222', '1111', '3333'],
    );
    expect(
      stateWith(
        rows,
        sortBy: QuarterlySortBy.netIncome,
      ).visibleRows(const {}).map((r) => r.symbol).toList(),
      ['3333', '1111', '2222'],
    );
  });

  test('watchlist 過濾只留自選;turnaround 過濾只留轉盈', () {
    final rows = [
      row('1111', eps: 1.0, priorEps: -0.5), // 轉盈
      row('2222', eps: 5.0, priorEps: 1.0),
      row('3333', eps: -1.0, priorEps: -2.0),
    ];

    expect(
      stateWith(
        rows,
        filter: QuarterlyFilter.watchlist,
      ).visibleRows(const {'2222'}).map((r) => r.symbol).toList(),
      ['2222'],
    );
    expect(
      stateWith(
        rows,
        filter: QuarterlyFilter.turnaround,
      ).visibleRows(const {}).map((r) => r.symbol).toList(),
      ['1111'],
    );
  });

  test('overview 為 null → 空清單', () {
    const state = QuarterlyReportOverviewState();
    expect(state.visibleRows(const {}), isEmpty);
  });
}
