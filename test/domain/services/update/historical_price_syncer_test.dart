import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/domain/services/update/historical_price_syncer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockPriceRepository extends Mock implements PriceRepository {}

void main() {
  late MockAppDatabase mockDb;
  late MockPriceRepository mockPriceRepo;
  late HistoricalPriceSyncer syncer;

  final testDate = DateTime(2025, 1, 15);

  /// 建立 N 天的價格資料
  List<DailyPriceEntry> createPrices(
    String symbol,
    int days, {
    DateTime? firstDate,
  }) {
    final start = firstDate ?? testDate.subtract(Duration(days: days));
    return List.generate(
      days,
      (i) => DailyPriceEntry(
        symbol: symbol,
        date: start.add(Duration(days: i)),
        close: 100.0,
      ),
    );
  }

  /// 設定 DB 的 getSymbolsWithSufficientData 回傳值
  void setupSufficientDataSymbols(List<String> symbols) {
    when(
      () => mockDb.getSymbolsWithSufficientData(
        minDays: any(named: 'minDays'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => symbols);
  }

  /// 設定 DB 的價格覆蓋回傳值（fixtures 仍以 entry list 描述，
  /// 於此導出 PriceCoverage——與 DAO aggregate 同語意，讓既有測試
  /// 全數成為 aggregate 重構的等價證明）
  void setupPriceHistoryBatch(Map<String, List<DailyPriceEntry>> batch) {
    final coverage = <String, PriceCoverage>{};
    for (final entry in batch.entries) {
      final prices = entry.value;
      if (prices.isEmpty) continue;
      var first = prices.first.date;
      var last = prices.first.date;
      final months = <(int, int), int>{};
      for (final p in prices) {
        if (p.date.isBefore(first)) first = p.date;
        if (p.date.isAfter(last)) last = p.date;
        final key = (p.date.year, p.date.month);
        months[key] = (months[key] ?? 0) + 1;
      }
      coverage[entry.key] = PriceCoverage(
        count: prices.length,
        firstDate: first,
        lastDate: last,
        daysByMonth: months,
      );
    }
    when(
      () => mockDb.getPriceCoverageBatch(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => coverage);
  }

  /// 設定 PriceRepo 的 syncStockPrices 成功回傳
  void setupSyncSuccess(String symbol, {int count = 10}) {
    when(
      () => mockPriceRepo.syncStockPrices(
        symbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => count);
  }

  /// 設定 PriceRepo 的 syncStockPrices 拋出錯誤
  void setupSyncFailure(String symbol) {
    when(
      () => mockPriceRepo.syncStockPrices(
        symbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(Exception('API Error'));
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2020));
    registerFallbackValue(<String>{});
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockPriceRepo = MockPriceRepository();
    syncer = HistoricalPriceSyncer(
      database: mockDb,
      priceRepository: mockPriceRepo,
    );
    // 市場日快照回補（phase 0）的良性預設：股票主檔為空 → phase 0
    // 直接跳過（fresh DB 防護），既有 per-symbol 測試行為不變。
    when(() => mockDb.getStocksByMarket(any())).thenAnswer((_) async => []);
  });

  group('HistoricalPriceSyncer', () {
    group('syncHistoricalPrices', () {
      test('returns zero when all symbols have sufficient data', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '2330': createPrices('2330', 260),
          '2317': createPrices('2317', 260),
        });

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330', '2317'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 0);
        expect(result.symbolsProcessed, 0);
        verifyNever(
          () => mockPriceRepo.syncStockPrices(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      });

      test('syncs symbols with zero price data', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': []});
        setupSyncSuccess('2330', count: 250);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 250);
        expect(result.symbolsProcessed, 1);
        expect(result.hasErrors, isFalse);
      });

      test(
        'skips non-priority symbols with near-complete data (>= 180 days)',
        () async {
          // firstDate > 365 days ago ensures _hasEnoughDataForAge won't skip
          final oldFirstDate = testDate.subtract(const Duration(days: 400));

          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({
            'A330': createPrices('A330', 200), // >= 180, should skip
            'A317': createPrices(
              'A317',
              50,
              firstDate: oldFirstDate,
            ), // < 180, needs sync
          });
          setupSyncSuccess('A317', count: 200);

          // 注意：兩檔都 NOT in watchlist/popular → 走 lenient 路徑
          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: [],
            popularStocks: [],
            marketCandidates: ['A330', 'A317'],
          );

          expect(result.syncedCount, 200);
          expect(result.symbolsProcessed, 1);

          // A330 should not be synced (non-priority, >= 180 → lenient skip)
          verifyNever(
            () => mockPriceRepo.syncStockPrices(
              'A330',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          );
        },
      );

      // 2026-06 production regression：watchlist/popular 股卡在 200-240 天
      // 區間時，被 nearThreshold (180) 與 _hasEnoughDataForAge 兩個 lenient
      // 早退濾掉，永遠補不到 250 → 52w high/low rule 永久無法觸發。
      // 修正後 priority 股只認嚴格 250 天門檻，會持續 top-up 到 250。
      test(
        'priority stock (watchlist) with 221/250 days is NOT skipped — keeps topping up to 250',
        () async {
          // 模擬 production：2330 在 watchlist，cache 有 221 天，
          // firstDate 約 250 天前（成熟股，age ratio check 會說「夠了」）。
          final oldFirstDate = testDate.subtract(const Duration(days: 250));

          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({
            '2330': createPrices('2330', 221, firstDate: oldFirstDate),
          });
          setupSyncSuccess('2330', count: 30);

          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: ['2330'],
            popularStocks: [],
            marketCandidates: [],
          );

          // priority 股應該被同步（追到 250）
          expect(result.symbolsProcessed, 1);
          verify(
            () => mockPriceRepo.syncStockPrices(
              '2330',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        },
      );

      test(
        'priority stock (popular) overrides _hasEnoughDataForAge ratio skip',
        () async {
          // 2454 in popular，cache 200/250 days，age ratio check 認為夠
          // (200/250 ≈ 80% > 50% threshold)。修正前會被 ratio 跳過。
          final oldFirstDate = testDate.subtract(const Duration(days: 250));

          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({
            '2454': createPrices('2454', 200, firstDate: oldFirstDate),
          });
          setupSyncSuccess('2454', count: 50);

          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: [],
            popularStocks: ['2454'],
            marketCandidates: [],
          );

          expect(result.symbolsProcessed, 1);
          verify(
            () => mockPriceRepo.syncStockPrices(
              '2454',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        },
      );

      test(
        'priority stock with >= 250 days IS skipped (truly complete)',
        () async {
          // sanity：priority 股若已達 250 仍應跳過，不應無限制呼叫 API
          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({'2330': createPrices('2330', 260)});

          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: ['2330'],
            popularStocks: [],
            marketCandidates: [],
          );

          expect(result.symbolsProcessed, 0);
          verifyNever(
            () => mockPriceRepo.syncStockPrices(
              '2330',
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          );
        },
      );

      test('handles partial failures gracefully', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': [], '2317': []});
        setupSyncSuccess('2330', count: 250);
        setupSyncFailure('2317');

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330', '2317'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 250);
        expect(result.symbolsProcessed, 1);
        expect(result.hasErrors, isTrue);
        expect(result.failedSymbols, contains('2317'));
      });

      test('deduplicates symbols from multiple sources', () async {
        final oldFirstDate = testDate.subtract(const Duration(days: 400));

        setupSufficientDataSymbols(['2330']);
        setupPriceHistoryBatch({
          '2330': createPrices(
            '2330',
            50,
            firstDate: oldFirstDate,
          ), // needs sync
          '2317': createPrices('2317', 260), // sufficient
        });
        setupSyncSuccess('2330', count: 200);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: ['2330', '2317'],
          marketCandidates: ['2330'],
        );

        // 2330 should only be synced once
        expect(result.symbolsProcessed, 1);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('calls onProgress callback', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': []});
        setupSyncSuccess('2330', count: 10);

        final progressMessages = <String>[];

        await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: [],
          marketCandidates: [],
          onProgress: progressMessages.add,
        );

        expect(progressMessages, isNotEmpty);
        expect(progressMessages.any((m) => m.contains('歷史資料')), isTrue);
      });
    });

    group('fresh database scenario', () {
      test('syncs popular stocks with only 1 day of data (fresh DB)', () async {
        // Fresh DB: 每檔股票只有今天 1 天資料
        // _hasEnoughDataForAge 會誤判為「剛上市」，但新增的 swingWindow guard 應觸發同步
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '2330': createPrices('2330', 1, firstDate: testDate),
          '2317': createPrices('2317', 1, firstDate: testDate),
        });
        setupSyncSuccess('2330', count: 250);
        setupSyncSuccess('2317', count: 250);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: ['2330', '2317'],
          marketCandidates: [],
        );

        expect(result.syncedCount, 500);
        expect(result.symbolsProcessed, 2);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2317',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });
    });

    group('_hasEnoughDataForAge', () {
      test('skips new stock with proportional data', () async {
        // Stock listed 100 days ago with 50 days of data
        // Expected: ~71 trading days, threshold: ~35 days
        // 50 >= 35, should skip
        final firstDate = testDate.subtract(const Duration(days: 100));

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '6547': createPrices('6547', 50, firstDate: firstDate),
        });

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['6547'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 0);
        expect(result.symbolsProcessed, 0);
      });

      test('syncs new stock with insufficient proportional data', () async {
        // Stock listed 100 days ago with only 10 days of data
        // Expected: ~71 trading days, threshold: ~35 days
        // 10 < 35, should sync
        final firstDate = testDate.subtract(const Duration(days: 100));

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '6547': createPrices('6547', 10, firstDate: firstDate),
        });
        setupSyncSuccess('6547', count: 60);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['6547'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 60);
        expect(result.symbolsProcessed, 1);
      });
    });

    group('_prioritizeSymbols', () {
      test('prioritizes watchlist over popular over others', () async {
        // Create 205 symbols that all need data
        // All have 0 data → avgMonthsPerSymbol ≈ 14
        // Dynamic maxSyncCount = ceil(300/14) = 22
        final allSymbols = List.generate(
          205,
          (i) => 'S${i.toString().padLeft(3, '0')}',
        );
        final watchlistSymbols = [
          'S200',
          'S201',
          'S202',
        ]; // last 3 are watchlist
        final popularSymbols = ['S203', 'S204']; // and 2 popular

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch(
          Map.fromEntries(
            allSymbols.map((s) => MapEntry(s, <DailyPriceEntry>[])),
          ),
        );

        // Mock getStocksBatch for market-aware prioritization
        when(() => mockDb.getStocksBatch(any())).thenAnswer(
          (_) async => {
            for (final s in allSymbols)
              s: StockMasterEntry(
                symbol: s,
                name: s,
                market: 'TWSE',
                isActive: true,
                updatedAt: testDate,
              ),
          },
        );

        // Setup sync for all
        for (final symbol in allSymbols) {
          setupSyncSuccess(symbol, count: 1);
        }

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: watchlistSymbols,
          popularStocks: popularSymbols,
          marketCandidates: allSymbols,
        );

        // 0-data symbols: dynamic maxSyncCount = ceil(300/14) = 22
        // 5 priority (3 watchlist + 2 popular) + 17 others = 22
        expect(result.symbolsProcessed, 22);
        expect(result.totalSymbolsNeeded, 205);

        // Watchlist symbols should always be synced
        for (final symbol in watchlistSymbols) {
          verify(
            () => mockPriceRepo.syncStockPrices(
              symbol,
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        }

        // Popular symbols should also be synced
        for (final symbol in popularSymbols) {
          verify(
            () => mockPriceRepo.syncStockPrices(
              symbol,
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        }
      });
    });

    // 2026-06 production regression：早期 _estimateAvgMonthsNeeded 對所有
    // 非零 symbol 一律假設 4 月，但 PriceRepository 實際走整個視窗的月份
    // 迴圈，partial-data symbol 若資料分佈零散會打很多 API。低估 budget
    // 讓 maxSyncCount 估高，跑到一半被 TWSE 限流（300 預算實打 1125 次）。
    //
    // 修正後 estimator 鏡像 price_repository 的「< minTradingDaysPerMonth
    // 月份算缺」邏輯，每 symbol 真實計算缺月。
    group('_estimateAvgMonthsNeeded fragmentation regression', () {
      test(
        'fragmented partial data caps syncCount to match real API budget',
        () async {
          // 200 檔每檔在 3 個非連續月各放 3 天 = 9 天總量 + 9 個月缺資料。
          //
          // 視窗 = testDate - historyRequiredDays = 約 250 天 (~12 個月)。
          // 9 天遠 < nearThreshold(180) → _findSymbolsNeedingData 不會早退。
          // firstTradeDate 在約 12 個月前 → _hasEnoughDataForAge 期望 ~85 天
          // (300×0.71×0.5)，9 天遠不足 → 進佇列。
          //
          // OLD estimator: 200 檔 × 4 月 = 800 → maxSyncCount = ceil(300/4) = 75
          //   會嘗試同步 75 檔，但真實 calls = 75 × 9 月 ≈ 675 → 超 budget 2.25 倍
          // NEW estimator: 200 檔 × 9 月 = 1800 → maxSyncCount = ceil(300/9) = 34
          //   只同步 ~34 檔，真實 calls ≈ 306 ≈ budget，不超

          final allSymbols = List.generate(
            200,
            (i) => 'F${i.toString().padLeft(3, '0')}',
          );

          // 每 symbol 在 3 個非連續月各放 3 天，oldest-first 排序（DAO 行為）
          List<DailyPriceEntry> fragmentedPrices(String symbol) {
            final out = <DailyPriceEntry>[];
            // 反向：先放最早 → 最新（符合 DAO `OrderingTerm.asc(date)`）
            for (final monthOffset in [10, 6, 2]) {
              // testDate.month - 10 = -9 → Dart 自動 normalize 到前一年
              final monthStart = DateTime(
                testDate.year,
                testDate.month - monthOffset,
                5,
              );
              for (var i = 0; i < 3; i++) {
                out.add(
                  DailyPriceEntry(
                    symbol: symbol,
                    date: monthStart.add(Duration(days: i)),
                    close: 100.0,
                  ),
                );
              }
            }
            return out;
          }

          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({
            for (final s in allSymbols) s: fragmentedPrices(s),
          });
          when(() => mockDb.getStocksBatch(any())).thenAnswer(
            (_) async => {
              for (final s in allSymbols)
                s: StockMasterEntry(
                  symbol: s,
                  name: s,
                  market: 'TWSE',
                  isActive: true,
                  updatedAt: testDate,
                ),
            },
          );
          for (final s in allSymbols) {
            setupSyncSuccess(s, count: 1);
          }

          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: [],
            popularStocks: [],
            marketCandidates: allSymbols,
          );

          expect(result.totalSymbolsNeeded, 200);

          // 核心斷言：修正後 maxSyncCount 應反映真實 API 成本（~9 月/檔）
          // 預期 symbolsProcessed ~34（300/9 budget），絕不應 ≥ 75（OLD bug 值）。
          // 用寬容區間避免月份邊界數字計算與測試環境差異產生 noise。
          expect(
            result.symbolsProcessed,
            lessThanOrEqualTo(45),
            reason:
                'maxSyncCount should cap to real API budget (~34), '
                'NOT old over-optimistic 75 from constant-4 partialMonths',
          );
          expect(
            result.symbolsProcessed,
            greaterThanOrEqualTo(20),
            reason:
                'cap should not be absurdly low — '
                'budget 300 / max(15) ≥ 20',
          );
        },
      );

      test(
        'zero-data symbol estimates full window (≈14 months) — not constant fallback',
        () async {
          // Fresh DB 場景對照組：完全沒資料的 symbol 應該估算成整個視窗
          // (~14 個月)，而不是被誤判成「partial」(舊 constant 4)。
          // 這個 case 在修法前後行為應一致，作為 sanity check。
          final allSymbols = List.generate(
            100,
            (i) => 'Z${i.toString().padLeft(3, '0')}',
          );
          setupSufficientDataSymbols([]);
          setupPriceHistoryBatch({for (final s in allSymbols) s: []});
          when(() => mockDb.getStocksBatch(any())).thenAnswer(
            (_) async => {
              for (final s in allSymbols)
                s: StockMasterEntry(
                  symbol: s,
                  name: s,
                  market: 'TWSE',
                  isActive: true,
                  updatedAt: testDate,
                ),
            },
          );
          for (final s in allSymbols) {
            setupSyncSuccess(s, count: 1);
          }

          final result = await syncer.syncHistoricalPrices(
            date: testDate,
            watchlistSymbols: [],
            popularStocks: [],
            marketCandidates: allSymbols,
          );

          // 100 檔 × ~14 月 → maxSyncCount = ceil(300/14) = 22。
          // 寬容區間：22 ± 2 涵蓋 9 / 10 月視窗的邊界。
          expect(result.totalSymbolsNeeded, 100);
          expect(
            result.symbolsProcessed,
            inInclusiveRange(18, 28),
            reason:
                'fresh DB: 100 stocks × ~14 months = ~1400 calls, '
                'budget 300 → maxSyncCount around 21-22',
          );
        },
      );
    });

    group('市場日快照回補（phase 0）', () {
      // testDate = 2025-01-15（週三）。窗內鄰近交易日：
      // 1/14（二）、1/13（一）、1/10（五）；1/11-12 為週末。
      final tue = DateTime(2025, 1, 14);
      final mon = DateTime(2025, 1, 13);

      StockMasterEntry stockEntry(String symbol, String market) =>
          StockMasterEntry(
            symbol: symbol,
            name: symbol,
            market: market,
            isActive: true,
            updatedAt: testDate,
          );

      List<StockMasterEntry> twseStocks(int n) =>
          List.generate(n, (i) => stockEntry('11$i', 'TWSE'));
      List<StockMasterEntry> tpexStocks(int n) =>
          List.generate(n, (i) => stockEntry('33$i', 'TPEx'));

      /// 測試用 syncer：市場日回補呼叫間不延遲（避免測試等待真實時間）
      late HistoricalPriceSyncer fastSyncer;

      /// phase 1（per-symbol）快速通過：無任何需求
      void setupEmptyPerSymbolPhase() {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({});
      }

      /// count 回應器：預設每日皆完整，[missingTwseDays] 內的日子缺漏
      ///
      /// 以 grouped 語意 stub（market → ymd → count）：缺漏日**不出現**在
      /// Map 中（真實 GROUP BY 只會產生 COUNT>=1 的組），scanner 以 ?? 0
      /// 處理缺鍵。
      void setupDayCounts({
        Set<DateTime> missingTwseDays = const {},
        int twseComplete = 10,
        int tpexComplete = 8,
      }) {
        when(
          () => mockDb.getPriceCountsByDayAndMarket(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((inv) async {
          final start = inv.namedArguments[#startDate] as DateTime;
          final end = inv.namedArguments[#endDate] as DateTime;
          final twse = <String, int>{};
          final tpex = <String, int>{};
          for (
            var d = DateTime(start.year, start.month, start.day);
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))
          ) {
            final key = DateContext.formatYmd(d);
            if (!missingTwseDays.contains(d)) twse[key] = twseComplete;
            tpex[key] = tpexComplete;
          }
          return {'TWSE': twse, 'TPEx': tpex};
        });
      }

      void setupTwseBackfill(int rowsPerDay) {
        when(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenAnswer((_) async => rowsPerDay);
      }

      setUp(() {
        fastSyncer = HistoricalPriceSyncer(
          database: mockDb,
          priceRepository: mockPriceRepo,
          marketDayCallDelay: Duration.zero,
        );
        when(
          () => mockDb.getStocksByMarket('TWSE'),
        ).thenAnswer((_) async => twseStocks(10));
        when(
          () => mockDb.getStocksByMarket('TPEx'),
        ).thenAnswer((_) async => tpexStocks(8));
        setupEmptyPerSymbolPhase();
      });

      test('缺漏市場日觸發整市場回補（新→舊、只補缺的市場）', () async {
        setupDayCounts(missingTwseDays: {tue, mon});
        setupTwseBackfill(800);

        final result = await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        final captured = verify(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: captureAny(named: 'date'),
            targetSymbols: captureAny(named: 'targetSymbols'),
          ),
        ).captured;
        // 兩次呼叫、新→舊
        expect(captured[0], tue);
        expect(captured[2], mon);
        // targetSymbols = 該市場全部股票
        expect(captured[1], twseStocks(10).map((s) => s.symbol).toSet());
        // TPEx 每日完整 → 不呼叫
        verifyNever(
          () => mockPriceRepo.backfillTpexPricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        );
        // 週末不列入缺漏檢查——上方 captured 斷言已證明只回補 tue/mon
        // （grouped 掃描下不再有 per-day 查詢可供 verifyNever）
        // 回補列數進 result（含 phase 1 early-return 路徑）
        expect(result.marketDayRows, 1600);
      });

      test('單次更新的回補呼叫數受上限保護、且由最近日開始', () async {
        setupDayCounts(
          missingTwseDays: {
            // 窗內全部日子都缺（用寬鬆 750 天涵蓋整個 lookback 窗）
            for (var i = 1; i <= 750; i++) testDate.subtract(Duration(days: i)),
          },
        );
        setupTwseBackfill(5);

        await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        final captured = verify(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: captureAny(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).captured;
        expect(
          captured.length,
          ApiConfig.historicalMarketDayMaxCallsPerRun,
          reason: '上限保護：單次更新最多補 N 個市場日',
        );
        expect(captured.first, tue, reason: '最近的缺漏交易日優先');
      });

      test('連續零筆中止（端點失效防護），且 phase 1 照常執行', () async {
        setupDayCounts(
          missingTwseDays: {
            for (var i = 1; i <= 750; i++) testDate.subtract(Duration(days: i)),
          },
        );
        setupTwseBackfill(0);

        final result = await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        verify(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).called(ApiConfig.historicalMarketDayMaxConsecutiveZeroDays);
        expect(result.marketDayRows, 0);
        // phase 1 未被 phase 0 中止
        verify(
          () => mockDb.getSymbolsWithSufficientData(
            minDays: any(named: 'minDays'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('RateLimit 中止 phase 0、不外拋、phase 1 照常執行', () async {
        setupDayCounts(missingTwseDays: {tue, mon});
        when(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenThrow(const RateLimitException());

        final result = await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        verify(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).called(1);
        expect(result.marketDayRows, 0);
        verify(
          () => mockDb.getSymbolsWithSufficientData(
            minDays: any(named: 'minDays'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('股票主檔為空（fresh DB）→ phase 0 全跳過', () async {
        when(() => mockDb.getStocksByMarket(any())).thenAnswer((_) async => []);

        final result = await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        verifyNever(
          () => mockDb.getPriceCountsByDayAndMarket(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
        verifyNever(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        );
        expect(result.marketDayRows, 0);
      });

      test('單日失敗（DatabaseException）不中斷後續日子', () async {
        setupDayCounts(missingTwseDays: {tue, mon});
        var call = 0;
        when(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenAnswer((_) async {
          call++;
          if (call == 1) throw const DatabaseException('單日失敗');
          return 700;
        });

        final result = await fastSyncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: [],
          marketCandidates: [],
        );

        verify(
          () => mockPriceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).called(2);
        expect(result.marketDayRows, 700);
      });
    });
  });
}
