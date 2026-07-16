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

    group('getTradeableUniverseCount', () {
      test('只計入過流動性門檻（量≥100萬 且 成交額≥3000萬）的股', () async {
        await db.insertPrices([
          // PASS：量 200萬、成交額 2 億
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(2000000.0),
          ),
          // FAIL：量 50萬 < 100萬
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(100.0),
            volume: const Value(500000.0),
          ),
          // FAIL：成交額 10×150萬 = 1500萬 < 3000萬
          DailyPriceCompanion.insert(
            symbol: '6488',
            date: today,
            close: const Value(10.0),
            volume: const Value(1500000.0),
          ),
          // PASS（邊界）：量剛好 100萬、成交額 2 億
          DailyPriceCompanion.insert(
            symbol: '3293',
            date: today,
            close: const Value(200.0),
            volume: const Value(1000000.0),
          ),
        ]);

        expect(await db.getTradeableUniverseCount(today), 2);
      });

      test('null volume 或 close 不計入', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(symbol: '2330', date: today), // 無量/價
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(100.0), // 有價無量
          ),
        ]);
        expect(await db.getTradeableUniverseCount(today), 0);
      });

      test('無資料日期回 0', () async {
        expect(await db.getTradeableUniverseCount(today), 0);
      });
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

        expect(result['TWSE']?.advance, 1);
        expect(result['TWSE']?.decline, 1);
        expect(result['TWSE']?.unchanged, 0);

        expect(result['TPEx']?.advance, 1);
        expect(result['TPEx']?.decline, 0);
        expect(result['TPEx']?.unchanged, 1);
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

        expect(result['TWSE']?.advance, 1);
        expect(result['TWSE']?.decline, 0);
        expect(result['TWSE']?.unchanged, 0);
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

        expect(result.advance, 2);
        expect(result.decline, 0);
        expect(result.unchanged, 0);
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
        expect(result['TWSE']?.totalTurnover, 2000000.0);
        // TPEx: 600*5000 = 3000000
        expect(result['TPEx']?.totalTurnover, 3000000.0);
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

        expect(result['TWSE']?.totalTurnover, 1000000.0);
      });

      test('returns empty map for date with no data', () async {
        final result = await db.getTurnoverSummaryByMarket(today);

        expect(result, isEmpty);
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

        expect(result['TWSE']?.limitUp, 1);
        expect(result['TWSE']?.limitDown, 0);
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

        expect(result['TWSE']?.limitDown, 1);
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

        final result = await db.getRecentTurnoverByMarket(
          today,
          days: 2,
          minCoverage: 1,
        );
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

        final result = await db.getRecentTurnoverByMarket(
          today,
          minCoverage: 1,
        );

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

        final result = await db.getRecentTurnoverByMarket(
          today,
          days: 3,
          minCoverage: 1,
        );

        // Should have at most 3+1 = 4 entries
        expect(result['TWSE']!.length, 4);
      });

      test('excludes half-coverage days below minCoverage threshold', () async {
        // 完整日：2 檔報價（達門檻 2）
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            volume: const Value(1000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
            volume: const Value(500.0),
          ),
        ]);
        // 半套日：僅 1 檔（模擬只同步候選子集，未達門檻）
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(100.0),
            volume: const Value(1000.0),
          ),
        ]);

        final result = await db.getRecentTurnoverByMarket(
          today,
          days: 5,
          minCoverage: 2,
        );

        // 半套日（1 檔 < 門檻 2）被濾除，只剩完整日
        expect(result['TWSE']!.length, 1, reason: '半套日應被濾除');
        expect(result['TWSE']!.first.date, today);
      });
    });

    // ── getRecentAdvanceDeclineByMarket ────────────────────

    group('getRecentAdvanceDeclineByMarket', () {
      test('aggregates advance/decline per market, date descending', () async {
        for (var i = 0; i < 3; i++) {
          final d = today.subtract(Duration(days: i));
          await db.insertPrices([
            DailyPriceCompanion.insert(
              symbol: '2330',
              date: d,
              close: const Value(100.0),
              priceChange: const Value(1.0), // advance
            ),
            DailyPriceCompanion.insert(
              symbol: '2317',
              date: d,
              close: const Value(50.0),
              priceChange: const Value(-1.0), // decline
            ),
          ]);
        }

        final result = await db.getRecentAdvanceDeclineByMarket(
          today,
          days: 3,
          minCoverage: 1,
        );
        final twse = result['TWSE']!;

        // 本方法保留最多 days 筆（與 turnover 的 days+1 不同，刻意不改動既有
        // sparkline 長度語意）
        expect(twse.length, 3);
        expect(twse.first.date, today);
        expect(twse.first.advance, 1);
        expect(twse.first.decline, 1);
      });

      test('excludes half-coverage days below minCoverage threshold', () async {
        // 完整日：2 檔報價（達門檻 2）
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(100.0),
            priceChange: const Value(1.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
            priceChange: const Value(-1.0),
          ),
        ]);
        // 半套日：僅 1 檔（模擬只同步候選子集，未達門檻）
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(100.0),
            priceChange: const Value(1.0),
          ),
        ]);

        final result = await db.getRecentAdvanceDeclineByMarket(
          today,
          days: 5,
          minCoverage: 2,
        );

        // 半套日（1 檔 < 門檻 2）被濾除，只剩完整日
        expect(result['TWSE']!.length, 1, reason: '半套日應被濾除');
        expect(result['TWSE']!.first.date, today);
      });
    });

    // ── getNewHighLowCountsByMarket ────────────────────────

    group('getNewHighLowCountsByMarket', () {
      /// 插入一檔個股的多日收盤（最新日為 [today]，往前回溯）
      Future<void> insertCloses(String symbol, List<double> closesDesc) async {
        // closesDesc[0] = 今日，closesDesc[1] = 昨日 ...
        final rows = <DailyPriceCompanion>[];
        for (var i = 0; i < closesDesc.length; i++) {
          rows.add(
            DailyPriceCompanion.insert(
              symbol: symbol,
              date: today.subtract(Duration(days: i)),
              close: Value(closesDesc[i]),
            ),
          );
        }
        await db.insertPrices(rows);
      }

      test('counts new highs and new lows per market', () async {
        // lookbackDays=3 → 窗口 = 今日 + 前 2 日（CURRENT ROW AND 2 FOLLOWING）
        // 2330 (TWSE) 今日 120 = 窗口 [120,110,100] 最高 → new high
        await insertCloses('2330', [120, 110, 100]);
        // 2317 (TWSE) 今日 90 = 窗口 [90,100,110] 最低 → new low
        await insertCloses('2317', [90, 100, 110]);
        // 6488 (TPEx) 今日 105 = 窗口 [105,100,110] 介於中間 → 既非高也非低
        await insertCloses('6488', [105, 100, 110]);
        // 3293 (TPEx) 今日 130 = 窗口 [130,120,110] 最高 → new high
        await insertCloses('3293', [130, 120, 110]);

        // minHistoryDays=1：薄歷史 fixture（各 3 列）不被歷史門檻濾除
        final result = await db.getNewHighLowCountsByMarket(
          today,
          lookbackDays: 3,
          minHistoryDays: 1,
        );

        // TWSE: 1 high (2330), 1 low (2317)
        expect(result['TWSE']?.newHighs, 1);
        expect(result['TWSE']?.newLows, 1);
        // TPEx: 1 high (3293), 0 low（6488 在區間內）
        expect(result['TPEx']?.newHighs, 1);
        expect(result['TPEx']?.newLows, 0);
      });

      test('today equal to window max counts as new high (>=)', () async {
        // 今日 100 = 前一日 100（持平於窗口最高）→ close >= hi 成立
        await insertCloses('2330', [100, 100, 90]);

        final result = await db.getNewHighLowCountsByMarket(
          today,
          lookbackDays: 3,
          minHistoryDays: 1,
        );

        expect(result['TWSE']?.newHighs, 1);
        // 100 也 >= 窗口最低嗎？窗口 [100,100,90] 最低 90，100 != 90 → 非新低
        expect(result['TWSE']?.newLows, 0);
      });

      test('excludes thin-history stocks below minHistoryDays', () async {
        // 薄歷史個股（5 列）今日創「新低」，但歷史不足 → 應被排除
        // 12110 是降序：今日 12 < 窗口最低嗎？窗口取今日 + 前 lookbackDays-1
        // 列，今日 12 為最低 → 否則會被認列為 new low。
        await insertCloses('2317', [12, 13, 14, 15, 16]); // TWSE，僅 5 列
        // 完整歷史個股（12 列）今日創新高 → 應被計入
        await insertCloses('2330', [
          130,
          120,
          118,
          116,
          114,
          112,
          110,
          108,
          106,
          104,
          102,
          100,
        ]); // TWSE，12 列

        // lookbackDays=12 涵蓋整段歷史；minHistoryDays=10 → 5 列薄股被濾除、
        // 12 列完整股保留
        final result = await db.getNewHighLowCountsByMarket(
          today,
          lookbackDays: 12,
          minHistoryDays: 10,
        );

        // 2330 (12 列) 今日 130 = 窗口最高 → 計入 new high
        expect(result['TWSE']?.newHighs, 1, reason: '完整歷史創新高個股應計入');
        // 2317 (5 列) 今日 12 = 窗口最低，但歷史 < 10 → 不應被當作 new low
        expect(result['TWSE']?.newLows, 0, reason: '薄歷史個股不應被認列創新低');
      });

      test('excludes rows with null close', () async {
        await db.insertPrices([
          DailyPriceCompanion.insert(symbol: '2330', date: today),
        ]);

        final result = await db.getNewHighLowCountsByMarket(
          today,
          lookbackDays: 3,
          minHistoryDays: 1,
        );

        expect(result, isEmpty);
      });

      test('returns empty map when no data', () async {
        final result = await db.getNewHighLowCountsByMarket(
          today,
          lookbackDays: 3,
          minHistoryDays: 1,
        );

        expect(result, isEmpty);
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
        // dealerSelfNet 未設 → SUM(NULL) 回 NULL（不 COALESCE，供 streak 隱藏判斷）
        expect(twse.first.dealerSelfNet, isNull);
      });

      test(
        'aggregates dealerSelfNet when present (nullable, no COALESCE)',
        () async {
          await db.insertInstitutionalData([
            DailyInstitutionalCompanion.insert(
              symbol: '2330',
              date: today,
              dealerNet: const Value(100.0),
              dealerSelfNet: const Value(40.0),
            ),
            DailyInstitutionalCompanion.insert(
              symbol: '2317',
              date: today,
              dealerNet: const Value(20.0),
              dealerSelfNet: const Value(-15.0),
            ),
          ]);

          final result = await db.getRecentInstitutionalDailyByMarket(today);

          final twse = result['TWSE']!;
          // Aggregated dealerSelfNet = 40 + (-15) = 25
          expect(twse.first.dealerSelfNet, 25.0);
        },
      );

      test(
        'dealerSelfNet stays null when all rows for the day are null',
        () async {
          // 既有歷史 row：dealer_self_net 全 NULL（重新同步前）
          await db.insertInstitutionalData([
            DailyInstitutionalCompanion.insert(
              symbol: '2330',
              date: today,
              dealerNet: const Value(100.0),
            ),
            DailyInstitutionalCompanion.insert(
              symbol: '2317',
              date: today,
              dealerNet: const Value(50.0),
            ),
          ]);

          final result = await db.getRecentInstitutionalDailyByMarket(today);

          // SUM(NULL, NULL) = NULL（非 0）→ 上層判定該日無自行買賣資料
          expect(result['TWSE']!.first.dealerSelfNet, isNull);
          // 其他欄位仍正常 COALESCE 為數值
          expect(result['TWSE']!.first.dealerNet, 150.0);
        },
      );

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

        expect(result['TWSE']?.marginBalance, 10000.0);
        // marginChange = buy - sell = 500-300 = 200
        expect(result['TWSE']?.marginChange, 200.0);
        expect(result['TWSE']?.shortBalance, 2000.0);
        // shortChange = sell - buy = 100-50 = 50
        expect(result['TWSE']?.shortChange, 50.0);

        expect(result['TPEx']?.marginBalance, 5000.0);
        expect(result['TPEx']?.marginChange, 100.0);
        expect(result['TPEx']?.shortBalance, 1000.0);
        expect(result['TPEx']?.shortChange, 30.0);
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
        expect(result['TWSE']?.marginBalance, 13000.0);
        // (500-300) + (100-80) = 220
        expect(result['TWSE']?.marginChange, 220.0);
      });

      test('returns empty map when no data', () async {
        final result = await db.getLatestMarginTradingTotalsByMarket();

        expect(result, isEmpty);
      });

      test('dataDate 還原本地曆日——不可讓 .day 讀到 UTC 曆日（落後一天迴歸測試）', () async {
        // Bug: Today 頁融資融券區塊日期標示落後 DB 實際最新資料一天
        // （DB 最新為 7/15，畫面顯示 7/14）。
        //
        // 直接用 raw SQL 寫入帶明確 UTC offset 的 ISO-8601 文字，模擬正式環境
        // 裝置在 Asia/Taipei（+08:00）寫入 margin_trading.date 的實際格式
        // （drift store_date_time_values_as_text 對「本地」DateTime 一律附加
        // 執行當下的 UTC offset）。用字面 offset 而非仰賴執行機器目前時區，
        // 確保本測試在任何時區的 CI runner 上都能穩定重現（GitHub Actions
        // ubuntu-latest 預設 UTC，offset=0 時此 bug 不會現形）。
        const rawDateText = '2026-07-15T00:00:00.000 +08:00';
        await db.customStatement(
          'INSERT INTO margin_trading '
          '(symbol, date, margin_buy, margin_sell, margin_balance, '
          'short_sell, short_buy, short_balance) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          ['2330', rawDateText, 500.0, 300.0, 10000.0, 100.0, 50.0, 2000.0],
        );

        final result = await db.getLatestMarginTradingTotalsByMarket();
        final dataDate = result['TWSE']?.dataDate;

        expect(dataDate, isNotNull);
        // Root cause 斷言：DateTime.parse 對帶明確 offset 的字串一律回傳
        // isUtc=true（純字串運算、與執行機器時區無關——見 drift
        // SqlTypes._readDateTime 原始碼註解）。Drift 自己的型別化讀取路徑
        // （QueryRow.read<DateTime>）在這種情況一定會接 .toLocal()
        // 轉正；若這裡讀出 isUtc=true，代表繞過了該轉換，.day/.month
        // 會讀到 UTC 曆日而非本地曆日。
        expect(
          dataDate!.isUtc,
          isFalse,
          reason:
              '應如 QueryRow.read<DateTime>（drift 內建型別化路徑）一樣 '
              '.toLocal() 轉換，否則 .day 會讀到 UTC 曆日、比本地曆日落後一天',
        );
        // 與 drift 官方型別化 read 路徑（getLatestDataDate 等既有正確用法）
        // 同公式驗證——在同一台機器、同一時刻求值，不受執行環境時區影響。
        expect(dataDate, DateTime.parse(rawDateText).toLocal());
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

        // minStockCount=1：fixture 每產業僅 1 檔，不被最低個股數門檻濾除
        final result = await db.getIndustrySummaryByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result.length, 2);
        // Sorted by avgChangePct DESC → 半導體業 first
        expect(result.first.industry, '半導體業');
        expect(result.first.advance, 1);
        expect(result.first.decline, 0);
        expect(result.first.stockCount, 1);

        expect(result.last.industry, '其他電子業');
        expect(result.last.advance, 0);
        expect(result.last.decline, 1);
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

        final twse = await db.getIndustrySummaryByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );
        final tpex = await db.getIndustrySummaryByMarket(
          today,
          'TPEx',
          minStockCount: 1,
        );

        expect(twse.length, 1);
        expect(twse.first.industry, '半導體業');

        expect(tpex.length, 1);
        expect(tpex.first.industry, '半導體業');
      });

      test('excludes industries below minStockCount', () async {
        // 半導體業：3 檔（達門檻）；其他電子業：1 檔（單股，未達門檻 3）
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2454',
            name: '聯發科',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2308',
            name: '台達電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: const Value('其他電子業'),
          ),
        ]);
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(2.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2454',
            date: today,
            close: const Value(900.0),
            priceChange: const Value(10.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2308',
            date: today,
            close: const Value(300.0),
            priceChange: const Value(3.0),
          ),
          // 單股產業，今日近漲停 → 若無門檻會竄上排行第一
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(110.0),
            priceChange: const Value(10.0),
          ),
        ]);

        // 預設 minStockCount = kIndustryMinStockCount (3)
        final result = await db.getIndustrySummaryByMarket(today, 'TWSE');

        // 單股「其他電子業」被排除，只剩 3 檔的半導體業
        expect(result.length, 1, reason: '單股產業應被最低個股數門檻排除');
        expect(result.first.industry, '半導體業');
        expect(result.first.stockCount, 3);
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

        final result = await db.getIndustrySummaryByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result, isEmpty);
      });

      test('returns empty list when no data for date', () async {
        await insertStocksWithIndustry();
        final result = await db.getIndustrySummaryByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result, isEmpty);
      });
    });

    // ── getIndustryMomentum5dByMarket ───────────────────────

    group('getIndustryMomentum5dByMarket', () {
      /// 產生 7 筆完整歷史（rn=1..7）：today 為最新（rn=1），
      /// today-5 為第 6 筆最近收盤（rn=6），中間日期以 [fillerClose] 填充
      /// （不影響 5 日動能計算，僅需存在以讓 ROW_NUMBER 正確編號）。
      List<DailyPriceCompanion> sevenDayHistory(
        String symbol,
        DateTime asOf, {
        required double todayClose,
        required double day5Close,
        double fillerClose = 50.0,
      }) {
        return [
          DailyPriceCompanion.insert(
            symbol: symbol,
            date: asOf,
            close: Value(todayClose),
          ),
          for (var i = 1; i <= 4; i++)
            DailyPriceCompanion.insert(
              symbol: symbol,
              date: asOf.subtract(Duration(days: i)),
              close: Value(fillerClose),
            ),
          DailyPriceCompanion.insert(
            symbol: symbol,
            date: asOf.subtract(const Duration(days: 5)),
            close: Value(day5Close),
          ),
          DailyPriceCompanion.insert(
            symbol: symbol,
            date: asOf.subtract(const Duration(days: 6)),
            close: Value(fillerClose),
          ),
        ];
      }

      test('以第1筆(rn=1) vs 第6筆(rn=6) 最近收盤計算 5 日報酬 (d0-d5)/d5', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
        ]);
        // rn=1 close=110、rn=6 close=100 → (110-100)/100*100 = 10.0%
        await db.insertPrices(
          sevenDayHistory('2330', today, todayClose: 110, day5Close: 100),
        );

        final result = await db.getIndustryMomentum5dByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result['半導體業'], closeTo(10.0, 0.001));
      });

      test('依產業分組計算等權平均（多檔股票）', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2454',
            name: '聯發科',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
        ]);
        await db.insertPrices([
          // +10%
          ...sevenDayHistory('2330', today, todayClose: 110, day5Close: 100),
          // -5%
          ...sevenDayHistory('2454', today, todayClose: 95, day5Close: 100),
          // +2%
          ...sevenDayHistory('2317', today, todayClose: 102, day5Close: 100),
        ]);

        // 預設 minStockCount = kIndustryMinStockCount(3)：3 檔恰好達標
        final result = await db.getIndustryMomentum5dByMarket(today, 'TWSE');

        // (10.0 + -5.0 + 2.0) / 3 = 2.3333...
        expect(result['半導體業'], closeTo(7.0 / 3, 0.001));
      });

      test('排除歷史不足 6 筆的股票，不拉扯產業平均、也不出錯', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2454',
            name: '聯發科',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
        ]);
        await db.insertPrices([
          // +10%
          ...sevenDayHistory('2330', today, todayClose: 110, day5Close: 100),
          // -10%（恰與 2330 抵銷 → 平均應為 0.0，若 2317 誤入會偏離此值）
          ...sevenDayHistory('2454', today, todayClose: 90, day5Close: 100),
          // 2317 僅 4 筆歷史（無 rn=6），應被排除
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(999),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(999),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today.subtract(const Duration(days: 2)),
            close: const Value(999),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today.subtract(const Duration(days: 3)),
            close: const Value(999),
          ),
        ]);

        final result = await db.getIndustryMomentum5dByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result['半導體業'], closeTo(0.0, 0.001));
      });

      test('成分股全數歷史不足時，該產業不回傳', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2308',
            name: '台達電',
            market: 'TWSE',
            industry: const Value('其他電子業'),
          ),
        ]);
        // 僅 3 筆歷史，無 rn=6
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2308',
            date: today,
            close: const Value(300),
          ),
          DailyPriceCompanion.insert(
            symbol: '2308',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(299),
          ),
          DailyPriceCompanion.insert(
            symbol: '2308',
            date: today.subtract(const Duration(days: 2)),
            close: const Value(298),
          ),
        ]);

        final result = await db.getIndustryMomentum5dByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result.containsKey('其他電子業'), isFalse);
      });

      test('套用 minStockCount 門檻（預設 kIndustryMinStockCount = 3）', () async {
        await db.upsertStocks([
          // 半導體業：3 檔皆有完整歷史 → 達門檻
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2454',
            name: '聯發科',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
          // 其他電子業：僅 2 檔有完整歷史 → 未達門檻
          StockMasterCompanion.insert(
            symbol: '2308',
            name: '台達電',
            market: 'TWSE',
            industry: const Value('其他電子業'),
          ),
          StockMasterCompanion.insert(
            symbol: '2311',
            name: '日月光',
            market: 'TWSE',
            industry: const Value('其他電子業'),
          ),
        ]);
        await db.insertPrices([
          ...sevenDayHistory('2330', today, todayClose: 110, day5Close: 100),
          ...sevenDayHistory('2454', today, todayClose: 108, day5Close: 100),
          ...sevenDayHistory('2317', today, todayClose: 105, day5Close: 100),
          ...sevenDayHistory('2308', today, todayClose: 95, day5Close: 100),
          ...sevenDayHistory('2311', today, todayClose: 90, day5Close: 100),
        ]);

        final result = await db.getIndustryMomentum5dByMarket(today, 'TWSE');

        expect(result.containsKey('半導體業'), isTrue, reason: '3 檔達門檻應納入');
        expect(result.containsKey('其他電子業'), isFalse, reason: '2 檔未達門檻應排除');
      });

      test('日期下界為 date−21 天（含）；剛好超出下界的股票視為歷史不足而排除', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: 'BOUND_IN',
            name: '邊界內',
            market: 'TWSE',
            industry: const Value('BOUND_IN_IND'),
          ),
          StockMasterCompanion.insert(
            symbol: 'BOUND_OUT',
            name: '邊界外',
            market: 'TWSE',
            industry: const Value('BOUND_OUT_IND'),
          ),
        ]);

        // BOUND_IN：rn=6 落在 today-21（下界，含），應納入
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: 'BOUND_IN',
            date: today,
            close: const Value(110),
          ),
          for (var i = 1; i <= 4; i++)
            DailyPriceCompanion.insert(
              symbol: 'BOUND_IN',
              date: today.subtract(Duration(days: i)),
              close: const Value(50),
            ),
          DailyPriceCompanion.insert(
            symbol: 'BOUND_IN',
            date: today.subtract(const Duration(days: 21)),
            close: const Value(100),
          ),
        ]);

        // BOUND_OUT：rn=6 落在 today-22（超出下界一天），視窗內僅 5 筆 → 排除
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: 'BOUND_OUT',
            date: today,
            close: const Value(110),
          ),
          for (var i = 1; i <= 4; i++)
            DailyPriceCompanion.insert(
              symbol: 'BOUND_OUT',
              date: today.subtract(Duration(days: i)),
              close: const Value(50),
            ),
          DailyPriceCompanion.insert(
            symbol: 'BOUND_OUT',
            date: today.subtract(const Duration(days: 22)),
            close: const Value(100),
          ),
        ]);

        final result = await db.getIndustryMomentum5dByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(
          result['BOUND_IN_IND'],
          closeTo(10.0, 0.001),
          reason: 'today-21 恰為下界（含），應納入計算',
        );
        expect(
          result.containsKey('BOUND_OUT_IND'),
          isFalse,
          reason: 'today-22 超出下界，視窗內僅剩 5 筆歷史應視為不足',
        );
      });

      test('不含未來資料：查詢日之後的資料不會滲入 rn=1（上界排除）', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: const Value('半導體業'),
          ),
        ]);
        await db.insertPrices([
          // 正常 6 筆歷史：today(110) ~ today-5(100) → 10.0%
          ...sevenDayHistory('2330', today, todayClose: 110, day5Close: 100),
          // 「未來」資料：若上界未正確排除，會被誤當 rn=1 大幅偏離預期值
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.add(const Duration(days: 1)),
            close: const Value(99999),
          ),
        ]);

        final result = await db.getIndustryMomentum5dByMarket(
          today,
          'TWSE',
          minStockCount: 1,
        );

        expect(result['半導體業'], closeTo(10.0, 0.001), reason: '查詢日之後的資料不應滲入計算');
      });

      test('回傳空 map 當無資料', () async {
        final result = await db.getIndustryMomentum5dByMarket(today, 'TWSE');
        expect(result, isEmpty);
      });
    });
  });
}
