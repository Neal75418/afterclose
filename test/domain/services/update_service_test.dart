import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/models/scoring_batch_data.dart';
import 'package:afterclose/domain/repositories/news_repository.dart'
    show NewsSyncResult;
import 'package:afterclose/domain/repositories/price_repository.dart'
    show MarketSyncResult;
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/domain/services/update_service_deps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockStockRepository extends Mock implements StockRepository {}

class MockPriceRepository extends Mock implements PriceRepository {}

class MockNewsRepository extends Mock implements NewsRepository {}

class MockAnalysisRepository extends Mock implements AnalysisRepository {}

class MockTdccClient extends Mock implements TdccClient {}

class MockTpexClient extends Mock implements TpexClient {}

class MockFundamentalRepository extends Mock implements FundamentalRepository {}

class MockScoringService extends Mock implements ScoringService {}

void main() {
  late MockAppDatabase mockDb;
  late MockStockRepository mockStockRepo;
  late MockPriceRepository mockPriceRepo;
  late MockNewsRepository mockNewsRepo;
  late MockAnalysisRepository mockAnalysisRepo;
  late MockTdccClient mockTdcc;
  late MockScoringService mockScoring;

  // 2026-07-06 為週一交易日
  final tradingDay = DateTime(2026, 7, 6);

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 7, 6));
    registerFallbackValue(
      ScoringBatchData(pricesMap: const {}, newsMap: const {}),
    );
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockStockRepo = MockStockRepository();
    mockPriceRepo = MockPriceRepository();
    mockNewsRepo = MockNewsRepository();
    mockAnalysisRepo = MockAnalysisRepository();
    mockTdcc = MockTdccClient();
    mockScoring = MockScoringService();

    // --- 主流程 happy-path stubs（candidates 為空，聚焦輔助資料步驟）---
    when(() => mockDb.createUpdateRun(any(), any())).thenAnswer((_) async => 1);
    when(
      () =>
          mockDb.finishUpdateRun(any(), any(), message: any(named: 'message')),
    ).thenAnswer((_) async {});
    // 股票清單：空 DB → needsInit → syncStockList
    when(() => mockStockRepo.getAllStocks()).thenAnswer((_) async => []);
    when(() => mockStockRepo.syncStockList()).thenAnswer((_) async => 1000);
    // 價格：dataDate 與目標日一致 → 不觸發日期校正
    when(() => mockPriceRepo.syncAllPricesForDate(any())).thenAnswer(
      (_) async => MarketSyncResult(
        count: 100,
        candidates: const [],
        dataDate: tradingDay,
      ),
    );
    // 歷史資料 / 候選篩選：無符合股票
    when(
      () => mockDb.getSymbolsWithSufficientData(
        minDays: any(named: 'minDays'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => []);
    // 流動性下限：無成交值資料 → 全部 permissive 放行
    when(
      () => mockDb.getMedianTurnoverBatch(
        endDate: any(named: 'endDate'),
        windowDays: any(named: 'windowDays'),
        minDataDays: any(named: 'minDataDays'),
      ),
    ).thenAnswer((_) async => {});
    when(() => mockDb.getStocksBatch(any())).thenAnswer((_) async => {});
    when(
      () => mockPriceRepo.syncStockPrices(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 10);
    // 新聞
    when(
      () => mockNewsRepo.syncNews(sources: any(named: 'sources')),
    ).thenAnswer((_) async => const NewsSyncResult(itemsAdded: 0, errors: []));
    when(
      () => mockNewsRepo.cleanupOldNews(
        olderThanDays: any(named: 'olderThanDays'),
      ),
    ).thenAnswer((_) async => 0);
    // BatchDataLoader 的空批次查詢
    when(
      () => mockDb.getPriceHistoryBatch(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockNewsRepo.getNewsForStocksBatch(any(), days: any(named: 'days')),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getLatestMonthlyRevenuesBatch(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getLatestValuationsBatch(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getRecentMonthlyRevenueBatch(
        any(),
        months: any(named: 'months'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getDayTradingMapForDate(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getLatestShareholdingsBatch(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getShareholdingsBeforeDateBatch(
        any(),
        beforeDate: any(named: 'beforeDate'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getActiveWarningsMapBatch(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getLatestInsiderHoldingsBatch(any()),
    ).thenAnswer((_) async => {});
    when(() => mockDb.getEPSHistoryBatch(any())).thenAnswer((_) async => {});
    when(() => mockDb.getROEHistoryBatch(any())).thenAnswer((_) async => {});
    when(
      () => mockDb.getDividendHistoryBatch(any()),
    ).thenAnswer((_) async => {});
    when(() => mockDb.getMaxRevenueBatch(any())).thenAnswer((_) async => {});
    // 評分（空結果）；當日清除已移入 ScoringService 的寫入 transaction，
    // 此處 scoring 為 mock 故不需 stub clear
    when(
      () => mockScoring.scoreStocksInIsolate(
        candidates: any(named: 'candidates'),
        date: any(named: 'date'),
        batchData: any(named: 'batchData'),
      ),
    ).thenAnswer((_) async => []);
    // 完成階段：警示價格
    when(() => mockDb.getActiveAlerts()).thenAnswer((_) async => []);
    when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);
    when(() => mockDb.getLatestPricesBatch(any())).thenAnswer((_) async => {});
    // TDCC 新鮮度檢查：無本週資料
    when(
      () => mockDb.getLatestHoldingDistributionDate(any()),
    ).thenAnswer((_) async => null);
  });

  /// 建立最小依賴的 UpdateService：
  /// 預設只提供 tdcc client（twse/tpex/finMind 為 null → 對應 syncer 不建立），
  /// 只提供 required repositories（institutional 等為 null → 對應 syncer 不建立）。
  /// 各測試可額外注入 tpex / fundamental 以啟用對應 syncer。
  UpdateService buildService({
    TpexClient? tpex,
    FundamentalRepository? fundamental,
  }) {
    return UpdateService(
      database: mockDb,
      repositories: UpdateRepositories(
        stock: mockStockRepo,
        price: mockPriceRepo,
        news: mockNewsRepo,
        analysis: mockAnalysisRepo,
        fundamental: fundamental,
      ),
      clients: UpdateClients(tdcc: mockTdcc, tpex: tpex),
      services: UpdateServices(scoring: mockScoring),
    );
  }

  group('UpdateService 輔助資料同步失敗的可見性', () {
    test('TDCC generic 同步失敗應記錄到 result.errors（partial 警告可見）', () async {
      // TDCC client 拋出 generic exception（模擬 API 格式變更等非限流故障）
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenThrow(Exception('unexpected payload'));

      final service = buildService();
      final result = await service.runDailyUpdate(forDate: tradingDay);

      // 主流程不受輔助資料失敗影響
      expect(result.success, isTrue);
      // 失敗必須可見：TDCC 失敗應進 errors 使 status 成為 partial
      expect(
        result.errors,
        anyElement(contains('TDCC')),
        reason: 'TDCC generic 失敗被靜默吞掉，使用者無從得知資料 stale',
      );
      expect(result.hasWarnings, isTrue);
    });

    test('內部人轉讓 generic 同步失敗應記錄到 result.errors', () async {
      final mockTpex = MockTpexClient();
      // TDCC 成功（回空資料 → 跳過寫入）
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});
      // 股利路徑成功（回空清單）
      when(() => mockDb.getAllActiveStocks()).thenAnswer((_) async => []);
      when(() => mockTpex.getDeclaredDividends()).thenAnswer((_) async => []);
      when(() => mockTpex.getShareholderMeetings()).thenAnswer((_) async => []);
      // 內部人轉讓：generic exception
      when(
        () => mockTpex.getInsiderTransfers(),
      ).thenThrow(Exception('schema changed'));

      final service = buildService(tpex: mockTpex);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue);
      expect(result.errors, anyElement(contains('內部人轉讓')));
    });

    test('股利 syncer 內部收集的錯誤應轉發到 result.errors', () async {
      final mockTpex = MockTpexClient();
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});
      when(() => mockDb.getAllActiveStocks()).thenAnswer((_) async => []);
      // 股利來源 generic 失敗 → DividendSyncer 收進自身 result.errors（不 throw）
      when(
        () => mockTpex.getDeclaredDividends(),
      ).thenThrow(Exception('payload broken'));
      when(() => mockTpex.getShareholderMeetings()).thenAnswer((_) async => []);
      when(() => mockTpex.getInsiderTransfers()).thenAnswer((_) async => []);

      final service = buildService(tpex: mockTpex);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue);
      // DividendSyncResult.errors 必須被 caller 讀取並轉發，否則靜默
      expect(result.errors, anyElement(contains('股利')));
    });

    test(
      '全市場估值 generic 失敗（FundamentalSyncer 內部收集）應轉發到 result.errors',
      () async {
        final mockFundamental = MockFundamentalRepository();
        when(
          () => mockTdcc.getAllHoldingDistribution(),
        ).thenAnswer((_) async => {});
        // 估值 generic 失敗；營收成功
        when(
          () => mockFundamental.syncAllMarketValuation(
            any(),
            force: any(named: 'force'),
          ),
        ).thenThrow(Exception('BWIBBU format changed'));
        when(
          () => mockFundamental.syncAllMarketRevenue(
            any(),
            force: any(named: 'force'),
          ),
        ).thenAnswer((_) async => 0);
        when(() => mockDb.getStocksByMarket(any())).thenAnswer((_) async => []);
        when(
          () => mockFundamental.syncFinancialStatements(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => 0);

        final service = buildService(fundamental: mockFundamental);
        final result = await service.runDailyUpdate(forDate: tradingDay);

        expect(result.success, isTrue);
        // FundamentalSyncer 內部 catch 收集的失敗必須被 caller 轉發，否則靜默
        expect(result.errors, anyElement(contains('估值')));
      },
    );

    test('上櫃自選估值 generic 失敗（syncOtcWatchlistFundamentals）應轉發', () async {
      final mockFundamental = MockFundamentalRepository();
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});
      when(
        () => mockFundamental.syncAllMarketValuation(
          any(),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockFundamental.syncAllMarketRevenue(
          any(),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockFundamental.syncFinancialStatements(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => 0);
      // watchlist 含一檔上櫃股 → 觸發 OTC watchlist 補充
      when(() => mockDb.getWatchlist()).thenAnswer(
        (_) async => [
          WatchlistEntry(symbol: '3567', createdAt: DateTime(2026, 1, 1)),
        ],
      );
      when(() => mockDb.getStocksByMarket(any())).thenAnswer(
        (_) async => [
          StockMasterEntry(
            symbol: '3567',
            name: '逸昌',
            market: 'TPEx',
            isActive: true,
            updatedAt: DateTime(2026, 7, 8),
          ),
        ],
      );
      // OTC 估值 generic 失敗（syncer 內部收集、不 throw）
      when(
        () => mockFundamental.syncOtcValuation(
          any(),
          date: any(named: 'date'),
          force: any(named: 'force'),
        ),
      ).thenThrow(Exception('OTC valuation broken'));
      when(
        () => mockFundamental.syncOtcRevenue(
          any(),
          date: any(named: 'date'),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async => 0);

      final service = buildService(fundamental: mockFundamental);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue);
      expect(result.errors, anyElement(contains('上櫃自選估值')));
    });

    test('財報 generic 同步失敗應記錄到 result.errors', () async {
      final mockFundamental = MockFundamentalRepository();
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});
      // 全市場基本面成功
      when(
        () => mockFundamental.syncAllMarketValuation(
          any(),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockFundamental.syncAllMarketRevenue(
          any(),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async => 0);
      // 上櫃自選：watchlist 空 → 早退（getWatchlist 已 stub 回空）
      when(() => mockDb.getStocksByMarket(any())).thenAnswer((_) async => []);
      // 財報：generic exception
      when(
        () => mockFundamental.syncFinancialStatements(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('EPS format changed'));

      final service = buildService(fundamental: mockFundamental);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue);
      expect(result.errors, anyElement(contains('財報')));
    });
  });
}
