import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';

/// 季報總覽清單(最新一季全部已申報公司,2026-08-06)
class QuarterlyReportOverview {
  const QuarterlyReportOverview({
    required this.year,
    required this.quarter,
    required this.rows,
    required this.filedByMarket,
  });

  /// 西元年度
  final int year;

  /// 季別 1~4
  final int quarter;
  final List<QuarterlyReportOverviewRow> rows;

  /// 各市場已申報家數(刻意不提供分母,理由同 RevenueOverview:
  /// 可得的分母混入興櫃/ETF,任何進度分數都是假的)。
  final Map<String, int> filedByMarket;
}

/// 季報總覽單列
class QuarterlyReportOverviewRow {
  const QuarterlyReportOverviewRow({
    required this.symbol,
    required this.name,
    required this.market,
    required this.eps,
    required this.netIncome,
    required this.revenue,
    required this.priorEps,
  });

  final String symbol;
  final String name;
  final String market;

  /// 基本每股盈餘(元,累計)
  final double? eps;

  /// 本期淨利(千元,累計)
  final double? netIncome;

  /// 營業收入(千元,累計;金融業別無此欄)
  final double? revenue;

  /// 去年同期 EPS(元,累計;來自 financial_data 的 FinMind 回補,
  /// 同為累計制口徑——無該季歷史則 null)
  final double? priorEps;

  /// 轉虧為盈(去年同期 EPS ≤ 0、本期 > 0;兩值皆須存在)
  bool get isTurnaround =>
      eps != null && priorEps != null && priorEps! <= 0 && eps! > 0;
}

/// 季報操作
mixin QuarterlyReportDaoMixin on $AppDatabase {
  /// 批次寫入季報(insertOrReplace:官方全列快照,重抓即修正)
  Future<void> insertQuarterlyReports(
    List<QuarterlyReportCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAll(quarterlyReport, entries, mode: InsertMode.insertOrReplace);
    });
  }

  /// 季報總覽:資料中最新一季的完整清單。
  ///
  /// 設計沿 [getRevenueOverviewForLatestMonth](2026-08-05 月營收總覽):
  /// - 「最新一季」= quarterly_report 實際存在的最大 (year, quarter)——
  ///   零日曆邏輯:公布期自然指向進行中的季,平時指向最後完整季
  /// - 只列 active 股票(殭屍下市股 join 排除)
  /// - 去年同期 EPS 以 financial_data(dataType='EPS')的**季末日**列
  ///   LEFT JOIN:FinMind EPS 與官方 t187ap06 同為累計制,直接可比;
  ///   無歷史(新上市/回補未及)則 null,UI 顯示「—」不硬算
  Future<QuarterlyReportOverview?> getQuarterlyReportOverview() async {
    final latest = await customSelect(
      'SELECT year AS y, quarter AS q FROM quarterly_report '
      'ORDER BY year DESC, quarter DESC LIMIT 1',
      readsFrom: {quarterlyReport},
    ).getSingleOrNull();
    if (latest == null) return null;
    final year = latest.read<int>('y');
    final quarter = latest.read<int>('q');

    // 季末日=去年同期 EPS 在 financial_data 的主鍵日(FinMind 慣例,
    // 已對 live DB 驗證:2330 的 EPS 列日期恰為 3/31、6/30、9/30、12/31)
    final quarterEnd = switch (quarter) {
      1 => DateTime(year - 1, 3, 31),
      2 => DateTime(year - 1, 6, 30),
      3 => DateTime(year - 1, 9, 30),
      _ => DateTime(year - 1, 12, 31),
    };

    final rows = await customSelect(
      '''
      SELECT qr.symbol, sm.name, sm.market,
             qr.eps, qr.net_income, qr.revenue,
             fd.value AS prior_eps
      FROM quarterly_report qr
      JOIN stock_master sm ON sm.symbol = qr.symbol AND sm.is_active = 1
      LEFT JOIN financial_data fd
        ON fd.symbol = qr.symbol
       AND fd.data_type = 'EPS'
       AND fd.date = ?
      WHERE qr.year = ? AND qr.quarter = ?
      ''',
      variables: [
        Variable.withDateTime(quarterEnd),
        Variable.withInt(year),
        Variable.withInt(quarter),
      ],
      readsFrom: {quarterlyReport, stockMaster, financialData},
    ).get();

    final entries = rows
        .map(
          (r) => QuarterlyReportOverviewRow(
            symbol: r.read<String>('symbol'),
            name: r.read<String>('name'),
            market: r.read<String>('market'),
            eps: r.readNullable<double>('eps'),
            netIncome: r.readNullable<double>('net_income'),
            revenue: r.readNullable<double>('revenue'),
            priorEps: r.readNullable<double>('prior_eps'),
          ),
        )
        .toList();

    final filedByMarket = <String, int>{};
    for (final e in entries) {
      filedByMarket.update(e.market, (v) => v + 1, ifAbsent: () => 1);
    }

    return QuarterlyReportOverview(
      year: year,
      quarter: quarter,
      rows: entries,
      filedByMarket: filedByMarket,
    );
  }
}
