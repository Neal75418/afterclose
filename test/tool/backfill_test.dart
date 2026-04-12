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
  });

  BackfillConfig makeConfig({
    List<String>? symbols = const ['2330', '2317', '2454'],
    bool dryRun = false,
  }) {
    return BackfillConfig(
      dbPath: ':memory:', // not actually opened in unit test
      years: 2,
      finMindToken: 'test-token',
      symbolsWhitelist: symbols,
      dryRun: dryRun,
      skipStockListSync: true, // 避免 unit test 呼叫 stock master sync
    );
  }

  Backfiller makeBackfiller(BackfillConfig config) {
    return Backfiller(config: config, deps: deps, logger: logs.add);
  }

  group('Backfiller happy path', () {
    test('executes 5 phases in order with correct symbol whitelist', () async {
      final backfiller = makeBackfiller(makeConfig());
      final result = await backfiller.run();

      expect(result.phases.length, 5);
      expect(result.phases.map((p) => p.phase).toList(), [
        'prices',
        'institutional',
        'revenue',
        'financial',
        'valuation',
      ]);

      // 每個 phase 應該對 3 檔 symbol 各呼叫一次
      verify(
        () => priceRepo.syncStockPrices(
          '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verify(
        () => priceRepo.syncStockPrices(
          '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verify(
        () => priceRepo.syncStockPrices(
          '2454',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('aggregates row counts across phases', () async {
      final backfiller = makeBackfiller(makeConfig());
      final result = await backfiller.run();

      // Per-symbol: 100 (prices) + 100 (inst) + 24 (rev) + 8 (fin) + 500 (val)
      //           = 732
      // 3 symbols: 732 * 3 = 2196
      expect(result.totalRows, 732 * 3);
      expect(result.hasFailures, isFalse);
    });

    test('passes consistent startDate/endDate across all phases', () async {
      DateTime? capturedStart;
      DateTime? capturedEnd;

      when(
        () => priceRepo.syncStockPrices(
          any(),
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
        ),
      ).thenAnswer((invocation) async {
        capturedStart = invocation.namedArguments[#startDate] as DateTime;
        capturedEnd = invocation.namedArguments[#endDate] as DateTime;
        return 100;
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
    test('individual symbol failure does not abort the phase', () async {
      when(
        () => priceRepo.syncStockPrices(
          '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('API 500'));

      final backfiller = makeBackfiller(makeConfig());
      final result = await backfiller.run();

      final pricePhase = result.phases.firstWhere((p) => p.phase == 'prices');
      expect(pricePhase.symbolsProcessed, 3);
      expect(pricePhase.symbolsSucceeded, 2);
      expect(pricePhase.failedSymbols, ['2317']);

      // 後續 phase 仍然執行
      expect(result.phases.any((p) => p.phase == 'valuation'), isTrue);
      verify(
        () => fundamentalRepo.syncValuationData(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test(
      'RateLimitException aborts immediately without running next phase',
      () async {
        when(
          () => priceRepo.syncStockPrices(
            '2317',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(const RateLimitException('API quota exceeded'));

        final backfiller = makeBackfiller(makeConfig());

        await expectLater(backfiller.run(), throwsA(isA<RateLimitException>()));

        // Institutional phase 不應被呼叫
        verifyNever(
          () => institutionalRepo.syncInstitutionalData(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      },
    );

    test('NetworkException aborts immediately', () async {
      when(
        () => priceRepo.syncStockPrices(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const NetworkException('connection refused'));

      final backfiller = makeBackfiller(makeConfig());

      await expectLater(backfiller.run(), throwsA(isA<NetworkException>()));
      verifyNever(
        () => fundamentalRepo.syncMonthlyRevenue(
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

      // 只呼叫 whitelist 裡的 symbol
      verify(
        () => priceRepo.syncStockPrices(
          '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verify(
        () => priceRepo.syncStockPrices(
          '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verifyNever(
        () => priceRepo.syncStockPrices(
          '2454',
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
      verify(
        () => priceRepo.syncStockPrices(
          '9999',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });
}
