import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockInsiderRepository extends Mock implements InsiderRepository {}

class MockDataSyncService extends Mock implements DataSyncService {}

class MockRuleAccuracyService extends Mock implements RuleAccuracyService {}

class MockWatchlistNotifier extends Notifier<WatchlistState>
    with Mock
    implements WatchlistNotifier {
  @override
  WatchlistState build() => WatchlistState();

  @override
  Future<bool> addStock(String symbol) async => true;

  @override
  Future<void> removeStock(String symbol) async {}
}

class MockAppClock extends Mock implements AppClock {}

// =============================================================================
// Test Helpers
// =============================================================================

const _testSymbol = '2330';
final _defaultDate = DateTime(2026, 2, 13);

StockMasterEntry createStock({
  String symbol = _testSymbol,
  String name = '台積電',
  String market = 'TWSE',
}) {
  return StockMasterEntry(
    symbol: symbol,
    name: name,
    market: market,
    industry: '半導體',
    isActive: true,
    updatedAt: _defaultDate,
  );
}

DailyPriceEntry createPrice({
  String symbol = _testSymbol,
  DateTime? date,
  double close = 600.0,
}) {
  final d = date ?? _defaultDate;
  return DailyPriceEntry(
    symbol: symbol,
    date: d,
    open: close * 0.99,
    high: close * 1.02,
    low: close * 0.98,
    close: close,
    volume: 50000,
  );
}

DailyAnalysisEntry createAnalysis({
  String symbol = _testSymbol,
  DateTime? date,
  double score = 75.0,
}) {
  return DailyAnalysisEntry(
    symbol: symbol,
    date: date ?? _defaultDate,
    score: score,
    trendState: 'BULLISH',
    reversalState: '',
    computedAt: date ?? _defaultDate,
  );
}

DailyReasonEntry createReason({
  String symbol = _testSymbol,
  DateTime? date,
  int rank = 1,
  String reasonType = 'GOLDEN_CROSS',
}) {
  return DailyReasonEntry(
    symbol: symbol,
    date: date ?? _defaultDate,
    rank: rank,
    reasonType: reasonType,
    evidenceJson: '{}',
    ruleScore: 10.0,
  );
}

DailyInstitutionalEntry createInstitutional({
  String symbol = _testSymbol,
  DateTime? date,
  double foreignNet = 1000.0,
}) {
  return DailyInstitutionalEntry(
    symbol: symbol,
    date: date ?? _defaultDate,
    foreignNet: foreignNet,
    investmentTrustNet: 500.0,
    dealerNet: -200.0,
  );
}

FinMindMarginData createMarginData({
  String stockId = _testSymbol,
  String date = '2026-02-13',
}) {
  return FinMindMarginData(
    stockId: stockId,
    date: date,
    marginBuy: 100,
    marginSell: 50,
    marginCashRepay: 10,
    marginBalance: 1000,
    marginLimit: 5000,
    marginUseRate: 20.0,
    shortBuy: 30,
    shortSell: 20,
    shortCashRepay: 5,
    shortBalance: 200,
    shortLimit: 1000,
    offsetMarginShort: 0,
    note: '',
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMind;
  late MockInsiderRepository mockInsiderRepo;
  late MockDataSyncService mockDataSyncService;
  late MockRuleAccuracyService mockRuleAccuracy;
  late MockAppClock mockClock;
  late ProviderContainer container;

  /// 設定 loadData 所需的所有 mock 行為
  void setupLoadDataMocks({
    StockMasterEntry? stock,
    List<DailyPriceEntry>? priceHistory,
    List<DailyPriceEntry>? recentPrices,
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry>? reasons,
    List<DailyInstitutionalEntry>? instHistory,
    bool isInWatchlist = false,
    DateTime? latestDataDate,
  }) {
    final defaultPriceHistory =
        priceHistory ??
        [
          createPrice(date: DateTime(2026, 2, 12), close: 595.0),
          createPrice(date: _defaultDate, close: 600.0),
        ];
    final defaultRecentPrices =
        recentPrices ??
        [
          createPrice(date: _defaultDate, close: 600.0),
          createPrice(date: DateTime(2026, 2, 12), close: 595.0),
        ];
    final defaultInstHistory =
        instHistory ?? [createInstitutional(date: _defaultDate)];

    when(
      () => mockDb.getLatestDataDate(),
    ).thenAnswer((_) async => latestDataDate ?? _defaultDate);
    when(
      () => mockDb.getStock(_testSymbol),
    ).thenAnswer((_) async => stock ?? createStock());
    when(
      () => mockDb.getPriceHistory(
        _testSymbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => defaultPriceHistory);
    when(
      () => mockDb.getRecentPrices(_testSymbol, count: 2),
    ).thenAnswer((_) async => defaultRecentPrices);
    when(
      () => mockDb.getAnalysis(_testSymbol, any()),
    ).thenAnswer((_) async => analysis ?? createAnalysis());
    when(
      () => mockDb.getReasons(_testSymbol, any()),
    ).thenAnswer((_) async => reasons ?? [createReason()]);
    when(
      () => mockDb.getInstitutionalHistory(
        _testSymbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => defaultInstHistory);
    when(
      () => mockDb.isInWatchlist(_testSymbol),
    ).thenAnswer((_) async => isInWatchlist);

    // DataSyncService
    when(
      () => mockDataSyncService.synchronizeDataDates(any(), any()),
    ).thenReturn((
      latestPrice: defaultPriceHistory.last,
      institutionalHistory: defaultInstHistory,
      dataDate: _defaultDate,
      hasDataMismatch: false,
    ));
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<DailyPriceEntry>[]);
    registerFallbackValue(<DailyInstitutionalEntry>[]);
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMind = MockFinMindClient();
    mockInsiderRepo = MockInsiderRepository();
    mockDataSyncService = MockDataSyncService();
    mockRuleAccuracy = MockRuleAccuracyService();
    mockClock = MockAppClock();

    when(() => mockClock.now()).thenReturn(_defaultDate);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        finMindClientProvider.overrideWithValue(mockFinMind),
        insiderRepositoryProvider.overrideWithValue(mockInsiderRepo),
        dataSyncServiceProvider.overrideWithValue(mockDataSyncService),
        ruleAccuracyServiceProvider.overrideWithValue(mockRuleAccuracy),
        appClockProvider.overrideWithValue(mockClock),
        watchlistProvider.overrideWith(() => MockWatchlistNotifier()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // StockDetailState
  // ===========================================================================

  group('StockDetailState', () {
    test('has correct default values', () {
      const state = StockDetailState();

      expect(state.price.stock, isNull);
      expect(state.price.latestPrice, isNull);
      expect(state.price.previousPrice, isNull);
      expect(state.price.priceHistory, isEmpty);
      expect(state.price.analysis, isNull);
      expect(state.fundamentals.revenueHistory, isEmpty);
      expect(state.fundamentals.dividendHistory, isEmpty);
      expect(state.fundamentals.latestPER, isNull);
      expect(state.chip.institutionalHistory, isEmpty);
      expect(state.chip.marginHistory, isEmpty);
      expect(state.chip.chipStrength, isNull);
      expect(state.loading.isLoading, isFalse);
      expect(state.loading.isLoadingMargin, isFalse);
      expect(state.loading.isLoadingFundamentals, isFalse);
      expect(state.loading.isLoadingInsider, isFalse);
      expect(state.loading.isLoadingChip, isFalse);
      expect(state.isInWatchlist, isFalse);
      expect(state.error, isNull);
      expect(state.dataDate, isNull);
      expect(state.hasDataMismatch, isFalse);
      expect(state.reasons, isEmpty);
      expect(state.aiSummary, isNull);
    });

    test('copyWith preserves unset values', () {
      final stock = createStock();
      final state = const StockDetailState().copyWith(
        stock: stock,
        isInWatchlist: true,
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.price.stock, equals(stock));
      expect(updated.isInWatchlist, isTrue);
      expect(updated.loading.isLoading, isTrue);
    });

    test('copyWith with sentinel handles error correctly', () {
      final stateWithError = const StockDetailState().copyWith(
        error: 'Test error',
      );
      expect(stateWithError.error, equals('Test error'));

      // 不傳入 error — 應保留原值
      final preserved = stateWithError.copyWith(isLoading: true);
      expect(preserved.error, equals('Test error'));

      // 明確傳入 null — 應清除 error
      final cleared = stateWithError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('convenience accessors delegate correctly', () {
      final stock = createStock(name: '台積電', market: 'TWSE');
      final price = createPrice(close: 600.0);

      final state = const StockDetailState().copyWith(
        stock: stock,
        latestPrice: price,
      );

      expect(state.stockName, equals('台積電'));
      expect(state.stockMarket, equals('TWSE'));
      expect(state.stockIndustry, equals('半導體'));
      expect(state.latestClose, equals(600.0));
    });

    test('convenience accessors return null when data is missing', () {
      const state = StockDetailState();

      expect(state.stockName, isNull);
      expect(state.stockMarket, isNull);
      expect(state.stockIndustry, isNull);
      expect(state.latestClose, isNull);
      expect(state.priceChange, isNull);
    });

    test('copyWith only creates new sub-state when fields change', () {
      final stock = createStock();
      final original = const StockDetailState().copyWith(stock: stock);

      // 只更新 loading — price/fundamentals/chip 應保持同一物件
      final updated = original.copyWith(isLoading: true);

      expect(identical(updated.fundamentals, original.fundamentals), isTrue);
      expect(identical(updated.chip, original.chip), isTrue);
    });
  });

  group('StockPriceState', () {
    test('has correct default values', () {
      const state = StockPriceState();

      expect(state.stock, isNull);
      expect(state.latestPrice, isNull);
      expect(state.previousPrice, isNull);
      expect(state.priceHistory, isEmpty);
      expect(state.analysis, isNull);
      expect(state.priceChange, isNull);
    });

    test('copyWith preserves unset values', () {
      final stock = createStock();
      final state = StockPriceState(stock: stock);

      final updated = state.copyWith(analysis: createAnalysis());

      expect(updated.stock, equals(stock));
      expect(updated.analysis, isNotNull);
    });
  });

  group('FundamentalsState', () {
    test('has correct default values', () {
      const state = FundamentalsState();

      expect(state.revenueHistory, isEmpty);
      expect(state.dividendHistory, isEmpty);
      expect(state.latestPER, isNull);
      expect(state.latestQuarterMetrics, isEmpty);
      expect(state.epsHistory, isEmpty);
    });
  });

  group('ChipAnalysisState', () {
    test('has correct default values', () {
      const state = ChipAnalysisState();

      expect(state.institutionalHistory, isEmpty);
      expect(state.marginHistory, isEmpty);
      expect(state.dayTradingHistory, isEmpty);
      expect(state.shareholdingHistory, isEmpty);
      expect(state.holdingDistribution, isEmpty);
      expect(state.insiderHistory, isEmpty);
      expect(state.chipStrength, isNull);
      expect(state.hasInstitutionalError, isFalse);
    });
  });

  group('LoadingState', () {
    test('has correct default values', () {
      const state = LoadingState();

      expect(state.isLoading, isFalse);
      expect(state.isLoadingMargin, isFalse);
      expect(state.isLoadingFundamentals, isFalse);
      expect(state.isLoadingInsider, isFalse);
      expect(state.isLoadingChip, isFalse);
    });

    test('copyWith updates individual flags', () {
      const state = LoadingState();

      final updated = state.copyWith(isLoadingMargin: true);

      expect(updated.isLoading, isFalse);
      expect(updated.isLoadingMargin, isTrue);
      expect(updated.isLoadingFundamentals, isFalse);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.loadData
  // ===========================================================================

  group('StockDetailNotifier.loadData', () {
    test('initial state has correct defaults', () {
      setupLoadDataMocks();

      final state = container.read(stockDetailProvider(_testSymbol));

      expect(state.loading.isLoading, isFalse);
      expect(state.price.stock, isNull);
      expect(state.error, isNull);
    });

    test('sets loading state and loads all data', () async {
      setupLoadDataMocks();

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      final loadFuture = notifier.loadData();

      // 驗證 loading 狀態
      expect(
        container.read(stockDetailProvider(_testSymbol)).loading.isLoading,
        isTrue,
      );

      await loadFuture;

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.price.stock, isNotNull);
      expect(state.price.stock!.name, equals('台積電'));
      expect(state.price.latestPrice, isNotNull);
      expect(state.price.priceHistory, hasLength(2));
      expect(state.reasons, hasLength(1));
      expect(state.chip.institutionalHistory, hasLength(1));
      expect(state.aiSummary, isNotNull);
      expect(state.dataDate, equals(_defaultDate));
    });

    test('handles missing stock gracefully', () async {
      setupLoadDataMocks();
      when(() => mockDb.getStock(_testSymbol)).thenAnswer((_) async => null);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.price.stock, isNull);
      expect(state.stockName, isNull);
    });

    test('falls back to API when DB has no institutional data', () async {
      setupLoadDataMocks(instHistory: []);
      when(
        () => mockDb.getInstitutionalHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <DailyInstitutionalEntry>[]);

      // Mock FinMindClient.getInstitutionalData
      when(
        () => mockFinMind.getInstitutionalData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <FinMindInstitutional>[]);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoading, isFalse);
      expect(state.error, isNull);

      // 驗證確實呼叫了 API fallback
      verify(
        () => mockFinMind.getInstitutionalData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('handles error gracefully', () async {
      when(
        () => mockDb.getLatestDataDate(),
      ).thenThrow(Exception('Database corrupted'));

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Database corrupted'));
    });

    test('clears previous error on successful load', () async {
      // 先觸發錯誤
      when(
        () => mockDb.getLatestDataDate(),
      ).thenThrow(Exception('First error'));

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      expect(container.read(stockDetailProvider(_testSymbol)).error, isNotNull);

      // 重設 mock 為成功
      setupLoadDataMocks();
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.error, isNull);
      expect(state.price.stock, isNotNull);
    });

    test('handles null latestDataDate', () async {
      setupLoadDataMocks();
      when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => null);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('sets isInWatchlist from DB', () async {
      setupLoadDataMocks(isInWatchlist: true);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.isInWatchlist, isTrue);
    });

    test('handles data mismatch correctly', () async {
      final priceHistory = [
        createPrice(date: DateTime(2026, 2, 11), close: 590.0),
        createPrice(date: DateTime(2026, 2, 12), close: 595.0),
        createPrice(date: _defaultDate, close: 600.0),
      ];

      setupLoadDataMocks(priceHistory: priceHistory);

      when(
        () => mockDataSyncService.synchronizeDataDates(any(), any()),
      ).thenReturn((
        latestPrice: priceHistory[1],
        institutionalHistory: [
          createInstitutional(date: DateTime(2026, 2, 12)),
        ],
        dataDate: DateTime(2026, 2, 12),
        hasDataMismatch: true,
      ));

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.hasDataMismatch, isTrue);
      expect(state.dataDate, equals(DateTime(2026, 2, 12)));
    });

    test('with empty reasons', () async {
      setupLoadDataMocks(reasons: []);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.reasons, isEmpty);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.toggleWatchlist
  // ===========================================================================

  group('StockDetailNotifier.toggleWatchlist', () {
    test('adds to watchlist when not in watchlist', () async {
      setupLoadDataMocks(isInWatchlist: false);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.toggleWatchlist();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.isInWatchlist, isTrue);
    });

    test('removes from watchlist when in watchlist', () async {
      setupLoadDataMocks(isInWatchlist: true);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.toggleWatchlist();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.isInWatchlist, isFalse);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.loadMarginData
  // ===========================================================================

  group('StockDetailNotifier.loadMarginData', () {
    test('loads margin data from API', () async {
      setupLoadDataMocks();

      when(
        () => mockFinMind.getMarginData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <FinMindMarginData>[]);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadMarginData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoadingMargin, isFalse);

      verify(
        () => mockFinMind.getMarginData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('skips when already loaded', () async {
      setupLoadDataMocks();

      when(
        () => mockFinMind.getMarginData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => [createMarginData()]);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadMarginData();
      await notifier.loadMarginData(); // 第二次應跳過（marginHistory 已有資料）

      verify(
        () => mockFinMind.getMarginData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.loadFundamentals
  // ===========================================================================

  group('StockDetailNotifier.loadFundamentals', () {
    test('handles error gracefully', () async {
      setupLoadDataMocks();

      // FundamentalsLoader.loadAll() 第一步呼叫 _loadValuationData
      // 讓 DB 方法拋出例外
      when(
        () => mockDb.getValuationHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('Valuation API error'));

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadFundamentals();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoadingFundamentals, isFalse);
      // error 不應設在主 state（只有 loadData 的 catch 會設主 error）
      expect(state.error, isNull);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.loadInsiderData
  // ===========================================================================

  group('StockDetailNotifier.loadInsiderData', () {
    test('loads insider data from DB', () async {
      setupLoadDataMocks();

      final insiderData = <InsiderHoldingEntry>[
        InsiderHoldingEntry(
          symbol: _testSymbol,
          date: _defaultDate,
          directorShares: 1000000,
          supervisorShares: 500000,
          managerShares: 200000,
          pledgeRatio: 5.0,
        ),
      ];

      when(
        () => mockInsiderRepo.getInsiderHoldingHistory(
          _testSymbol,
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => insiderData);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadInsiderData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.chip.insiderHistory, hasLength(1));
      expect(state.loading.isLoadingInsider, isFalse);
    });

    test('skips when already loaded', () async {
      setupLoadDataMocks();

      final insiderData = <InsiderHoldingEntry>[
        InsiderHoldingEntry(
          symbol: _testSymbol,
          date: _defaultDate,
          directorShares: 1000000,
          supervisorShares: 500000,
          managerShares: 200000,
          pledgeRatio: 5.0,
        ),
      ];

      when(
        () => mockInsiderRepo.getInsiderHoldingHistory(
          _testSymbol,
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => insiderData);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadInsiderData();
      await notifier.loadInsiderData(); // 第二次應跳過

      verify(
        () => mockInsiderRepo.getInsiderHoldingHistory(
          _testSymbol,
          months: any(named: 'months'),
        ),
      ).called(1);
    });
  });

  // ===========================================================================
  // StockDetailNotifier.loadChipData
  // ===========================================================================

  group('StockDetailNotifier.loadChipData', () {
    test('loads all chip data', () async {
      setupLoadDataMocks();

      when(
        () => mockDb.getDayTradingHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <DayTradingEntry>[]);
      when(
        () => mockDb.getShareholdingHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <ShareholdingEntry>[]);
      when(
        () => mockDb.getMarginTradingHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <MarginTradingEntry>[]);
      when(
        () => mockDb.getLatestHoldingDistribution(_testSymbol),
      ).thenAnswer((_) async => <HoldingDistributionEntry>[]);
      when(
        () => mockDb.getRecentInsiderHoldings(
          _testSymbol,
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => <InsiderHoldingEntry>[]);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadChipData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoadingChip, isFalse);
      expect(state.chip.chipStrength, isNotNull);
    });

    test('handles error gracefully', () async {
      setupLoadDataMocks();

      when(
        () => mockDb.getDayTradingHistory(
          _testSymbol,
          startDate: any(named: 'startDate'),
        ),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();
      await notifier.loadChipData();

      final state = container.read(stockDetailProvider(_testSymbol));
      expect(state.loading.isLoadingChip, isFalse);
    });
  });

  // ===========================================================================
  // ruleAccuracyProvider
  // ===========================================================================

  group('ruleAccuracyProvider', () {
    test('returns stats for valid ruleId', () async {
      const stats = RuleStats(
        ruleId: 'GOLDEN_CROSS',
        hitRate: 0.65,
        avgReturn: 2.3,
        triggerCount: 50,
      );

      when(
        () => mockRuleAccuracy.getRuleStats('GOLDEN_CROSS'),
      ).thenAnswer((_) async => stats);

      final result = await container.read(
        ruleAccuracyProvider('GOLDEN_CROSS').future,
      );

      expect(result, isNotNull);
      expect(result!.hitRate, equals(0.65));
      expect(result.avgReturn, equals(2.3));
    });

    test('returns null for insufficient data', () async {
      when(
        () => mockRuleAccuracy.getRuleStats('RARE_RULE'),
      ).thenAnswer((_) async => null);

      final result = await container.read(
        ruleAccuracyProvider('RARE_RULE').future,
      );

      expect(result, isNull);
    });
  });

  // ===========================================================================
  // primaryRuleAccuracySummaryProvider
  // ===========================================================================

  group('primaryRuleAccuracySummaryProvider', () {
    test('returns null when no reasons', () async {
      setupLoadDataMocks(reasons: []);

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final result = await container.read(
        primaryRuleAccuracySummaryProvider(_testSymbol).future,
      );

      expect(result, isNull);
    });

    test('uses primary reason with rank=1', () async {
      final reasons = [
        createReason(rank: 2, reasonType: 'VOLUME_BREAKOUT'),
        createReason(rank: 1, reasonType: 'GOLDEN_CROSS'),
      ];

      setupLoadDataMocks(reasons: reasons);

      when(
        () => mockRuleAccuracy.getRuleSummaryText('GOLDEN_CROSS'),
      ).thenAnswer((_) async => '命中率 65%，平均 5 日報酬 +2.3%');

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final result = await container.read(
        primaryRuleAccuracySummaryProvider(_testSymbol).future,
      );

      expect(result, equals('命中率 65%，平均 5 日報酬 +2.3%'));
      verify(
        () => mockRuleAccuracy.getRuleSummaryText('GOLDEN_CROSS'),
      ).called(1);
    });

    test('falls back to first reason when rank=1 not found', () async {
      final reasons = [
        createReason(rank: 2, reasonType: 'VOLUME_BREAKOUT'),
        createReason(rank: 3, reasonType: 'RSI_OVERSOLD'),
      ];

      setupLoadDataMocks(reasons: reasons);

      when(
        () => mockRuleAccuracy.getRuleSummaryText('VOLUME_BREAKOUT'),
      ).thenAnswer((_) async => '量能突破摘要');

      final notifier = container.read(
        stockDetailProvider(_testSymbol).notifier,
      );
      await notifier.loadData();

      final result = await container.read(
        primaryRuleAccuracySummaryProvider(_testSymbol).future,
      );

      expect(result, equals('量能突破摘要'));
    });
  });
}
