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
  });
}
