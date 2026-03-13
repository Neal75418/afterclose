import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  final today = DateTime.utc(2025, 6, 15);

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '6488', name: '環球晶', market: 'TPEx'),
      StockMasterCompanion.insert(symbol: '3293', name: '鑫科', market: 'TPEx'),
    ]);
  }

  group('MarketOverviewDao', () {
    setUp(() async {
      await insertTestStocks();
    });

    group('getAdvanceDeclineCountsByMarket', () {
      test('groups advance/decline/unchanged by market', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(5.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
            priceChange: const Value(-2.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(600.0),
            priceChange: const Value(0.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '3293',
            date: today,
            close: const Value(30.0),
            priceChange: const Value(1.0),
          ),
        ]);

        final result = await db.getAdvanceDeclineCountsByMarket(today);

        expect(result['TWSE']?['advance'], 1);
        expect(result['TWSE']?['decline'], 1);
        expect(result['TWSE']?['unchanged'], 0);

        expect(result['TPEx']?['advance'], 1);
        expect(result['TPEx']?['decline'], 0);
        expect(result['TPEx']?['unchanged'], 1);
      });

      test('excludes rows with null close or priceChange', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(5.0),
          ),
          // Null priceChange
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
          ),
          // Null close
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            priceChange: const Value(1.0),
          ),
        ]);

        final result = await db.getAdvanceDeclineCountsByMarket(today);

        expect(result['TWSE']?['advance'], 1);
        expect(result['TWSE']?['decline'], 0);
        expect(result['TWSE']?['unchanged'], 0);
        expect(result['TPEx'], isNull);
      });

      test('returns empty map for date with no data', () async {
        final result = await db.getAdvanceDeclineCountsByMarket(today);

        expect(result, isEmpty);
      });
    });

    group('getAdvanceDeclineCounts', () {
      test('merges TWSE and TPEx totals', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(5.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(600.0),
            priceChange: const Value(3.0),
          ),
        ]);

        final result = await db.getAdvanceDeclineCounts(today);

        expect(result['advance'], 2);
        expect(result['decline'], 0);
        expect(result['unchanged'], 0);
      });
    });

    group('getInstitutionalTotalsByMarket', () {
      test('sums institutional data by market', () async {
        await db.insertInstitutionalData([
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: today,
            foreignNet: const Value(1000.0),
            investmentTrustNet: const Value(500.0),
            dealerNet: const Value(-200.0),
          ),
          DailyInstitutionalCompanion.insert(
            symbol: '2317',
            date: today,
            foreignNet: const Value(2000.0),
            investmentTrustNet: const Value(-100.0),
            dealerNet: const Value(300.0),
          ),
          DailyInstitutionalCompanion.insert(
            symbol: '6488',
            date: today,
            foreignNet: const Value(500.0),
            investmentTrustNet: const Value(200.0),
            dealerNet: const Value(100.0),
          ),
        ]);

        final result = await db.getInstitutionalTotalsByMarket(today);

        // TWSE: 2330 + 2317
        expect(result['TWSE']?['foreignNet'], 3000.0);
        expect(result['TWSE']?['trustNet'], 400.0);
        expect(result['TWSE']?['dealerNet'], 100.0);
        expect(result['TWSE']?['totalNet'], 3500.0);

        // TPEx: 6488
        expect(result['TPEx']?['foreignNet'], 500.0);
        expect(result['TPEx']?['trustNet'], 200.0);
        expect(result['TPEx']?['dealerNet'], 100.0);
        expect(result['TPEx']?['totalNet'], 800.0);
      });

      test('returns empty map for date with no data', () async {
        final result = await db.getInstitutionalTotalsByMarket(today);

        expect(result, isEmpty);
      });
    });

    group('getInstitutionalTotals', () {
      test('merges all markets', () async {
        await db.insertInstitutionalData([
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: today,
            foreignNet: const Value(1000.0),
            investmentTrustNet: const Value(500.0),
            dealerNet: const Value(-200.0),
          ),
          DailyInstitutionalCompanion.insert(
            symbol: '6488',
            date: today,
            foreignNet: const Value(500.0),
            investmentTrustNet: const Value(200.0),
            dealerNet: const Value(100.0),
          ),
        ]);

        final result = await db.getInstitutionalTotals(today);

        expect(result['foreignNet'], 1500.0);
        expect(result['trustNet'], 700.0);
        expect(result['dealerNet'], -100.0);
        expect(result['totalNet'], 2100.0);
      });
    });

    group('getMarginTradingTotalsByMarket', () {
      test('sums margin trading data by market', () async {
        await db.insertMarginTradingData([
          MarginTradingCompanion.insert(
            symbol: '2330',
            date: today,
            marginBuy: const Value(100.0),
            marginSell: const Value(80.0),
            marginBalance: const Value(5000.0),
            shortBuy: const Value(20.0),
            shortSell: const Value(30.0),
            shortBalance: const Value(200.0),
          ),
          MarginTradingCompanion.insert(
            symbol: '6488',
            date: today,
            marginBuy: const Value(50.0),
            marginSell: const Value(40.0),
            marginBalance: const Value(2000.0),
            shortBuy: const Value(10.0),
            shortSell: const Value(15.0),
            shortBalance: const Value(100.0),
          ),
        ]);

        final result = await db.getMarginTradingTotalsByMarket(today);

        // TWSE: 2330
        expect(result['TWSE']?['marginBalance'], 5000.0);
        // marginChange = margin_buy - margin_sell = 100 - 80 = 20
        expect(result['TWSE']?['marginChange'], 20.0);
        expect(result['TWSE']?['shortBalance'], 200.0);
        // shortChange = short_sell - short_buy = 30 - 20 = 10
        expect(result['TWSE']?['shortChange'], 10.0);

        // TPEx: 6488
        expect(result['TPEx']?['marginBalance'], 2000.0);
        expect(result['TPEx']?['marginChange'], 10.0);
        expect(result['TPEx']?['shortBalance'], 100.0);
        expect(result['TPEx']?['shortChange'], 5.0);
      });

      test('returns empty map for date with no data', () async {
        final result = await db.getMarginTradingTotalsByMarket(today);

        expect(result, isEmpty);
      });
    });

    group('getMarginTradingTotals', () {
      test('merges all markets', () async {
        await db.insertMarginTradingData([
          MarginTradingCompanion.insert(
            symbol: '2330',
            date: today,
            marginBuy: const Value(100.0),
            marginSell: const Value(80.0),
            marginBalance: const Value(5000.0),
            shortBuy: const Value(20.0),
            shortSell: const Value(30.0),
            shortBalance: const Value(200.0),
          ),
          MarginTradingCompanion.insert(
            symbol: '6488',
            date: today,
            marginBuy: const Value(50.0),
            marginSell: const Value(40.0),
            marginBalance: const Value(2000.0),
            shortBuy: const Value(10.0),
            shortSell: const Value(15.0),
            shortBalance: const Value(100.0),
          ),
        ]);

        final result = await db.getMarginTradingTotals(today);

        expect(result['marginBalance'], 7000.0);
        expect(result['marginChange'], 30.0);
        expect(result['shortBalance'], 300.0);
        expect(result['shortChange'], 15.0);
      });
    });

    group('getTurnoverSummaryByMarket', () {
      test('calculates turnover (close * volume) by market', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(10000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
            volume: const Value(20000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(600.0),
            volume: const Value(5000.0),
          ),
        ]);

        final result = await db.getTurnoverSummaryByMarket(today);

        // TWSE: 100*10000 + 50*20000 = 2000000
        expect(result['TWSE']?['totalTurnover'], 2000000.0);
        // TPEx: 600*5000 = 3000000
        expect(result['TPEx']?['totalTurnover'], 3000000.0);
      });

      test('excludes rows with null close or volume', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(10000.0),
          ),
          // Null volume
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
          ),
        ]);

        final result = await db.getTurnoverSummaryByMarket(today);

        expect(result['TWSE']?['totalTurnover'], 1000000.0);
      });

      test('returns empty map for date with no data', () async {
        final result = await db.getTurnoverSummaryByMarket(today);

        expect(result, isEmpty);
      });
    });

    group('getTurnoverSummary', () {
      test('merges all markets', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(10000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(600.0),
            volume: const Value(5000.0),
          ),
        ]);

        final result = await db.getTurnoverSummary(today);

        // 100*10000 + 600*5000 = 4000000
        expect(result['totalTurnover'], 4000000.0);
      });
    });

    // ── getLimitUpDownCountsByMarket ────────────────────────

    group('getLimitUpDownCountsByMarket', () {
      test('counts limit-up and limit-down by market', () async {
        // 2330: close=110, priceChange=10
        //   → 10/(110-10)*100 = 10% ≥ 9.5 → limit up
        // 2317: close=90, priceChange=-9
        //   → -9/(90-(-9))*100 = -9.09% > -9.5 → NOT limit down
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(10.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(90.0),
            priceChange: const Value(-9.0),
          ),
        ]);

        final result = await db.getLimitUpDownCountsByMarket(today);

        expect(result['TWSE']?['limitUp'], 1);
        expect(result['TWSE']?['limitDown'], 0);
      });

      test('detects limit-down at exact -9.5% threshold', () async {
        // close=90.5, priceChange=-9.5
        //   → -9.5/(90.5-(-9.5))*100 = -9.5/100*100 = -9.5%
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(90.5),
            priceChange: const Value(-9.5),
          ),
        ]);

        final result = await db.getLimitUpDownCountsByMarket(today);

        expect(result['TWSE']?['limitDown'], 1);
      });

      test('excludes rows where previous close is zero', () async {
        // close=5, priceChange=5 → (close-priceChange)=0 → excluded
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(5.0),
            priceChange: const Value(5.0),
          ),
        ]);

        final result = await db.getLimitUpDownCountsByMarket(today);

        expect(result, isEmpty);
      });

      test('returns empty map when no data', () async {
        final result = await db.getLimitUpDownCountsByMarket(today);

        expect(result, isEmpty);
      });
    });

    // ── getRecentTurnoverByMarket ──────────────────────────

    group('getRecentTurnoverByMarket', () {
      test('returns daily turnover per market, date descending', () async {
        for (var i = 0; i < 3; i++) {
          final d = today.subtract(Duration(days: i));
          await db.insertPrices([
            DailyPriceCompanion.insert(
              symbol: '2330',
              date: d,
              close: const Value(100.0),
              volume: const Value(1000.0),
            ),
            DailyPriceCompanion.insert(
              symbol: '2317',
              date: d,
              close: const Value(50.0),
              volume: const Value(500.0),
            ),
          ]);
        }

        final result = await db.getRecentTurnoverByMarket(today, days: 2);
        final twse = result['TWSE']!;

        // days+1 = 3 entries
        expect(twse.length, 3);
        // Most recent first
        expect(twse.first.date, today);
        // Turnover = 100*1000 + 50*500 = 125000
        expect(twse.first.turnover, 125000.0);
      });

      test('separates TWSE and TPEx turnover', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(1000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(200.0),
            volume: const Value(300.0),
          ),
        ]);

        final result = await db.getRecentTurnoverByMarket(today);

        expect(result['TWSE']!.first.turnover, 100000.0);
        expect(result['TPEx']!.first.turnover, 60000.0);
      });

      test('limits result to days+1 entries', () async {
        // Insert 10 days of data
        for (var i = 0; i < 10; i++) {
          await db.insertPrices([
            DailyPriceCompanion.insert(
              symbol: '2330',
              date: today.subtract(Duration(days: i)),
              close: const Value(100.0),
              volume: const Value(1000.0),
            ),
          ]);
        }

        final result = await db.getRecentTurnoverByMarket(today, days: 3);

        // Should have at most 3+1 = 4 entries
        expect(result['TWSE']!.length, 4);
      });
    });

    // ── getActiveWarningCountsByMarket ─────────────────────

    group('getActiveWarningCountsByMarket', () {
      test('counts active warnings by market and type', () async {
        await db.insertWarningData([
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: today,
            warningType: 'ATTENTION',
          ),
          TradingWarningCompanion.insert(
            symbol: '2317',
            date: today,
            warningType: 'DISPOSAL',
          ),
          TradingWarningCompanion.insert(
            symbol: '6488',
            date: today,
            warningType: 'ATTENTION',
          ),
        ]);

        final result = await db.getActiveWarningCountsByMarket();

        expect(result['TWSE']?['ATTENTION'], 1);
        expect(result['TWSE']?['DISPOSAL'], 1);
        expect(result['TPEx']?['ATTENTION'], 1);
      });

      test('excludes inactive warnings', () async {
        await db.insertWarningData([
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: today,
            warningType: 'ATTENTION',
            isActive: const Value(false),
          ),
        ]);

        final result = await db.getActiveWarningCountsByMarket();

        expect(result, isEmpty);
      });

      test('counts distinct symbols (dedup same symbol)', () async {
        // Same symbol, different dates → should count as 1
        await db.insertWarningData([
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: today,
            warningType: 'ATTENTION',
          ),
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 5)),
            warningType: 'ATTENTION',
          ),
        ]);

        final result = await db.getActiveWarningCountsByMarket();

        expect(result['TWSE']?['ATTENTION'], 1);
      });
    });

    // ── getRecentInstitutionalDailyByMarket ────────────────

    group('getRecentInstitutionalDailyByMarket', () {
      test('aggregates institutional net by market and date', () async {
        await db.insertInstitutionalData([
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: today,
            foreignNet: const Value(100.0),
            investmentTrustNet: const Value(50.0),
            dealerNet: const Value(-30.0),
          ),
          DailyInstitutionalCompanion.insert(
            symbol: '2317',
            date: today,
            foreignNet: const Value(200.0),
            investmentTrustNet: const Value(-10.0),
            dealerNet: const Value(20.0),
          ),
        ]);

        final result = await db.getRecentInstitutionalDailyByMarket(today);

        final twse = result['TWSE']!;
        expect(twse.length, 1);
        // Aggregated: foreign=300, trust=40, dealer=-10
        expect(twse.first.foreignNet, 300.0);
        expect(twse.first.trustNet, 40.0);
        expect(twse.first.dealerNet, -10.0);
      });

      test('returns multiple days sorted descending', () async {
        final yesterday = today.subtract(const Duration(days: 1));
        await db.insertInstitutionalData([
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: today,
            foreignNet: const Value(100.0),
          ),
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: yesterday,
            foreignNet: const Value(-50.0),
          ),
        ]);

        final result = await db.getRecentInstitutionalDailyByMarket(today);

        final twse = result['TWSE']!;
        expect(twse.length, 2);
        expect(twse.first.date, today);
        expect(twse.last.date, yesterday);
      });

      test('respects days limit', () async {
        for (var i = 0; i < 5; i++) {
          await db.insertInstitutionalData([
            DailyInstitutionalCompanion.insert(
              symbol: '2330',
              date: today.subtract(Duration(days: i)),
              foreignNet: Value(100.0 - i * 10),
            ),
          ]);
        }

        final result = await db.getRecentInstitutionalDailyByMarket(
          today,
          days: 3,
        );

        expect(result['TWSE']!.length, 3);
      });
    });

    // ── getLatestMarginTradingTotalsByMarket ────────────────

    group('getLatestMarginTradingTotalsByMarket', () {
      test('finds latest date per market independently', () async {
        // TWSE on today
        await db.insertMarginTradingData([
          MarginTradingCompanion.insert(
            symbol: '2330',
            date: today,
            marginBuy: const Value(500.0),
            marginSell: const Value(300.0),
            marginBalance: const Value(10000.0),
            shortSell: const Value(100.0),
            shortBuy: const Value(50.0),
            shortBalance: const Value(2000.0),
          ),
        ]);

        // TPEx on yesterday (simulating T+1 delay)
        final yesterday = today.subtract(const Duration(days: 1));
        await db.insertMarginTradingData([
          MarginTradingCompanion.insert(
            symbol: '6488',
            date: yesterday,
            marginBuy: const Value(200.0),
            marginSell: const Value(100.0),
            marginBalance: const Value(5000.0),
            shortSell: const Value(50.0),
            shortBuy: const Value(20.0),
            shortBalance: const Value(1000.0),
          ),
        ]);

        final result = await db.getLatestMarginTradingTotalsByMarket();

        expect(result.containsKey('TWSE'), true);
        expect(result.containsKey('TPEx'), true);

        expect(result['TWSE']?['marginBalance'], 10000.0);
        // marginChange = buy - sell = 500-300 = 200
        expect(result['TWSE']?['marginChange'], 200.0);
        expect(result['TWSE']?['shortBalance'], 2000.0);
        // shortChange = sell - buy = 100-50 = 50
        expect(result['TWSE']?['shortChange'], 50.0);

        expect(result['TPEx']?['marginBalance'], 5000.0);
        expect(result['TPEx']?['marginChange'], 100.0);
        expect(result['TPEx']?['shortBalance'], 1000.0);
        expect(result['TPEx']?['shortChange'], 30.0);
      });

      test('aggregates multiple stocks on same market date', () async {
        await db.insertMarginTradingData([
          MarginTradingCompanion.insert(
            symbol: '2330',
            date: today,
            marginBalance: const Value(10000.0),
            marginBuy: const Value(500.0),
            marginSell: const Value(300.0),
            shortBalance: const Value(2000.0),
            shortSell: const Value(100.0),
            shortBuy: const Value(50.0),
          ),
          MarginTradingCompanion.insert(
            symbol: '2317',
            date: today,
            marginBalance: const Value(3000.0),
            marginBuy: const Value(100.0),
            marginSell: const Value(80.0),
            shortBalance: const Value(500.0),
            shortSell: const Value(30.0),
            shortBuy: const Value(10.0),
          ),
        ]);

        final result = await db.getLatestMarginTradingTotalsByMarket();

        // 10000 + 3000 = 13000
        expect(result['TWSE']?['marginBalance'], 13000.0);
        // (500-300) + (100-80) = 220
        expect(result['TWSE']?['marginChange'], 220.0);
      });

      test('returns empty map when no data', () async {
        final result = await db.getLatestMarginTradingTotalsByMarket();

        expect(result, isEmpty);
      });
    });

    // ── getIndustrySummaryByMarket ──────────────────────────

    group('getIndustrySummaryByMarket', () {
      Future<void> insertStocksWithIndustry() async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: const Value('其他電子業'),
          ),
          StockMasterCompanion.insert(
            symbol: '6488',
            name: '環球晶',
            market: 'TPEx',
            industry: const Value('半導體業'),
          ),
        ]);
      }

      test('calculates avg change and advance/decline per industry', () async {
        await insertStocksWithIndustry();

        // 2330 半導體業: close=110, priceChange=10 → 10/(110-10)*100 = 10%
        // 2317 其他電子業: close=99, priceChange=-9 → -9/(99+9)*100 ≈ -8.33%
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(10.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(99.0),
            priceChange: const Value(-9.0),
          ),
        ]);

        final result = await db.getIndustrySummaryByMarket(today, 'TWSE');

        expect(result.length, 2);
        // Sorted by avgChangePct DESC → 半導體業 first
        expect(result.first['industry'], '半導體業');
        expect(result.first['advance'], 1);
        expect(result.first['decline'], 0);
        expect(result.first['stockCount'], 1);

        expect(result.last['industry'], '其他電子業');
        expect(result.last['advance'], 0);
        expect(result.last['decline'], 1);
      });

      test('filters by market', () async {
        await insertStocksWithIndustry();

        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(10.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(200.0),
            priceChange: const Value(5.0),
          ),
        ]);

        final twse = await db.getIndustrySummaryByMarket(today, 'TWSE');
        final tpex = await db.getIndustrySummaryByMarket(today, 'TPEx');

        expect(twse.length, 1);
        expect(twse.first['industry'], '半導體業');

        expect(tpex.length, 1);
        expect(tpex.first['industry'], '半導體業');
      });

      test('excludes stocks with null industry', () async {
        // insertTestStocks() has no industry set
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(50.0),
            priceChange: const Value(1.0),
          ),
        ]);

        final result = await db.getIndustrySummaryByMarket(today, 'TWSE');

        expect(result, isEmpty);
      });

      test('returns empty list when no data for date', () async {
        await insertStocksWithIndustry();
        final result = await db.getIndustrySummaryByMarket(today, 'TWSE');

        expect(result, isEmpty);
      });
    });
  });
}
