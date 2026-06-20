// Integration test: TodayNotifier.loadData() 編排狀態的端到端流程
//
// 驗證：DB 資料 → MarketDataRepository → TodayNotifier.loadData()
// → TodayState.dataDate / lastUpdate 的端到端編排流程。
//
// **2026-06-21 退役舊推薦系統 Step 3**：推薦清單已搬到
// modeRecommendationsProvider，loadData() 不再載入 daily_recommendation。
// 本檔案因此只覆蓋 loadData 的編排輸出（資料日期 / 最後更新時間）。
// 使用真實 in-memory SQLite 資料庫 + 真實 Repository 邏輯。
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

// ==========================================
// Mocks（僅 mock 無法使用真實實例的依賴）
// ==========================================

class MockUpdateService extends Mock implements UpdateService {}

class MockAppClock extends Mock implements AppClock {}

// ==========================================
// Tests
// ==========================================

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockAppClock mockClock;

  final testDate = DateTime(2026, 3, 10);

  /// 預填充資料庫：loadData 編排狀態所需的最小資料
  /// （價格歷史 → dataDate，更新執行記錄 → lastUpdate）
  Future<void> seedDatabase() async {
    // 股票主檔
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
    ]);

    // 價格歷史（20 天）— 決定 getLatestDataDate 的最新一天
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
            volume: const Value(50000.0),
          ),
        );
      }
      await db.insertPrices(prices);
    }

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

  group('loadData Orchestration Integration', () {
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
