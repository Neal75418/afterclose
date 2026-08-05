import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/quarterly_report_dao.dart';

/// 季報總覽查詢(2026-08-06,最新一季財報總覽頁的資料層)。
///
/// 口徑沿月營收總覽:
/// - 「最新一季」= 資料裡實際存在的最大 (year, quarter)——零日曆邏輯
/// - 只列 active 股票
/// - 去年同期 EPS 從 financial_data(dataType='EPS')以**季末日精確
///   join**:錯日期/錯 dataType 都不得誤撿——FinMind EPS 與官方
///   t187ap06 同為累計制,值可直接比
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '1232', name: '大統益', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '1570', name: '力肯', market: 'TPEx'),
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  }

  QuarterlyReportCompanion report(
    String symbol,
    int year,
    int quarter, {
    double? eps,
    double? netIncome,
    double? revenue,
  }) => QuarterlyReportCompanion.insert(
    symbol: symbol,
    year: year,
    quarter: quarter,
    eps: Value(eps),
    netIncome: Value(netIncome),
    revenue: Value(revenue),
  );

  FinancialDataCompanion finData(
    String symbol,
    DateTime date,
    String dataType,
    double value,
  ) => FinancialDataCompanion.insert(
    symbol: symbol,
    date: date,
    statementType: 'INCOME',
    dataType: dataType,
    value: Value(value),
  );

  test('🚨 最新一季完整清單+去年同期 EPS join(季末日精確比對)', () async {
    await seedStocks();
    await db.insertQuarterlyReports([
      // 舊季(2026Q1)——不該出現在總覽
      report('2330', 2026, 1, eps: 22.08, netIncome: 500),
      // 最新季(2026Q2)
      report('1232', 2026, 2, eps: 4.71, netIncome: 790350, revenue: 11481997),
      report('1570', 2026, 2, eps: 0.54, netIncome: 27849, revenue: 288259),
    ]);
    await db.insertFinancialData([
      // 1232 去年同期(2025Q2 累計)EPS——正解
      finData('1232', DateTime(2025, 6, 30), 'EPS', 3.10),
      // 干擾列:同代號同日不同 dataType、同代號異日 EPS——都不得誤撿
      finData('1232', DateTime(2025, 6, 30), 'ROE', 99.9),
      finData('1232', DateTime(2025, 3, 31), 'EPS', 1.50),
      // 1570 無歷史 → priorEps null
    ]);

    final overview = await db.getQuarterlyReportOverview();

    expect(overview, isNotNull);
    expect(overview!.year, 2026);
    expect(overview.quarter, 2);
    expect(overview.rows.length, 2, reason: '只列最新季,2330 的 Q1 不進來');

    final dtn = overview.rows.firstWhere((r) => r.symbol == '1232');
    expect(dtn.name, '大統益');
    expect(dtn.eps, 4.71);
    expect(dtn.netIncome, 790350);
    expect(dtn.revenue, 11481997);
    expect(dtn.priorEps, 3.10, reason: '2026Q2 → join 2025-06-30 的 EPS 列');

    final lk = overview.rows.firstWhere((r) => r.symbol == '1570');
    expect(lk.priorEps, isNull, reason: '無歷史不硬算');

    expect(overview.filedByMarket, {'TWSE': 1, 'TPEx': 1});
  });

  test('inactive(下市殭屍)股不進清單', () async {
    await seedStocks();
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: '9998',
        name: '殭屍',
        market: 'TWSE',
        isActive: const Value(false),
      ),
    ]);
    await db.insertQuarterlyReports([
      report('1232', 2026, 2, eps: 4.71),
      report('9998', 2026, 2, eps: 1.00),
    ]);

    final overview = await db.getQuarterlyReportOverview();

    expect(overview!.rows.map((r) => r.symbol).toList(), ['1232']);
  });

  test('空表 → null(入口據此隱藏)', () async {
    expect(await db.getQuarterlyReportOverview(), isNull);
  });

  test('Q1 的去年同期=去年 3/31;Q4 = 去年 12/31', () async {
    await seedStocks();
    await db.insertQuarterlyReports([report('1232', 2026, 1, eps: 1.20)]);
    await db.insertFinancialData([
      finData('1232', DateTime(2025, 3, 31), 'EPS', 0.80),
    ]);

    var overview = await db.getQuarterlyReportOverview();
    expect(overview!.rows.single.priorEps, 0.80);

    // 疊上 Q4(變成最新季)→ join 改抓 2025-12-31
    await db.insertQuarterlyReports([report('1232', 2026, 4, eps: 9.99)]);
    await db.insertFinancialData([
      finData('1232', DateTime(2025, 12, 31), 'EPS', 8.88),
    ]);
    overview = await db.getQuarterlyReportOverview();
    expect(overview!.quarter, 4);
    expect(overview.rows.single.priorEps, 8.88);
  });

  test('insertOrReplace:重抓同季覆蓋為新值(官方數字自我修正)', () async {
    await seedStocks();
    await db.insertQuarterlyReports([report('1232', 2026, 2, eps: 4.00)]);
    await db.insertQuarterlyReports([
      report('1232', 2026, 2, eps: 4.71, netIncome: 790350),
    ]);

    final overview = await db.getQuarterlyReportOverview();
    final row = overview!.rows.single;
    expect(row.eps, 4.71);
    expect(row.netIncome, 790350);
  });

  group('isTurnaround(轉虧為盈)', () {
    QuarterlyReportOverviewRow row({double? eps, double? priorEps}) =>
        QuarterlyReportOverviewRow(
          symbol: '0000',
          name: 'x',
          market: 'TWSE',
          eps: eps,
          netIncome: null,
          revenue: null,
          priorEps: priorEps,
        );

    test('去年 ≤0、本期 >0 才算;缺值一律 false', () {
      expect(row(eps: 1.2, priorEps: -0.5).isTurnaround, isTrue);
      expect(row(eps: 1.2, priorEps: 0).isTurnaround, isTrue);
      expect(row(eps: 1.2, priorEps: 0.5).isTurnaround, isFalse);
      expect(row(eps: -0.1, priorEps: -0.5).isTurnaround, isFalse);
      expect(row(eps: null, priorEps: -0.5).isTurnaround, isFalse);
      expect(row(eps: 1.2, priorEps: null).isTurnaround, isFalse);
    });
  });
}
