import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/quarterly_report_dao.dart';

/// 季報總覽查詢(2026-08-06,最新一季財報總覽頁的資料層)。
///
/// 口徑沿月營收總覽:
/// - 「最新一季」= 資料裡實際存在的最大 (year, quarter)——零日曆邏輯
/// - 只列 active 股票
/// - 去年同期 EPS:官方 t187ap06 是**累計制**(Q2=上半年),FinMind 的
///   financial_data EPS 是**單季**值(生產資料實測 2454 序列
///   18.43→17.5→15.84→14.4 遞減,累計制不可能遞減)——基期必須
///   **加總去年 1..Q 季**,且 Q 季齊全才算(缺季 null,不硬算低估的
///   假基期把年增方向弄反)
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
      // 1232 去年 H1 = Q1(1.60)+Q2(1.50) 單季加總 = 3.10——正解
      finData('1232', DateTime(2025, 3, 31), 'EPS', 1.60),
      finData('1232', DateTime(2025, 6, 30), 'EPS', 1.50),
      // 干擾列:同代號同日不同 dataType、前年 EPS——都不得混進加總
      finData('1232', DateTime(2025, 6, 30), 'ROE', 99.9),
      finData('1232', DateTime(2024, 6, 30), 'EPS', 5.00),
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
    expect(
      dtn.priorEps,
      closeTo(3.10, 1e-9),
      reason: '2026Q2 基期 = 2025Q1+2025Q2 單季 EPS 加總',
    );

    final lk = overview.rows.firstWhere((r) => r.symbol == '1570');
    expect(lk.priorEps, isNull, reason: '無歷史不硬算');

    expect(overview.filedByMarket, {'TWSE': 1, 'TPEx': 1});
  });

  test('🚨 去年基期缺季 → null(單季比累計會把年增方向弄反)', () async {
    await seedStocks();
    await db.insertQuarterlyReports([report('2330', 2026, 2, eps: 30.44)]);
    // 只有 2025Q2 單季、缺 2025Q1 → 不得拿 17.5 冒充 H1 基期
    await db.insertFinancialData([
      finData('2330', DateTime(2025, 6, 30), 'EPS', 17.5),
    ]);

    final overview = await db.getQuarterlyReportOverview();

    expect(overview!.rows.single.priorEps, isNull);
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

  test('Q1 基期=去年 Q1 單季;Q4 基期=去年四季加總(缺季前不成立)', () async {
    await seedStocks();
    await db.insertQuarterlyReports([report('1232', 2026, 1, eps: 1.20)]);
    await db.insertFinancialData([
      finData('1232', DateTime(2025, 3, 31), 'EPS', 0.80),
    ]);

    var overview = await db.getQuarterlyReportOverview();
    expect(overview!.rows.single.priorEps, 0.80, reason: 'Q1 只需一季');

    // 疊上 Q4(變成最新季):此時去年只有 Q1 一季在庫 → 基期 null
    await db.insertQuarterlyReports([report('1232', 2026, 4, eps: 9.99)]);
    overview = await db.getQuarterlyReportOverview();
    expect(overview!.quarter, 4);
    expect(overview.rows.single.priorEps, isNull, reason: '四季缺三 → 不硬算');

    // 補齊 Q2~Q4 → 基期 = 0.80+2.00+2.00+4.08 = 8.88
    await db.insertFinancialData([
      finData('1232', DateTime(2025, 6, 30), 'EPS', 2.00),
      finData('1232', DateTime(2025, 9, 30), 'EPS', 2.00),
      finData('1232', DateTime(2025, 12, 31), 'EPS', 4.08),
    ]);
    overview = await db.getQuarterlyReportOverview();
    expect(overview!.rows.single.priorEps, closeTo(8.88, 1e-9));
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

    test('epsYoyDelta=排序鍵與年增欄的單一事實來源;缺任一值 null', () {
      expect(
        row(eps: 30.44, priorEps: 35.93).epsYoyDelta,
        closeTo(-5.49, 1e-9),
      );
      expect(row(eps: 1.2, priorEps: -0.5).epsYoyDelta, closeTo(1.7, 1e-9));
      expect(row(eps: 1.2, priorEps: null).epsYoyDelta, isNull);
      expect(row(eps: null, priorEps: 0.5).epsYoyDelta, isNull);
    });
  });
}
