import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

/// 法人買賣超排行查詢(2026-08-05,盤後籌碼排行頁的資料層)。
///
/// 口徑(與使用者定稿):
/// - 排序鍵=**金額**(淨股數 × 當日收盤),張數並列顯示——跨價位可比
///   (實測 8/4:欣興 5,933 張 54.8 億 vs 川湖 233 張 22.2 億,張數會誤導)
/// - **連買/連賣天數**:以「資料存在的交易日」連續同號計,含最新日
/// - **雙買/雙賣**:外資與投信同日同向(買賣超榜的最強共識訊號)
/// - 自營刻意不做榜(避險盤污染+持續性差,2026-08-05 設計討論)
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
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '3231', name: '緯創', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '6669', name: '緯穎', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2303', name: '聯電', market: 'TWSE'),
    ]);
  }

  Future<void> seedDay(
    String symbol,
    DateTime date, {
    double? foreignNet,
    double? trustNet,
    required double close,
  }) async {
    await db.insertInstitutionalData([
      DailyInstitutionalCompanion.insert(
        symbol: symbol,
        date: date,
        foreignNet: Value(foreignNet),
        investmentTrustNet: Value(trustNet),
      ),
    ]);
    await db.insertPrices([
      DailyPriceCompanion.insert(
        symbol: symbol,
        date: date,
        close: Value(close),
        volume: const Value(1000),
      ),
    ]);
  }

  final d1 = DateTime(2026, 8, 1);
  final d2 = DateTime(2026, 8, 3);
  final d3 = DateTime(2026, 8, 4);

  test('🚨 外資買超榜:按金額排序(張數大者若單價低要輸給金額大者)', () async {
    await seedStocks();
    // 緯創:2萬張 × 200 = 40 億;緯穎:500 張 × 6000 = 30 億;
    // 聯電:3萬張 × 100 = 30 億——張數最大但金額只並列第二
    await seedDay('3231', d3, foreignNet: 20000e3, close: 200);
    await seedDay('6669', d3, foreignNet: 500e3, close: 6000);
    await seedDay('2303', d3, foreignNet: 30000e3, close: 100);
    await seedDay('2330', d3, foreignNet: -5000e3, close: 2400); // 賣超不進買榜

    final r = await db.getInstitutionalRanking();

    final buy = r!.foreignBuy;
    expect(buy.first.symbol, '3231', reason: '40 億金額最大');
    expect(buy.map((e) => e.symbol), isNot(contains('2330')));
    expect(buy.first.netAmount, closeTo(40e8, 1));
    expect(buy.first.netShares, closeTo(20000e3, 1));
  });

  test('🚨 賣超榜:負淨額按絕對金額排序', () async {
    await seedStocks();
    await seedDay('2330', d3, foreignNet: -5000e3, close: 2400); // -120 億
    await seedDay('2303', d3, foreignNet: -30000e3, close: 100); // -30 億
    await seedDay('3231', d3, foreignNet: 1000e3, close: 200);

    final r = await db.getInstitutionalRanking();

    expect(r!.foreignSell.map((e) => e.symbol).toList(), ['2330', '2303']);
  });

  test('🚨 連買天數:連續同號含最新日;中斷歸零重計', () async {
    await seedStocks();
    // 緯創:三日連買 → streak 3
    await seedDay('3231', d1, foreignNet: 1000e3, close: 190);
    await seedDay('3231', d2, foreignNet: 2000e3, close: 195);
    await seedDay('3231', d3, foreignNet: 3000e3, close: 200);
    // 緯穎:d2 賣超中斷 → streak 1
    await seedDay('6669', d1, foreignNet: 100e3, close: 5900);
    await seedDay('6669', d2, foreignNet: -50e3, close: 5950);
    await seedDay('6669', d3, foreignNet: 200e3, close: 6000);

    final r = await db.getInstitutionalRanking();

    final bySymbol = {for (final e in r!.foreignBuy) e.symbol: e};
    expect(bySymbol['3231']!.streakDays, 3);
    expect(bySymbol['6669']!.streakDays, 1);
  });

  test('🚨 雙買/雙賣旗標:外資與投信同日同向', () async {
    await seedStocks();
    await seedDay('3231', d3, foreignNet: 1000e3, trustNet: 500e3, close: 200);
    await seedDay(
      '6669',
      d3,
      foreignNet: 1000e3,
      trustNet: -100e3,
      close: 6000,
    );
    await seedDay('2330', d3, foreignNet: -900e3, trustNet: -80e3, close: 2400);

    final r = await db.getInstitutionalRanking();

    final buy = {for (final e in r!.foreignBuy) e.symbol: e};
    expect(buy['3231']!.isDualSide, isTrue);
    expect(buy['6669']!.isDualSide, isFalse);
    final sell = {for (final e in r.foreignSell) e.symbol: e};
    expect(sell['2330']!.isDualSide, isTrue, reason: '雙賣同樣標記');
  });

  test('投信榜獨立於外資榜;無投信資料的股票不進投信榜', () async {
    await seedStocks();
    await seedDay('3231', d3, foreignNet: 1000e3, trustNet: 500e3, close: 200);
    await seedDay('2303', d3, foreignNet: 2000e3, close: 100); // trust null

    final r = await db.getInstitutionalRanking();

    expect(r!.trustBuy.map((e) => e.symbol).toList(), ['3231']);
    expect(r.foreignBuy, hasLength(2));
  });

  test('limit 生效:超過上限截斷', () async {
    await seedStocks();
    await seedDay('3231', d3, foreignNet: 3000e3, close: 200);
    await seedDay('6669', d3, foreignNet: 2000e3, close: 200);
    await seedDay('2303', d3, foreignNet: 1000e3, close: 200);

    final r = await db.getInstitutionalRanking(limit: 2);

    expect(r!.foreignBuy, hasLength(2));
    expect(r.foreignBuy.map((e) => e.symbol).toList(), ['3231', '6669']);
  });

  test('🚨 上市未發布時基準日退回雙市場齊備日(15:30~21:30 過渡態不出半套榜)', () async {
    await seedStocks();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '6538', name: '倉和', market: 'TPEx'),
    ]);
    // d2:上市+上櫃都有(完整日);d3:只有上櫃(TPEx 法人先發布)
    await seedDay('3231', d2, foreignNet: 1000e3, close: 195);
    await seedDay('6538', d2, foreignNet: 300e3, close: 150);
    await seedDay('6538', d3, foreignNet: 500e3, close: 160);

    final r = await db.getInstitutionalRanking();

    expect(r!.date, DateTime(2026, 8, 3), reason: '基準日=上市已到的最新日');
    final symbols = r.foreignBuy.map((e) => e.symbol).toSet();
    expect(symbols, {'3231', '6538'}, reason: '用 d2 完整日的資料,不是 d3 半套');
  });

  test('🚨 ETF(00 開頭)不進榜——申購/造市的機制性買賣非選股訊號', () async {
    await seedStocks();
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: '0050',
        name: '元大台灣50',
        market: 'TWSE',
      ),
    ]);
    await seedDay('0050', d3, foreignNet: 50000e3, close: 200); // 100 億也不進
    await seedDay('3231', d3, foreignNet: 1000e3, close: 200);

    final r = await db.getInstitutionalRanking();

    expect(r!.foreignBuy.map((e) => e.symbol).toList(), ['3231']);
  });

  test('空表 → null', () async {
    expect(await db.getInstitutionalRanking(), isNull);
  });
}
