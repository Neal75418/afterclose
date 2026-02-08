import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/domain/services/update/market_data_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTradingRepository extends Mock implements TradingRepository {}

class MockShareholdingRepository extends Mock
    implements ShareholdingRepository {}

class MockWarningRepository extends Mock implements WarningRepository {}

class MockInsiderRepository extends Mock implements InsiderRepository {}

void main() {
  late MockAppDatabase mockDb;
  late MockTradingRepository mockTradingRepo;
  late MockShareholdingRepository mockShareholdingRepo;
  late MockWarningRepository mockWarningRepo;
  late MockInsiderRepository mockInsiderRepo;
  late MarketDataUpdater updater;

  final testDate = DateTime(2025, 1, 15);

  /// 建立上櫃股票 master 資料
  StockMasterEntry createOtcStock(String symbol) {
    return StockMasterEntry(
      symbol: symbol,
      name: 'Test $symbol',
      market: 'TPEx',
      isActive: true,
      updatedAt: testDate,
    );
  }

  setUp(() {
    mockDb = MockAppDatabase();
    mockTradingRepo = MockTradingRepository();
    mockShareholdingRepo = MockShareholdingRepository();
    mockWarningRepo = MockWarningRepository();
    mockInsiderRepo = MockInsiderRepository();

    updater = MarketDataUpdater(
      database: mockDb,
      tradingRepository: mockTradingRepo,
      shareholdingRepository: mockShareholdingRepo,
      warningRepository: mockWarningRepo,
      insiderRepository: mockInsiderRepo,
    );
  });

  // ==========================================
  // syncOtcCandidatesMarketData — 回歸測試
  //
  // 驗證 P2 修正：區分 RateLimitException 與一般錯誤
  // 一般錯誤不應觸發 quotaExhausted 提前終止
  // ==========================================
  group('syncOtcCandidatesMarketData', () {
    /// 設定 DB 回傳指定的上櫃股票清單
    void setupOtcStocks(List<String> symbols) {
      when(
        () => mockDb.getStocksByMarket('TPEx'),
      ).thenAnswer((_) async => symbols.map(createOtcStock).toList());
    }

    /// 設定新鮮度檢查：預設無快取資料
    void setupFreshnessCheck({DateTime? latestDate}) {
      when(
        () => mockDb.getLatestDayTradingDate(),
      ).thenAnswer((_) async => latestDate);
    }

    /// 設定特定 symbol 的 shareholding 新鮮度
    void setupShareholdingFreshness(String symbol, {bool fresh = false}) {
      when(() => mockShareholdingRepo.getLatestShareholding(symbol)).thenAnswer(
        (_) async =>
            fresh ? ShareholdingEntry(symbol: symbol, date: testDate) : null,
      );
    }

    /// 設定 syncShareholding 成功
    void setupSyncSuccess(String symbol, {int count = 5}) {
      when(
        () => mockShareholdingRepo.syncShareholding(
          symbol,
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => count);
    }

    /// 設定 syncShareholding 拋出一般錯誤
    void setupSyncGenericError(String symbol) {
      when(
        () => mockShareholdingRepo.syncShareholding(
          symbol,
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const NetworkException('Connection timeout'));
    }

    /// 設定 syncShareholding 拋出 RateLimitException
    void setupSyncRateLimitError(String symbol) {
      when(
        () => mockShareholdingRepo.syncShareholding(
          symbol,
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException());
    }

    test('returns zero result when candidates list is empty', () async {
      final result = await updater.syncOtcCandidatesMarketData(
        candidates: [],
        date: testDate,
      );

      expect(result.dayTradingCount, equals(0));
      expect(result.shareholdingCount, equals(0));
    });

    test('syncs shareholding successfully for OTC candidates', () async {
      final candidates = ['6547', '8044'];
      setupOtcStocks(candidates);
      setupFreshnessCheck();

      for (final symbol in candidates) {
        setupShareholdingFreshness(symbol);
        setupSyncSuccess(symbol);
      }

      final result = await updater.syncOtcCandidatesMarketData(
        candidates: candidates,
        date: testDate,
      );

      expect(result.shareholdingCount, equals(2));
    });

    test('skips stocks with fresh shareholding data', () async {
      final candidates = ['6547', '8044'];
      setupOtcStocks(candidates);
      setupFreshnessCheck(latestDate: testDate);

      // 6547 已有新鮮資料，8044 沒有
      setupShareholdingFreshness('6547', fresh: true);
      setupShareholdingFreshness('8044');
      setupSyncSuccess('8044');

      final result = await updater.syncOtcCandidatesMarketData(
        candidates: candidates,
        date: testDate,
      );

      // 只有 8044 被同步
      expect(result.shareholdingCount, equals(1));
      verifyNever(
        () => mockShareholdingRepo.syncShareholding(
          '6547',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test(
      'regression: generic errors do not trigger quota exhaustion early stop',
      () async {
        // 3 檔上櫃股票，第 1 檔拋出一般錯誤
        // 修正前：任何錯誤都會設 quotaExhausted=true
        // 修正後：一般錯誤只增加 errorCount，不設 quotaExhausted
        final candidates = ['6547', '8044', '3293'];
        setupOtcStocks(candidates);
        setupFreshnessCheck();

        for (final symbol in candidates) {
          setupShareholdingFreshness(symbol);
        }

        // 6547 拋出一般錯誤（非 RateLimitException）
        setupSyncGenericError('6547');
        // 8044, 3293 正常同步
        setupSyncSuccess('8044');
        setupSyncSuccess('3293');

        final result = await updater.syncOtcCandidatesMarketData(
          candidates: candidates,
          date: testDate,
        );

        // 即使 6547 失敗，8044 和 3293 仍應完成同步
        expect(result.shareholdingCount, equals(2));
      },
    );

    test(
      'regression: RateLimitException sets quotaExhausted and stops early',
      () async {
        // 10 檔上櫃股票，分成 2 個 chunk (每 chunk 5 檔)
        // 第 1 chunk 中有 2 個 RateLimitException
        // 修正後：只有 RateLimitException 才設 quotaExhausted
        final candidates = List.generate(10, (i) => '${6500 + i}');
        setupOtcStocks(candidates);
        setupFreshnessCheck();

        for (final symbol in candidates) {
          setupShareholdingFreshness(symbol);
        }

        // 第一批 chunk (6500-6504)：前 2 個拋 RateLimitException
        setupSyncRateLimitError('6500');
        setupSyncRateLimitError('6501');
        for (var i = 2; i < 5; i++) {
          setupSyncSuccess('${6500 + i}');
        }

        // 第二批 chunk (6505-6509)：正常同步
        for (var i = 5; i < 10; i++) {
          setupSyncSuccess('${6500 + i}');
        }

        final result = await updater.syncOtcCandidatesMarketData(
          candidates: candidates,
          date: testDate,
        );

        // quotaExhausted + errorCount>=2 => 第一批處理完即停止
        // 第二批不應被同步
        // shareholdingCount 只有第一批中成功的 3 檔
        expect(result.shareholdingCount, equals(3));

        // 驗證第二批的 symbol 沒有被呼叫 syncShareholding
        for (var i = 5; i < 10; i++) {
          verifyNever(
            () => mockShareholdingRepo.syncShareholding(
              '${6500 + i}',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          );
        }
      },
    );

    test(
      'regression: mixed errors — generic first then RateLimitException',
      () async {
        // 驗證混合場景：先一般錯誤再 RateLimitException
        // 一般錯誤不應中斷，遇到 RateLimit 才標記 quota exhausted
        final candidates = ['6547', '8044', '3293', '6669', '4977'];
        setupOtcStocks(candidates);
        setupFreshnessCheck();

        for (final symbol in candidates) {
          setupShareholdingFreshness(symbol);
        }

        // 6547: 一般錯誤（不該觸發 quotaExhausted）
        setupSyncGenericError('6547');
        // 8044: 正常
        setupSyncSuccess('8044');
        // 3293: RateLimitException（應觸發 quotaExhausted）
        setupSyncRateLimitError('3293');
        // 6669: 正常
        setupSyncSuccess('6669');
        // 4977: 正常
        setupSyncSuccess('4977');

        final result = await updater.syncOtcCandidatesMarketData(
          candidates: candidates,
          date: testDate,
        );

        // 5 檔在同一 chunk（chunkSize=5），全部會嘗試
        // 6547 失敗（一般）、8044 成功、3293 失敗（quota）、6669 成功、4977 成功
        // quotaExhausted=true, errorCount=2 >= 2 => 會在此 chunk 結束後停止
        // 但因只有 1 個 chunk 所以全部都已執行
        expect(result.shareholdingCount, equals(3));
      },
    );

    test(
      'stops after maxTotalErrors (5) generic errors without quota exhaustion',
      () async {
        // 15 檔股票 = 3 chunks
        // 前 5 檔全部拋一般錯誤 => 達到 maxTotalErrors=5 後停止
        // 但 quotaExhausted 應為 false（非 RateLimitException）
        final candidates = List.generate(15, (i) => '${7000 + i}');
        setupOtcStocks(candidates);
        setupFreshnessCheck();

        for (final symbol in candidates) {
          setupShareholdingFreshness(symbol);
        }

        // 第一批 (7000-7004)：全部一般錯誤
        for (var i = 0; i < 5; i++) {
          setupSyncGenericError('${7000 + i}');
        }

        // 第二、三批：正常
        for (var i = 5; i < 15; i++) {
          setupSyncSuccess('${7000 + i}');
        }

        final result = await updater.syncOtcCandidatesMarketData(
          candidates: candidates,
          date: testDate,
        );

        // 第一批全部失敗，達到 maxTotalErrors=5 後停止
        expect(result.shareholdingCount, equals(0));

        // 驗證第二批及以後沒有被呼叫
        for (var i = 5; i < 15; i++) {
          verifyNever(
            () => mockShareholdingRepo.syncShareholding(
              '${7000 + i}',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          );
        }
      },
    );
  });
}
