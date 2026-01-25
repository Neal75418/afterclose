import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:afterclose/data/database/app_database.dart';

/// AppDatabase 單元測試
///
/// 測試 Drift SQLite 資料庫的 CRUD 操作，
/// 涵蓋 StockMaster、DailyPrice、Watchlist、Analysis、Recommendation 等資料表。

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to insert test stock master entries required by foreign keys
  Future<void> insertTestStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2454', name: '聯發科', market: 'TWSE'),
    ]);
  }

  group('AppDatabase', () {
    group('StockMaster Operations', () {
      test('should upsert and retrieve stock', () async {
        await db.upsertStock(
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
        );

        final stock = await db.getStock('2330');

        expect(stock, isNotNull);
        expect(stock!.symbol, '2330');
        expect(stock.name, '台積電');
        expect(stock.market, 'TWSE');
      });

      test('should return null for non-existent stock', () async {
        final stock = await db.getStock('9999');

        expect(stock, isNull);
      });

      test('should batch upsert stocks', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
          ),
        ]);

        final stocks = await db.getAllActiveStocks();

        expect(stocks.length, 2);
      });

      test('should get stocks batch', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
          ),
        ]);

        final result = await db.getStocksBatch(['2330', '2317', '9999']);

        expect(result.length, 2);
        expect(result['2330']?.name, '台積電');
        expect(result['2317']?.name, '鴻海');
        expect(result['9999'], isNull);
      });

      test('should search stocks by symbol or name', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
          ),
        ]);

        final bySymbol = await db.searchStocks('2330');
        expect(bySymbol.length, 1);
        expect(bySymbol.first.symbol, '2330');

        final byName = await db.searchStocks('積電');
        expect(byName.length, 1);
        expect(byName.first.symbol, '2330');
      });
    });

    group('DailyPrice Operations', () {
      setUp(() async {
        await insertTestStocks();
      });

      test('should insert and retrieve price history', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(100.0),
            volume: const Value(1000.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(105.0),
            volume: const Value(1500.0),
          ),
        ]);

        final history = await db.getPriceHistory(
          '2330',
          startDate: today.subtract(const Duration(days: 5)),
        );

        expect(history.length, 2);
        expect(history.first.close, 100.0);
        expect(history.last.close, 105.0);
      });

      test('should get latest price', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(100.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(105.0),
          ),
        ]);

        final latest = await db.getLatestPrice('2330');

        expect(latest, isNotNull);
        expect(latest!.close, 105.0);
      });

      test('should get latest prices batch', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(105.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
          ),
        ]);

        final result = await db.getLatestPricesBatch(['2330', '2317']);

        expect(result.length, 2);
        expect(result['2330']?.close, 105.0);
        expect(result['2317']?.close, 50.0);
      });

      test('should get price history batch', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 1)),
            close: const Value(100.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            close: const Value(105.0),
          ),
          DailyPriceCompanion.insert(
            symbol: '2317',
            date: today,
            close: const Value(50.0),
          ),
        ]);

        final result = await db.getPriceHistoryBatch([
          '2330',
          '2317',
        ], startDate: today.subtract(const Duration(days: 5)));

        expect(result['2330']?.length, 2);
        expect(result['2317']?.length, 1);
      });

      test('should handle price with null close and volume', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        // Insert price without close and volume (both optional)
        await db.insertPrices([
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: today,
            // close and volume are optional, using Value.absent()
          ),
        ]);

        final latest = await db.getLatestPrice('2330');

        expect(latest, isNotNull);
        expect(latest!.close, isNull);
        expect(latest.volume, isNull);
      });

      test('should handle empty batch queries', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        // Query with empty symbol list
        final result = await db.getLatestPricesBatch([]);

        expect(result, isEmpty);

        // Query history for non-existent symbols
        final historyResult = await db.getPriceHistoryBatch([
          '9999',
        ], startDate: today.subtract(const Duration(days: 5)));

        expect(historyResult['9999'], isNull);
      });
    });

    group('Watchlist Operations', () {
      setUp(() async {
        await insertTestStocks();
      });

      test('should add to watchlist', () async {
        await db.addToWatchlist('2330');

        final watchlist = await db.getWatchlist();

        expect(watchlist.length, 1);
        expect(watchlist.first.symbol, '2330');
      });

      test('should remove from watchlist', () async {
        await db.addToWatchlist('2330');
        await db.removeFromWatchlist('2330');

        final watchlist = await db.getWatchlist();

        expect(watchlist, isEmpty);
      });

      test('should check if in watchlist', () async {
        await db.addToWatchlist('2330');

        expect(await db.isInWatchlist('2330'), isTrue);
        expect(await db.isInWatchlist('2317'), isFalse);
      });

      test('should ignore duplicate watchlist entries', () async {
        await db.addToWatchlist('2330');
        await db.addToWatchlist('2330'); // Duplicate

        final watchlist = await db.getWatchlist();

        expect(watchlist.length, 1);
      });
    });

    group('Analysis Operations', () {
      setUp(() async {
        await insertTestStocks();
      });

      test('should insert and retrieve analysis', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );

        final analysis = await db.getAnalysis('2330', today);

        expect(analysis, isNotNull);
        expect(analysis!.trendState, 'UP');
        expect(analysis.score, 50.0);
      });

      test('should get analyses batch', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );

        final result = await db.getAnalysesBatch(['2330', '2317'], today);

        expect(result.length, 2);
        expect(result['2330']?.trendState, 'UP');
        expect(result['2317']?.trendState, 'DOWN');
      });

      test('should get analysis for date', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );

        final analyses = await db.getAnalysisForDate(today);

        expect(analyses.length, 2);
        // Sorted by score descending
        expect(analyses.first.symbol, '2330');
        expect(analyses.last.symbol, '2317');
      });
    });

    group('Reason Operations', () {
      setUp(() async {
        await insertTestStocks();
      });

      test('should insert and retrieve reasons', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'VOLUME_SPIKE',
            evidenceJson: '{}',
            ruleScore: const Value(18.0),
            rank: 1,
          ),
        ]);

        final reasons = await db.getReasons('2330', today);

        expect(reasons.length, 1);
        expect(reasons.first.reasonType, 'VOLUME_SPIKE');
        expect(reasons.first.ruleScore, 18.0);
      });

      test('should get reasons batch', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'VOLUME_SPIKE',
            evidenceJson: '{}',
            ruleScore: const Value(18.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2317',
            date: today,
            reasonType: 'PRICE_SPIKE',
            evidenceJson: '{}',
            ruleScore: const Value(15.0),
            rank: 1,
          ),
        ]);

        final result = await db.getReasonsBatch(['2330', '2317'], today);

        expect(result['2330']?.length, 1);
        expect(result['2317']?.length, 1);
        expect(result['2330']?.first.reasonType, 'VOLUME_SPIKE');
        expect(result['2317']?.first.reasonType, 'PRICE_SPIKE');
      });

      test('should replace reasons atomically', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        // Insert initial reasons
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'OLD_REASON',
            evidenceJson: '{}',
            ruleScore: const Value(10.0),
            rank: 1,
          ),
        ]);

        // Replace with new reasons
        await db.replaceReasons('2330', today, [
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'NEW_REASON',
            evidenceJson: '{}',
            ruleScore: const Value(20.0),
            rank: 1,
          ),
        ]);

        final reasons = await db.getReasons('2330', today);

        expect(reasons.length, 1);
        expect(reasons.first.reasonType, 'NEW_REASON');
      });
    });

    group('Recommendation Operations', () {
      setUp(() async {
        await insertTestStocks();
      });

      test('should insert and retrieve recommendations', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        // First create the stocks (foreign key requirement)
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
          ),
        ]);

        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2330',
            score: 50.0,
            rank: 1,
          ),
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2317',
            score: 40.0,
            rank: 2,
          ),
        ]);

        final recommendations = await db.getRecommendations(today);

        expect(recommendations.length, 2);
        expect(recommendations.first.symbol, '2330'); // Rank 1
        expect(recommendations.last.symbol, '2317'); // Rank 2
      });

      test('should check if symbol was recommended in range', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        // First create the stock (foreign key requirement)
        await db.upsertStock(
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
        );

        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: today.subtract(const Duration(days: 2)),
            symbol: '2330',
            score: 50.0,
            rank: 1,
          ),
        ]);

        final wasRecommended = await db.wasSymbolRecommendedInRange(
          '2330',
          startDate: today.subtract(const Duration(days: 5)),
          endDate: today,
        );

        expect(wasRecommended, isTrue);

        final wasNotRecommended = await db.wasSymbolRecommendedInRange(
          '2317',
          startDate: today.subtract(const Duration(days: 5)),
          endDate: today,
        );

        expect(wasNotRecommended, isFalse);
      });
    });

    group('Settings Operations', () {
      test('should set and get setting', () async {
        await db.setSetting('test_key', 'test_value');

        final value = await db.getSetting('test_key');

        expect(value, 'test_value');
      });

      test('should return null for non-existent setting', () async {
        final value = await db.getSetting('non_existent');

        expect(value, isNull);
      });

      test('should delete setting', () async {
        await db.setSetting('test_key', 'test_value');
        await db.deleteSetting('test_key');

        final value = await db.getSetting('test_key');

        expect(value, isNull);
      });

      test('should update existing setting', () async {
        await db.setSetting('test_key', 'old_value');
        await db.setSetting('test_key', 'new_value');

        final value = await db.getSetting('test_key');

        expect(value, 'new_value');
      });
    });

    group('Update Run Operations', () {
      test('should create and finish update run', () async {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        final id = await db.createUpdateRun(today, 'RUNNING');
        await db.finishUpdateRun(id, 'COMPLETED', message: 'Success');

        final latest = await db.getLatestUpdateRun();

        expect(latest, isNotNull);
        expect(latest!.status, 'COMPLETED');
        expect(latest.message, 'Success');
        expect(latest.finishedAt, isNotNull);
      });
    });
  });
}
