// CandidateSelector 測試 — 流動性下限（2026-07 評分改進 #4）
//
// 真 in-memory Drift DB（不 mock），驗證：
//   1. 市場候選股 20 日中位成交值 < 門檻 → 濾除
//   2. 自選清單豁免（使用者主動追蹤、不過濾）
//   3. 成交值資料不足（新上市）→ permissive 放行
//
// 門檻依據（2026-07-11 本機 DB 實測）：P50=1,930 萬、3,000 萬砍 56% 無效
// 運算但訊號股只損失 7%；被砍的是滑價會吃掉 edge 的薄流動性股。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/update/candidate_selector.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  final today = DateTime(2026, 7, 10);

  /// 插入一檔股票 + [days] 天價格。
  /// [dailyTurnover] = 每日成交值（volume × close 恰等於它）。
  Future<void> seedStock(
    String symbol, {
    int days = 40,
    double close = 100.0,
    required double dailyTurnover,
  }) async {
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: symbol,
        name: 'T$symbol',
        market: 'TWSE',
      ),
    ]);
    final prices = <DailyPriceCompanion>[];
    for (var i = days; i >= 1; i--) {
      prices.add(
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: today.subtract(Duration(days: i)),
          close: Value(close),
          volume: Value(dailyTurnover / close),
        ),
      );
    }
    await db.insertPrices(prices);
  }

  CandidateSelector makeSelector() =>
      CandidateSelector(database: db, popularStocks: const []);

  group('CandidateSelector — 流動性下限', () {
    test('市場候選股中位成交值低於門檻 → 濾除；達標者保留', () async {
      await seedStock('1101', dailyTurnover: 100e6); // 1 億 → 過
      await seedStock('9999', dailyTurnover: 5e6); // 500 萬 → 砍

      final result = await makeSelector().filterCandidates(
        date: today,
        marketCandidates: const ['1101', '9999'],
      );

      expect(result, contains('1101'));
      expect(
        result,
        isNot(contains('9999')),
        reason: '20 日中位成交值 500 萬 < ${RuleParams.liquidityMinMedianTurnoverNtd}',
      );
    });

    test('門檻邊界：恰等於門檻 → 保留（>= 語意）', () async {
      await seedStock(
        '1102',
        dailyTurnover: RuleParams.liquidityMinMedianTurnoverNtd.toDouble(),
      );

      final result = await makeSelector().filterCandidates(
        date: today,
        marketCandidates: const ['1102'],
      );
      expect(result, contains('1102'));
    });

    test('自選清單豁免：即使流動性極低也保留', () async {
      await seedStock('9998', dailyTurnover: 1e6); // 100 萬、遠低於門檻
      await db.addToWatchlist('9998');

      final result = await makeSelector().filterCandidates(
        date: today,
        marketCandidates: const [],
      );
      expect(result, contains('9998'), reason: '使用者主動追蹤的自選股不套流動性過濾');
    });

    test('成交值資料不足（有效天數 < 最低判定天數）→ permissive 放行', () async {
      // 歷史夠（過 sufficiency 篩選）但 volume 全 null → 無法判定流動性
      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: '7777',
          name: 'IPO',
          market: 'TWSE',
        ),
      ]);
      final prices = <DailyPriceCompanion>[];
      for (var i = 40; i >= 1; i--) {
        prices.add(
          DailyPriceCompanion.insert(
            symbol: '7777',
            date: today.subtract(Duration(days: i)),
            close: const Value(50.0),
            // volume 缺漏 → 成交值不可算
          ),
        );
      }
      await db.insertPrices(prices);

      final result = await makeSelector().filterCandidates(
        date: today,
        marketCandidates: const ['7777'],
      );
      expect(
        result,
        contains('7777'),
        reason: '無資料 ≠ 低流動性，permissive 放行（與 null-permissive 慣例一致）',
      );
    });
  });

  group('PriceDao.getMedianTurnoverBatch', () {
    test('回傳每檔近 N 交易日的中位成交值（volume × close）', () async {
      await seedStock('2330', dailyTurnover: 80e9, close: 1000);
      await seedStock('8888', dailyTurnover: 12e6, close: 20);

      final med = await db.getMedianTurnoverBatch(
        endDate: today,
        windowDays: RuleParams.liquidityMedianWindowDays,
        minDataDays: RuleParams.liquidityMinDataDays,
      );
      expect(med['2330'], closeTo(80e9, 1e3));
      expect(med['8888'], closeTo(12e6, 1e3));
    });

    test('有效天數不足 minDataDays 的股票不出現在結果', () async {
      // 必須同場有一檔 ≥ windowDays 的股票，否則全市場 distinct dates
      // 不足、cutoff 解析失敗會提前回空 map —— 那驗到的是短路而非
      // per-symbol omission 分支。
      await seedStock('2330', dailyTurnover: 80e9, close: 1000);
      await seedStock('4444', days: 5, dailyTurnover: 90e6);

      final med = await db.getMedianTurnoverBatch(
        endDate: today,
        windowDays: RuleParams.liquidityMedianWindowDays,
        minDataDays: RuleParams.liquidityMinDataDays,
      );
      expect(med.containsKey('2330'), isTrue, reason: '正常股保留');
      expect(
        med.containsKey('4444'),
        isFalse,
        reason: '窗內有效天數 5 < ${RuleParams.liquidityMinDataDays} → 略去',
      );
    });

    test('中位數偶數分支：不等值序列取中間兩值平均', () async {
      // 20 天成交值：10 天 20M、10 天 40M（排序後 v[9]=20M, v[10]=40M）
      // → median = 30M。等值資料測不出 even-branch 取值索引錯誤。
      await db.upsertStocks([
        StockMasterCompanion.insert(symbol: '5555', name: 'E', market: 'TWSE'),
      ]);
      final prices = <DailyPriceCompanion>[];
      for (var i = 20; i >= 1; i--) {
        final turnover = i.isEven ? 20e6 : 40e6;
        prices.add(
          DailyPriceCompanion.insert(
            symbol: '5555',
            date: today.subtract(Duration(days: i)),
            close: const Value(100.0),
            volume: Value(turnover / 100.0),
          ),
        );
      }
      await db.insertPrices(prices);

      final med = await db.getMedianTurnoverBatch(
        endDate: today,
        windowDays: RuleParams.liquidityMedianWindowDays,
        minDataDays: RuleParams.liquidityMinDataDays,
      );
      expect(med['5555'], closeTo(30e6, 1e3));
    });
  });
}
