import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

/// 營收總覽清單查詢(2026-08-05,月營收完整清單頁的資料層)。
///
/// 口徑:
/// - 「最新月份」= 資料裡實際存在的最大 (year, month)——零日曆邏輯,
///   公布期自然指向進行中的月、平時指向最後完整月
/// - 「創高」= 純資料口徑(當月營收 > 歷史最高,排除當月自身),沿用
///   [RevenueDao.getMaxRevenueBatch] 的同一個基準——**刻意不含**
///   REVENUE_NEW_HIGH 規則的「站上 MA20」技術過濾:清單是資料事實
///   視角,技術面安靜的創高股正是清單要保住、訊號層看不見的族群
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
      StockMasterCompanion.insert(symbol: '2408', name: '南亞科', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '6538', name: '倉和', market: 'TPEx'),
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  }

  Future<void> seedRevenue(
    String symbol,
    int year,
    int month,
    double revenue, {
    double? yoy,
  }) {
    return db.insertMonthlyRevenue([
      MonthlyRevenueCompanion.insert(
        symbol: symbol,
        date: DateTime(year, month),
        revenueYear: year,
        revenueMonth: month,
        revenue: revenue,
        yoyGrowth: Value(yoy),
      ),
    ]);
  }

  test('🚨 清單=資料中最新月的全部列(公布期部分覆蓋也照實列)', () async {
    await seedStocks();
    // 6 月:三檔都有;7 月:只有兩檔申報(2330 還沒交卷)
    await seedRevenue('2408', 2026, 6, 100);
    await seedRevenue('6538', 2026, 6, 50);
    await seedRevenue('2330', 2026, 6, 999);
    await seedRevenue('2408', 2026, 7, 43867609, yoy: 719.6);
    await seedRevenue('6538', 2026, 7, 60, yoy: 20.0);

    final overview = await db.getRevenueOverviewForLatestMonth();

    expect(overview, isNotNull);
    expect(overview!.year, 2026);
    expect(overview.month, 7);
    expect(overview.rows, hasLength(2), reason: '未申報的 2330 不在 7 月清單');
    final codes = overview.rows.map((r) => r.symbol).toSet();
    expect(codes, {'2408', '6538'});
  });

  test('🚨 創高判定:當月 > 歷史最高(排除當月自身);首月資料不算創高', () async {
    await seedStocks();
    await seedRevenue('2408', 2026, 5, 200);
    await seedRevenue('2408', 2026, 6, 100);
    await seedRevenue('2408', 2026, 7, 300); // > max(200,100) → 創高
    await seedRevenue('6538', 2026, 6, 80);
    await seedRevenue('6538', 2026, 7, 70); // < 80 → 非創高
    await seedRevenue('2330', 2026, 7, 500); // 首月資料,無歷史基準 → 非創高

    final overview = await db.getRevenueOverviewForLatestMonth();

    final bySymbol = {for (final r in overview!.rows) r.symbol: r};
    expect(bySymbol['2408']!.isNewHigh, isTrue);
    expect(bySymbol['6538']!.isNewHigh, isFalse);
    expect(bySymbol['2330']!.isNewHigh, isFalse, reason: '無歷史可比不算創高');
  });

  test('列帶名稱/市場/YoY;各市場已申報數正確(無分母——算不準的不顯示)', () async {
    await seedStocks();
    await seedRevenue('2408', 2026, 7, 100, yoy: 12.3);
    await seedRevenue('6538', 2026, 7, 50);

    final overview = await db.getRevenueOverviewForLatestMonth();

    final r = overview!.rows.firstWhere((r) => r.symbol == '2408');
    expect(r.name, '南亞科');
    expect(r.market, 'TWSE');
    expect(r.yoyGrowth, closeTo(12.3, 0.001));
    expect(overview.filedByMarket['TWSE'], 1);
    expect(overview.filedByMarket['TPEx'], 1);
  });

  test('非 active(下市)股票不進清單', () async {
    await seedStocks();
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: '9104',
        name: '殭屍',
        market: 'TWSE',
        isActive: const Value(false),
      ),
    ]);
    await seedRevenue('9104', 2026, 7, 100);
    await seedRevenue('2408', 2026, 7, 100);

    final overview = await db.getRevenueOverviewForLatestMonth();

    expect(overview!.rows.map((r) => r.symbol), isNot(contains('9104')));
  });

  test('空表 → null(app 首裝零資料不炸)', () async {
    final overview = await db.getRevenueOverviewForLatestMonth();
    expect(overview, isNull);
  });
}
