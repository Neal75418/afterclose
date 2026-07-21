// insertMonthlyRevenue 的 upsert 語意
//
// 背景：per-symbol 回補（詳情頁、watchlist 營收歷史 warm-up）抓固定窗口，
// 窗口舊端的月份在該批次內沒有前一年同月基期 → calculateGrowthRates 算出
// yoyGrowth=null。若用整列 REPLACE，會把先前更寬窗口算好的非空 YoY 靜默
// 降級成 null（表格上已顯示的年增率變回「-」）。故 growth 欄位必須
// coalesce(新值, 舊值)：非空新值照常更新，null 不得覆蓋非空舊值。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  MonthlyRevenueCompanion rev({
    double revenue = 100000,
    double? mom,
    double? yoy,
  }) {
    return MonthlyRevenueCompanion.insert(
      symbol: '2330',
      date: DateTime(2026, 3),
      revenueYear: 2026,
      revenueMonth: 3,
      revenue: revenue,
      momGrowth: Value(mom),
      yoyGrowth: Value(yoy),
    );
  }

  group('insertMonthlyRevenue upsert 語意', () {
    test('null growth 不得覆蓋既有非空值（營收本身照常更新）', () async {
      await db.insertMonthlyRevenue([
        rev(revenue: 100000, mom: 5.0, yoy: 30.0),
      ]);
      // 窄窗口重抓：同月算不出成長率 → null
      await db.insertMonthlyRevenue([
        rev(revenue: 100500, mom: null, yoy: null),
      ]);

      final rows = await db.getMonthlyRevenueHistory(
        '2330',
        startDate: DateTime(2025, 1),
      );
      expect(rows, hasLength(1));
      expect(rows.single.revenue, 100500); // 新營收值生效
      expect(rows.single.momGrowth, 5.0); // 舊值保留
      expect(rows.single.yoyGrowth, 30.0); // 舊值保留
    });

    test('非空 growth 照常更新（重算/修正要能寫入）', () async {
      await db.insertMonthlyRevenue([rev(mom: 5.0, yoy: 30.0)]);
      await db.insertMonthlyRevenue([rev(mom: 6.0, yoy: 31.0)]);

      final rows = await db.getMonthlyRevenueHistory(
        '2330',
        startDate: DateTime(2025, 1),
      );
      expect(rows.single.momGrowth, 6.0);
      expect(rows.single.yoyGrowth, 31.0);
    });

    test('首次插入 null growth → 存 null（無舊值可保留）', () async {
      await db.insertMonthlyRevenue([rev(mom: null, yoy: null)]);

      final rows = await db.getMonthlyRevenueHistory(
        '2330',
        startDate: DateTime(2025, 1),
      );
      expect(rows.single.momGrowth, isNull);
      expect(rows.single.yoyGrowth, isNull);
    });
  });
}
