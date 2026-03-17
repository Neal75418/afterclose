/// Integration test: 推薦清單從 DB 到 Provider State 的完整流程
///
/// 驗證：DB 資料 → AnalysisRepository → TodayNotifier.loadData()
/// → TodayState.recommendations 的端到端資料流程。
/// 使用真實 in-memory SQLite 資料庫 + 真實 Repository 邏輯。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';

// =============================================================================
// Mocks（僅 mock 無法使用真實實例的依賴）
// =============================================================================

class MockUpdateService extends Mock implements UpdateService {}

class MockAppClock extends Mock implements AppClock {}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockAppClock mockClock;

  final testDate = DateTime(2026, 3, 10);

  /// 預填充資料庫：股票 + 價格 + 分析 + 推薦
  Future<void> seedDatabase() async {
    // 股票主檔
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
    ]);

    // 價格歷史（20 天）
    for (final symbol in ['2330', '2317']) {
      final prices = <DailyPriceCompanion>[];
      for (int i = 0; i < 20; i++) {
        final date = testDate.subtract(Duration(days: 20 - i));
        prices.add(
          DailyPriceCompanion.insert(
            symbol: symbol,
            date: date,
            open: Value(500.0 + i),
            high: Value(510.0 + i),
            low: Value(490.0 + i),
            close: Value(505.0 + i),
            volume: Value(50000.0),
          ),
        );
      }
      await db.insertPrices(prices);
    }

    // 分析結果
    await db.insertAnalysis(
      DailyAnalysisCompanion.insert(
        symbol: '2330',
        date: testDate,
        trendState: 'UP',
        score: const Value(85.0),
      ),
    );
    await db.insertAnalysis(
      DailyAnalysisCompanion.insert(
        symbol: '2317',
        date: testDate,
        trendState: 'UP',
        score: const Value(72.0),
      ),
    );

    // 分析原因
    await db.insertReasons([
      DailyReasonCompanion.insert(
        symbol: '2330',
        date: testDate,
        rank: 1,
        reasonType: 'GOLDEN_CROSS',
        evidenceJson: '{}',
        ruleScore: const Value(25.0),
      ),
      DailyReasonCompanion.insert(
        symbol: '2317',
        date: testDate,
        rank: 1,
        reasonType: 'VOLUME_SPIKE',
        evidenceJson: '{}',
        ruleScore: const Value(22.0),
      ),
    ]);

    // 推薦清單
    await db.insertRecommendations([
      DailyRecommendationCompanion.insert(
        symbol: '2330',
        date: testDate,
        score: 85.0,
        rank: 1,
      ),
      DailyRecommendationCompanion.insert(
        symbol: '2317',
        date: testDate,
        score: 72.0,
        rank: 2,
      ),
    ]);

    // 更新執行記錄（傳入固定時間避免依賴真實系統時鐘）
    final runId = await db.createUpdateRun(testDate, 'running');
    await db.finishUpdateRun(runId, 'completed', now: testDate);
  }

  setUp(() async {
    db = AppDatabase.forTesting();
    mockClock = MockAppClock();
    when(() => mockClock.now()).thenReturn(testDate);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appClockProvider.overrideWithValue(mockClock),
        cachedDbProvider.overrideWithValue(
          CachedDatabaseAccessor(
            db: db,
            cache: BatchQueryCacheManager(
              maxSize: 50,
              ttl: const Duration(seconds: 30),
            ),
          ),
        ),
        analysisRepositoryProvider.overrideWithValue(
          AnalysisRepository(database: db, clock: mockClock),
        ),
        dataSyncServiceProvider.overrideWithValue(const DataSyncService()),
        updateServiceProvider.overrideWithValue(MockUpdateService()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Recommendation Flow Integration', () {
    test(
      'TodayNotifier.loadData() populates recommendations from DB',
      () async {
        await seedDatabase();

        // 呼叫 loadData
        final notifier = container.read(todayProvider.notifier);
        await notifier.loadData();

        // 驗證 state
        final state = container.read(todayProvider);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        expect(state.recommendations.length, 2);

        // 驗證第一名推薦
        final top = state.recommendations.first;
        expect(top.symbol, '2330');
        expect(top.stockName, '台積電');
        expect(top.market, 'TWSE');
        expect(top.score, 85.0);
        expect(top.rank, 1);
        expect(top.latestClose, isNotNull);
        expect(top.reasons.length, 1);
        expect(top.reasons.first.reasonType, 'GOLDEN_CROSS');
        expect(top.trendState, 'UP');

        // 驗證第二名推薦
        final second = state.recommendations.last;
        expect(second.symbol, '2317');
        expect(second.stockName, '鴻海');
        expect(second.score, 72.0);
        expect(second.rank, 2);
      },
    );

    test(
      'TodayNotifier.loadData() returns empty when no recommendations',
      () async {
        // 只寫入股票主檔，不寫入推薦
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
          ),
        ]);

        final notifier = container.read(todayProvider.notifier);
        await notifier.loadData();

        final state = container.read(todayProvider);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        expect(state.recommendations, isEmpty);
      },
    );

    test('recommendation includes recent prices for sparkline', () async {
      await seedDatabase();

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      final state = container.read(todayProvider);
      final top = state.recommendations.first;

      // 應有最近價格資料供迷你走勢圖使用
      expect(top.recentPrices, isNotNull);
      expect(top.recentPrices!.length, greaterThan(0));
      expect(top.recentPrices!.length, lessThanOrEqualTo(30));
    });

    test('dataDate matches latest price date in DB', () async {
      await seedDatabase();

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      final state = container.read(todayProvider);
      // seedDatabase 寫入 20 天價格，最新一天 = testDate - 1
      final expectedDataDate = testDate.subtract(const Duration(days: 1));
      expect(state.dataDate, isNotNull);
      expect(state.dataDate!.year, expectedDataDate.year);
      expect(state.dataDate!.month, expectedDataDate.month);
      expect(state.dataDate!.day, expectedDataDate.day);
    });

    test('lastUpdate matches update run finishedAt', () async {
      await seedDatabase();

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      final state = container.read(todayProvider);
      expect(state.lastUpdate, isNotNull);
      // seedDatabase 中 finishUpdateRun(now: testDate)
      expect(state.lastUpdate!.year, testDate.year);
      expect(state.lastUpdate!.month, testDate.month);
      expect(state.lastUpdate!.day, testDate.day);
    });
  });
}
