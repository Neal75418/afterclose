import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/models/scoring_batch_data.dart';
import 'package:afterclose/domain/repositories/news_repository.dart'
    show NewsSyncResult;
import 'package:afterclose/domain/repositories/price_repository.dart'
    show MarketSyncResult;
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:afterclose/domain/services/update/news_mention_snapshot_service.dart';
import 'package:afterclose/domain/services/thesis/thesis_monitor_service.dart';
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

class MockNewsMentionSnapshotService extends Mock
    implements NewsMentionSnapshotService {}

class MockThesisMonitorService extends Mock implements ThesisMonitorService {}

class MockTradingRepository extends Mock implements TradingRepository {}

class MockShareholdingRepository extends Mock
    implements ShareholdingRepository {}

class MockWarningRepository extends Mock implements WarningRepository {}

class MockInsiderRepository extends Mock implements InsiderRepository {}

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
      () =>
          mockDb.getLatestMonthlyRevenuesBatch(any(), asOf: any(named: 'asOf')),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getLatestValuationsBatch(any(), asOf: any(named: 'asOf')),
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
      () => mockDb.getLatestShareholdingsBatch(any(), asOf: any(named: 'asOf')),
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
      () => mockDb.getMarketsForSymbolsBatch(any()),
    ).thenAnswer((_) async => <String, String>{});
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
    NewsMentionSnapshotService? newsMentionSnapshot,
    TradingRepository? trading,
    ShareholdingRepository? shareholding,
    WarningRepository? warning,
    InsiderRepository? insider,
    ThesisMonitorService? thesisMonitor,
  }) {
    return UpdateService(
      database: mockDb,
      repositories: UpdateRepositories(
        stock: mockStockRepo,
        price: mockPriceRepo,
        news: mockNewsRepo,
        analysis: mockAnalysisRepo,
        fundamental: fundamental,
        trading: trading,
        shareholding: shareholding,
        warning: warning,
        insider: insider,
      ),
      clients: UpdateClients(tdcc: mockTdcc, tpex: tpex),
      services: UpdateServices(
        scoring: mockScoring,
        newsMentionSnapshot: newsMentionSnapshot,
        thesisMonitor: thesisMonitor,
      ),
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

    test('半個市場價格取得失敗必須可見（TWSE 空、TPEx 有資料）', () async {
      // safeAwait 把來源失敗吞成空陣列：只有 TWSE 掛掉時 tpexPrices 非空、
      // 不進「兩者皆空」分支 → 用半個市場的資料照常評分且無人知曉。
      when(() => mockPriceRepo.syncAllPricesForDate(any())).thenAnswer(
        (_) async => MarketSyncResult(
          count: 900,
          candidates: const [],
          dataDate: tradingDay,
          emptyMarkets: const ['TWSE'],
        ),
      );

      final service = buildService();
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(
        result.errors,
        anyElement(contains('TWSE')),
        reason: '缺半個市場卻回報成功，等於讓使用者用殘缺資料下單',
      );
      expect(result.hasWarnings, isTrue);
    });

    test('🚨 日期回滾時不得誤報缺市場（早盤假 partial）', () async {
      // 交易日盤前/盤中：TPEx 當日行情檔未發布 → 空；TWSE 端點自動回上一交易日
      // → dataDate 早於 targetDate、觸發回滾。此時「TPEx 今日零筆」是預期的，
      // 而回滾後那一天的資料 DB 早已完整，記 error 會讓每個交易日早盤都假 partial。
      final prevDay = tradingDay.subtract(const Duration(days: 1));
      when(() => mockPriceRepo.syncAllPricesForDate(any())).thenAnswer(
        (_) async => MarketSyncResult(
          count: 1200,
          candidates: const [],
          dataDate: prevDay,
          emptyMarkets: const ['TPEx'],
        ),
      );

      final service = buildService();
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(
        result.errors.where((e) => e.contains('TPEx')),
        isEmpty,
        reason: '日期已回滾到有完整資料的那天，不該報缺市場',
      );
    });

    test('兩個市場都有資料時不得誤報錯誤', () async {
      final service = buildService();
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(
        result.errors.where((e) => e.contains('價格')),
        isEmpty,
        reason: '正常路徑不得產生假警告',
      );
    });

    test('🚨 警示同步失敗必須轉發到 errors（處置股是硬排除、非額外功能）', () async {
      // KillerFeaturesSyncResult 的 warningError/insiderError 過去零消費點，
      // 且裸 catch 明寫「額外功能不影響主流程」。但處置股是三模式榜的硬性
      // 宇宙排除（-50 分 + droppedDisposal），缺名單是 fail-open：危險股照常
      // 上榜、風險徽章不亮，而使用者看到綠燈。
      final trading = MockTradingRepository();
      final shareholding = MockShareholdingRepository();
      final warningRepo = MockWarningRepository();
      final insider = MockInsiderRepository();

      // 步驟 4.5 籌碼鏈：讓它安靜通過
      when(
        () => trading.syncAllDayTradingFromTwse(date: any(named: 'date')),
      ).thenAnswer((_) async => 0);
      when(
        () => trading.syncAllMarginTradingFromTwse(date: any(named: 'date')),
      ).thenAnswer((_) async => 0);
      when(
        () => shareholding.syncShareholding(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockDb.getLatestDayTradingDate(),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getDayTradingCountForDate(any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.countStocksByMarket(any()),
      ).thenAnswer((_) async => 100);
      when(
        () => mockDb.countPricesByDateAndMarket(any(), any()),
      ).thenAnswer((_) async => 100);
      when(
        () => mockDb.countMarginTradingByDateAndMarket(any(), any()),
      ).thenAnswer((_) async => 100);
      when(() => mockDb.getStocksByMarket(any())).thenAnswer((_) async => []);

      // 步驟 4.8：警示同步失敗（generic，非 rate limit）
      when(
        () => warningRepo.syncAllMarketWarnings(force: any(named: 'force')),
      ).thenThrow(Exception('TWSE announcement 500'));
      when(
        () => insider.syncAllInsiderHoldings(force: any(named: 'force')),
      ).thenAnswer((_) async => 0);

      final service = buildService(
        trading: trading,
        shareholding: shareholding,
        warning: warningRepo,
        insider: insider,
      );
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(
        result.errors,
        anyElement(contains('警示')),
        reason: '缺處置股名單會讓危險股照常上榜，必須進 errors 讓 run 降級',
      );
      // 不斷言 hasWarnings：它是 `errors.isNotEmpty && success`，而本測試的
      // 精簡 harness 未 stub 全部步驟、success 未必為 true。要釘的契約是
      // 「警示失敗有沒有進 errors」，那才是本次修復的內容。
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

  group('UpdateService 新聞提及快照 fail-safe', () {
    test('新聞提及快照拋例外時更新流程照常完成', () async {
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});

      final mockSnapshotService = MockNewsMentionSnapshotService();
      when(
        () => mockSnapshotService.snapshotRecentDays(),
      ).thenThrow(Exception('snapshot boom'));

      final service = buildService(newsMentionSnapshot: mockSnapshotService);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      // 快照失敗不應中斷或拖垮整體更新結果（fail-safe：只 log，不 rethrow）
      expect(result.success, isTrue);
      verify(() => mockSnapshotService.snapshotRecentDays()).called(1);
    });

    // ====================================================================
    // 步驟 10+ 的失敗必須可見（finding #23）
    //
    // 三個 fail-safe（規則準確度統計、新聞提及快照、釘選論點失效檢查）原本
    // 跑在 `_finishUpdate` **之後**，且只 AppLogger、不碰 result.errors。
    // 而 `_finishUpdate` 依 result.errors 決定 update_run 狀態並設
    // `result.success = true` —— 於是這三步整個沒跑，畫面仍是乾淨的
    // 「更新完成」、update_run 仍是 SUCCESS。
    //
    // 影響最重的是釘選論點檢查：那是**出場層**。它靜默沒跑代表該失效的
    // 論點不會被標記，使用者會抱著一個已達出場條件的部位而毫不知情。
    // 新聞提及快照失敗則是永久損失——news_mention_daily 在 wipe 白名單內
    // 正因為「歷史不可重建」。
    //
    // fail-safe 的語意是「不中斷流程」，不是「不留下痕跡」。
    // ====================================================================

    test('🚨 快照失敗必須進 result.errors（fail-safe ≠ 無痕）', () async {
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});

      final mockSnapshotService = MockNewsMentionSnapshotService();
      when(
        () => mockSnapshotService.snapshotRecentDays(),
      ).thenThrow(Exception('snapshot boom'));

      final service = buildService(newsMentionSnapshot: mockSnapshotService);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue, reason: 'fail-safe 仍不得中斷流程');
      expect(
        result.errors,
        anyElement(contains('新聞提及快照')),
        reason: '失敗必須留下痕跡，否則使用者看到的是乾淨的「更新完成」',
      );
    });

    test('🚨 釘選論點檢查失敗必須進 result.errors（出場層靜默沒跑最危險）', () async {
      when(
        () => mockTdcc.getAllHoldingDistribution(),
      ).thenAnswer((_) async => {});

      final mockThesis = MockThesisMonitorService();
      when(
        () => mockThesis.checkActiveTheses(asOf: any(named: 'asOf')),
      ).thenThrow(Exception('thesis boom'));

      final service = buildService(thesisMonitor: mockThesis);
      final result = await service.runDailyUpdate(forDate: tradingDay);

      expect(result.success, isTrue);
      expect(result.errors, anyElement(contains('釘選論點')));
    });
  });
}
