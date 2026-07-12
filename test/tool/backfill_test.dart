// Stage 3 Commit C1 — tool/backfill.dart unit tests
//
// 用 mocktail mock 四個 repository interface 驗證 Backfiller 的行為：
// - Phase 順序正確
// - 單 symbol 失敗被記入 failedSymbols 但不中斷迴圈
// - RateLimitException / NetworkException 立即 rethrow
// - Dry-run 不呼叫任何 sync method
// - Symbols whitelist 優先於 stock master 查詢
//
// 不測試真實 TWSE/FinMind API — 那些由 operational run 驗證。
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/fundamental_repository.dart';
import 'package:afterclose/domain/repositories/institutional_repository.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';
import 'package:afterclose/domain/repositories/stock_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tool/backfill.dart';

class _MockDb extends Mock implements AppDatabase {}

class _MockStockRepo extends Mock implements IStockRepository {}

class _MockPriceRepo extends Mock implements IPriceRepository {}

class _MockInstitutionalRepo extends Mock implements IInstitutionalRepository {}

class _MockFundamentalRepo extends Mock implements IFundamentalRepository {}

void main() {
  late _MockDb db;
  late _MockStockRepo stockRepo;
  late _MockPriceRepo priceRepo;
  late _MockInstitutionalRepo institutionalRepo;
  late _MockFundamentalRepo fundamentalRepo;
  late BackfillDeps deps;
  late List<String> logs;

  setUpAll(() {
    registerFallbackValue(DateTime(2024, 1, 1));
  });

  setUp(() {
    db = _MockDb();
    stockRepo = _MockStockRepo();
    priceRepo = _MockPriceRepo();
    institutionalRepo = _MockInstitutionalRepo();
    fundamentalRepo = _MockFundamentalRepo();

    deps = BackfillDeps(
      db: db,
      stockRepo: stockRepo,
      priceRepo: priceRepo,
      institutionalRepo: institutionalRepo,
      fundamentalRepo: fundamentalRepo,
    );

    logs = [];

    // Defaults — 所有 sync method 預設回傳 0（no-op success）
    when(() => stockRepo.syncStockList()).thenAnswer((_) async => 1300);
    when(
      () => priceRepo.syncStockPrices(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 100);
    when(
      () => institutionalRepo.syncInstitutionalData(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 100);
    when(
      () => fundamentalRepo.syncMonthlyRevenue(
        symbol: any(named: 'symbol'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 24);
    when(
      () => fundamentalRepo.syncFinancialStatements(
        symbol: any(named: 'symbol'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 8);
    when(
      () => fundamentalRepo.syncValuationData(
        symbol: any(named: 'symbol'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 500);

    // Default: stock_master 沒 cache 任何 symbol → 全部 fallback 為 TWSE。
    // 個別測試需要 TPEx batch path 時自行 override。
    when(
      () => db.getStocksBatch(any()),
    ).thenAnswer((_) async => <String, StockMasterEntry>{});
    // Default: TWSE / TPEx batch backfill 預設 no-op（每天 0 rows）。
    // 個別測試要驗 batch path 時自行 override。
    when(
      () => priceRepo.backfillTwsePricesByDate(
        date: any(named: 'date'),
        targetSymbols: any(named: 'targetSymbols'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => priceRepo.backfillTpexPricesByDate(
        date: any(named: 'date'),
        targetSymbols: any(named: 'targetSymbols'),
      ),
    ).thenAnswer((_) async => 0);
    // Default: institutional batch backfill 預設 no-op（每天 0 rows）。
    when(
      () => institutionalRepo.backfillInstitutionalByDate(
        date: any(named: 'date'),
        targetSymbols: any(named: 'targetSymbols'),
      ),
    ).thenAnswer((_) async => 0);
    // Default: 該日尚無既有價格 rows → 不觸發 per-day skip
    when(
      () => db.countPricesByDateAndMarket(any(), any()),
    ).thenAnswer((_) async => 0);
  });

  BackfillConfig makeConfig({
    List<String>? symbols = const ['2330', '2317', '2454'],
    bool dryRun = false,
    DateTime? endDateOverride,
  }) {
    return BackfillConfig(
      dbPath: ':memory:', // not actually opened in unit test
      years: 2,
      finMindToken: 'test-token',
      symbolsWhitelist: symbols,
      dryRun: dryRun,
      endDateOverride: endDateOverride,
      skipStockListSync: true, // 避免 unit test 呼叫 stock master sync
      // 跳過 inter-day delay：500 trading days × 1.5s 預設會讓單測 timeout
      interDayDelayMs: 0,
    );
  }

  Backfiller makeBackfiller(BackfillConfig config) {
    return Backfiller(config: config, deps: deps, logger: logs.add);
  }

  group('Backfiller happy path', () {
    test('executes 5 phases in order with correct symbol whitelist', () async {
      final backfiller = makeBackfiller(makeConfig());
      final result = await backfiller.run();

      // Phase 1.5 後 prices:twse 也改 per-day batch（與 prices:tpex 對稱）。
      // 預設 stockMap 為空 → 全部 symbol 走 TWSE 路徑 → prices:tpex 不發。
      expect(result.phases.length, 5);
      expect(result.phases.map((p) => p.phase).toList(), [
        'prices:twse',
        'institutional',
        'revenue',
        'financial',
        'valuation',
      ]);

      // prices:twse batch 應該以包含全部 3 個 symbol 的 targetSymbols 被呼叫
      final captured = verify(
        () => priceRepo.backfillTwsePricesByDate(
          date: any(named: 'date'),
          targetSymbols: captureAny(named: 'targetSymbols'),
        ),
      ).captured;
      expect(captured, isNotEmpty);
      final targets = captured.first as Set<String>;
      expect(targets, containsAll(['2330', '2317', '2454']));

      // 個別 per-symbol phase 仍然每個 symbol 呼叫一次（revenue 範例）
      verify(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('aggregates row counts across phases', () async {
      final backfiller = makeBackfiller(makeConfig());
      final result = await backfiller.run();

      // Per-symbol phases × 3 symbols：
      //   revenue       24/symbol × 3 = 72
      //   financial      8/symbol × 3 = 24
      //   valuation    500/symbol × 3 = 1500
      // Per-day batch phases (預設 stub 回 0 rows)：
      //   prices:twse   0 → 連續 0 rows 觸發 fail-fast abort（見下）
      //   prices:tpex   0 (no TPEx symbols)
      //   institutional 0 (Phase 2 改 batch)
      // Total: 72 + 24 + 1500 = 1596
      expect(result.totalRows, 1596);
      // 2026-07-11 起：price batch phase 連續 0 rows 視為端點失效 abort，
      // 會記進 failedSymbols → hasFailures 為 true（可稽核、非靜默）。
      expect(result.hasFailures, isTrue);
    });

    test('passes consistent startDate/endDate across all phases', () async {
      // 經 Phase 1.5 後 prices 改 per-day batch，不再傳 startDate/endDate
      // 給 priceRepo。改觀察 fundamental phase（仍 per-symbol）的 startDate/
      // endDate 區間是否為 2 年。
      DateTime? capturedStart;
      DateTime? capturedEnd;

      when(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
        ),
      ).thenAnswer((invocation) async {
        capturedStart = invocation.namedArguments[#startDate] as DateTime;
        capturedEnd = invocation.namedArguments[#endDate] as DateTime;
        return 24;
      });

      final backfiller = makeBackfiller(makeConfig(symbols: const ['2330']));
      await backfiller.run();

      expect(capturedStart, isNotNull);
      expect(capturedEnd, isNotNull);
      // 2 年 × 365 天 = 730 天
      final span = capturedEnd!.difference(capturedStart!);
      expect(span.inDays, inInclusiveRange(720, 740));
    });
  });

  group('Backfiller error isolation', () {
    test(
      'individual symbol failure does not abort the phase (per-symbol phase)',
      () async {
        // Phase 1.5 後 prices 是 batch，per-symbol 錯誤隔離邏輯只剩
        // fundamental phases (revenue/financial/valuation)。用 revenue 驗。
        when(
          () => fundamentalRepo.syncMonthlyRevenue(
            symbol: '2317',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(Exception('API 500'));

        final backfiller = makeBackfiller(makeConfig());
        final result = await backfiller.run();

        final revPhase = result.phases.firstWhere((p) => p.phase == 'revenue');
        expect(revPhase.symbolsProcessed, 3);
        expect(revPhase.symbolsSucceeded, 2);
        expect(revPhase.failedSymbols, ['2317']);

        // 後續 phase 仍然執行
        expect(result.phases.any((p) => p.phase == 'valuation'), isTrue);
        verify(
          () => fundamentalRepo.syncValuationData(
            symbol: '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      },
    );

    test(
      'RateLimitException aborts immediately without running next phase',
      () async {
        // 用 revenue (per-symbol phase) 模擬 RateLimit。financial / valuation
        // 不應被執行。
        when(
          () => fundamentalRepo.syncMonthlyRevenue(
            symbol: '2317',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(const RateLimitException('API quota exceeded'));

        final backfiller = makeBackfiller(makeConfig());

        await expectLater(backfiller.run(), throwsA(isA<RateLimitException>()));

        verifyNever(
          () => fundamentalRepo.syncFinancialStatements(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      },
    );

    test('NetworkException aborts immediately', () async {
      when(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const NetworkException('connection refused'));

      final backfiller = makeBackfiller(makeConfig());

      await expectLater(backfiller.run(), throwsA(isA<NetworkException>()));
      verifyNever(
        () => fundamentalRepo.syncFinancialStatements(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });
  });

  group('Backfiller dry run', () {
    test(
      'prints plan and returns empty phases without calling sync methods',
      () async {
        final backfiller = makeBackfiller(makeConfig(dryRun: true));
        final result = await backfiller.run();

        expect(result.phases, isEmpty);
        expect(result.totalRows, 0);

        verifyNever(
          () => priceRepo.syncStockPrices(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
        verifyNever(
          () => fundamentalRepo.syncMonthlyRevenue(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );

        // Dry run log 應包含 'DRY RUN PLAN' 或類似字串
        expect(logs.any((l) => l.contains('Dry run')), isTrue);
      },
    );
  });

  group('Backfiller symbol resolution', () {
    test('uses whitelist when provided', () async {
      final backfiller = makeBackfiller(
        makeConfig(symbols: const ['2330', '2317']),
      );
      await backfiller.run();

      // Phase 1.5 後 prices 走 batch，只能透過 per-symbol 的 fundamental
      // phase 驗證 symbol 範圍。revenue 應該被精準呼叫兩次（2330, 2317），
      // 不會碰到 2454。
      verify(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verify(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verifyNever(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: '2454',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );

      // Stock master getAllStocks 不該被呼叫
      verifyNever(() => stockRepo.getAllStocks());
    });

    test('falls back to stock master when whitelist is null', () async {
      when(() => stockRepo.getAllStocks()).thenAnswer(
        (_) async => [
          StockMasterEntry(
            symbol: '9999',
            name: 'Fallback',
            market: 'TWSE',
            industry: 'Test',
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final backfiller = makeBackfiller(makeConfig(symbols: null));
      await backfiller.run();

      verify(() => stockRepo.getAllStocks()).called(1);
      // 透過 revenue（per-symbol phase）驗證 fallback symbol 真的進到 pipeline
      verify(
        () => fundamentalRepo.syncMonthlyRevenue(
          symbol: '9999',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });

  // ============================================================
  // Stage 1 TPEx-batch refactor: prices phase 拆 TWSE / TPEx
  //
  // 確保正確性的核心測試：依市場分流是否真的走對路徑、
  // TPEx 不再呼叫 syncStockPrices（per-symbol FinMind 路徑）。
  // ============================================================
  group('Backfiller TPEx batch path', () {
    test(
      'TWSE symbols go to backfillTwsePricesByDate batch (not syncStockPrices)',
      () async {
        // Phase 1.5 確保上市股票也走 per-day batch，不再 hit TWSE
        // per-symbol IP rate limit。
        when(
          () => priceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenAnswer((_) async => 7);

        final backfiller = makeBackfiller(makeConfig(symbols: const ['2330']));
        final result = await backfiller.run();

        final pricePhase = result.phases.firstWhere(
          (p) => p.phase == 'prices:twse',
        );
        expect(
          pricePhase.rowsInserted,
          greaterThan(0),
          reason: 'batch path 真的有寫入',
        );

        // 核心保證：syncStockPrices 不再被 backfill 呼叫（FinMind / TWSE 月度
        // 兩條 per-symbol rate-limited 路徑都被繞開）
        verifyNever(
          () => priceRepo.syncStockPrices(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );

        // targetSymbols 包含我們指定的 symbol
        final captured = verify(
          () => priceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: captureAny(named: 'targetSymbols'),
          ),
        ).captured;
        expect(captured, isNotEmpty);
        final targets = captured.first as Set<String>;
        expect(targets, contains('2330'));
      },
    );

    test(
      'TWSE batch path RateLimitException aborts backfill (no institutional phase runs)',
      () async {
        when(
          () => priceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenThrow(const RateLimitException());

        final backfiller = makeBackfiller(makeConfig(symbols: const ['2330']));

        await expectLater(backfiller.run(), throwsA(isA<RateLimitException>()));

        // institutional / fundamental phases 都不該跑
        verifyNever(
          () => institutionalRepo.backfillInstitutionalByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        );
        verifyNever(
          () => fundamentalRepo.syncMonthlyRevenue(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      },
    );

    test(
      'TPEx symbols go to backfillTpexPricesByDate (not syncStockPrices)',
      () async {
        // stock_master 標記 4488 為 TPEx 上櫃，2330 為 TWSE 上市
        when(() => db.getStocksBatch(any())).thenAnswer(
          (_) async => {
            '4488': StockMasterEntry(
              symbol: '4488',
              name: 'TPEx Stock',
              market: 'TPEx',
              industry: 'Test',
              isActive: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
            '2330': StockMasterEntry(
              symbol: '2330',
              name: 'TSMC',
              market: 'TWSE',
              industry: 'Test',
              isActive: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
          },
        );

        when(
          () => priceRepo.backfillTpexPricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenAnswer((_) async => 1);

        final backfiller = makeBackfiller(
          makeConfig(symbols: ['2330', '4488']),
        );
        final result = await backfiller.run();

        // 應該同時存在 prices:twse 與 prices:tpex 兩個 phase
        final phaseNames = result.phases.map((p) => p.phase).toList();
        expect(phaseNames, contains('prices:twse'));
        expect(phaseNames, contains('prices:tpex'));

        // Phase 1.5 後 2330 不再走 syncStockPrices，而是 batch 路徑
        verify(
          () => priceRepo.backfillTwsePricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).called(greaterThan(0));

        // 任何 symbol 都不該走 syncStockPrices — 完全脫離 per-symbol
        // rate-limited 路徑（FinMind / TWSE 月度兩個都繞開）
        verifyNever(
          () => priceRepo.syncStockPrices(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );

        // TPEx batch 必須在 targetSymbols 中包含 4488
        final captured = verify(
          () => priceRepo.backfillTpexPricesByDate(
            date: any(named: 'date'),
            targetSymbols: captureAny(named: 'targetSymbols'),
          ),
        ).captured;
        expect(captured, isNotEmpty);
        final targets = captured.first as Set<String>;
        expect(targets, contains('4488'));
        expect(
          targets.contains('2330'),
          isFalse,
          reason: 'TPEx batch 不該包含 TWSE symbol',
        );
      },
    );

    test(
      'TPEx batch only emits prices:twse phase when no TPEx symbols exist',
      () async {
        when(() => db.getStocksBatch(any())).thenAnswer(
          (_) async => {
            '2330': StockMasterEntry(
              symbol: '2330',
              name: 'TSMC',
              market: 'TWSE',
              industry: 'Test',
              isActive: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
          },
        );

        final backfiller = makeBackfiller(makeConfig(symbols: ['2330']));
        final result = await backfiller.run();

        final phaseNames = result.phases.map((p) => p.phase).toList();
        expect(phaseNames, contains('prices:twse'));
        expect(
          phaseNames.contains('prices:tpex'),
          isFalse,
          reason: 'no TPEx symbols → no prices:tpex phase',
        );
        verifyNever(
          () => priceRepo.backfillTpexPricesByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        );
      },
    );

    test('institutional phase goes to backfillInstitutionalByDate '
        '(not syncInstitutionalData)', () async {
      // 每天回傳 5 筆，確認 batch path 是真實被呼叫且 result.totalRows 來自它
      when(
        () => institutionalRepo.backfillInstitutionalByDate(
          date: any(named: 'date'),
          targetSymbols: any(named: 'targetSymbols'),
        ),
      ).thenAnswer((_) async => 5);

      final backfiller = makeBackfiller(makeConfig(symbols: const ['2330']));
      final result = await backfiller.run();

      // 確認 institutional phase 出現且來自 batch path
      final instPhase = result.phases.firstWhere(
        (p) => p.phase == 'institutional',
      );
      expect(
        instPhase.rowsInserted,
        greaterThan(0),
        reason: 'batch path 真的有寫入',
      );

      // 核心保證：syncInstitutionalData (per-symbol FinMind path) 不該被呼叫
      verifyNever(
        () => institutionalRepo.syncInstitutionalData(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );

      // targetSymbols 應包含我們指定的 symbol
      final captured = verify(
        () => institutionalRepo.backfillInstitutionalByDate(
          date: any(named: 'date'),
          targetSymbols: captureAny(named: 'targetSymbols'),
        ),
      ).captured;
      expect(captured, isNotEmpty);
      final targets = captured.first as Set<String>;
      expect(targets, contains('2330'));
    });

    test(
      'institutional batch RateLimitException aborts backfill (no fundamental phases run)',
      () async {
        when(
          () => institutionalRepo.backfillInstitutionalByDate(
            date: any(named: 'date'),
            targetSymbols: any(named: 'targetSymbols'),
          ),
        ).thenThrow(const RateLimitException());

        final backfiller = makeBackfiller(makeConfig());

        await expectLater(backfiller.run(), throwsA(isA<RateLimitException>()));

        // institutional 死掉後 revenue / financial / valuation 都不該跑
        verifyNever(
          () => fundamentalRepo.syncMonthlyRevenue(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
        verifyNever(
          () => fundamentalRepo.syncFinancialStatements(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
        verifyNever(
          () => fundamentalRepo.syncValuationData(
            symbol: any(named: 'symbol'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      },
    );

    test('TPEx batch path RateLimitException aborts backfill', () async {
      when(() => db.getStocksBatch(any())).thenAnswer(
        (_) async => {
          '4488': StockMasterEntry(
            symbol: '4488',
            name: 'TPEx',
            market: 'TPEx',
            industry: 'Test',
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );
      when(
        () => priceRepo.backfillTpexPricesByDate(
          date: any(named: 'date'),
          targetSymbols: any(named: 'targetSymbols'),
        ),
      ).thenThrow(const RateLimitException());

      final backfiller = makeBackfiller(makeConfig(symbols: ['4488']));

      await expectLater(backfiller.run(), throwsA(isA<RateLimitException>()));

      // 不可進入下一個 phase (institutional)
      verifyNever(
        () => institutionalRepo.syncInstitutionalData(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });
  });

  group('Backfiller per-day 日期正規化 + 端點失效 fail-fast', () {
    test('guard 與 API 呼叫的日期都是午夜（now 帶時間分量不得洩漏）', () async {
      // endDate 預設 DateTime.now() 帶時間分量；不正規化的話
      // countPricesByDateAndMarket 的 TEXT 等值比對永遠 miss → skip-guard 全滅
      final backfiller = makeBackfiller(
        makeConfig(endDateOverride: DateTime(2026, 7, 10, 13, 36, 19, 123)),
      );
      await backfiller.run();

      final guardDates = verify(
        () => db.countPricesByDateAndMarket(captureAny(), any()),
      ).captured.cast<DateTime>();
      expect(guardDates, isNotEmpty);
      for (final d in guardDates) {
        expect(
          (d.hour, d.minute, d.second, d.millisecond),
          (0, 0, 0, 0),
          reason: 'guard 日期必須正規化到午夜（實得 $d）',
        );
      }
    });

    test('連續多個交易日回 0 rows → abort phase（端點忽略 date 參數 fail-fast）', () async {
      // 預設 stub 每天回 0 → 2 年 ~500 個交易日不該全打一遍
      final backfiller = makeBackfiller(makeConfig());
      await backfiller.run();

      verify(
        () => priceRepo.backfillTwsePricesByDate(
          date: any(named: 'date'),
          targetSymbols: any(named: 'targetSymbols'),
        ),
      ).called(lessThanOrEqualTo(12)); // 閾值 10 + 邊際
      expect(logs.join('\n'), contains('連續'), reason: 'abort 時要留下可診斷的訊息');
    });
  });

  group('Backfiller per-day skip-existing（resume 不重打 API）', () {
    test('該日該市場已有足量價格 rows → 跳過、完全不打 TWSE API', () async {
      // 3 個 target symbols、每天已有 3 筆（100% ≥ 80% 門檻）
      when(
        () => db.countPricesByDateAndMarket(any(), any()),
      ).thenAnswer((_) async => 3);

      final backfiller = makeBackfiller(makeConfig());
      await backfiller.run();

      verifyNever(
        () => priceRepo.backfillTwsePricesByDate(
          date: any(named: 'date'),
          targetSymbols: any(named: 'targetSymbols'),
        ),
      );
    });

    test('該日 rows 不足門檻 → 照常打 API', () async {
      // 只有 1/3（33% < 80%）→ 不能 skip（可能是 FinMind 補的部分子集）
      when(
        () => db.countPricesByDateAndMarket(any(), any()),
      ).thenAnswer((_) async => 1);

      final backfiller = makeBackfiller(makeConfig());
      await backfiller.run();

      verify(
        () => priceRepo.backfillTwsePricesByDate(
          date: any(named: 'date'),
          targetSymbols: any(named: 'targetSymbols'),
        ),
      ).called(greaterThan(0));
    });
  });
}
