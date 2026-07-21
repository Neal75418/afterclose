// FundamentalSyncer 自選股月營收歷史回補
//
// 全市場批次同步（TWSE/TPEx OpenData）只涵蓋「最新一個月」，歷史月份僅在
// 使用者開過個股詳情頁時按需回補——導致「近 3 月均年增」（使用者選股法則
// L2 門檻）對絕大多數自選股算不出來。本方法讓自選股具備該欄位所需資料：
// 缺近 3 個月完整 YoY 的 symbol 走 FinMind 逐檔回補 ~16 個月（涵蓋前一年
// 同月，讓 calculateGrowthRates 算得出 YoY）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/domain/services/update/fundamental_syncer.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFundamentalRepository extends Mock implements FundamentalRepository {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  late MockAppDatabase mockDb;
  late MockFundamentalRepository mockFundRepo;
  late FundamentalSyncer syncer;

  // 2026-07-15（>10 日）→ 應已公布的最新月 = 2026-06，近 3 月 = 4/5/6 月
  final now = DateTime(2026, 7, 15);

  WatchlistEntry watch(String symbol) =>
      WatchlistEntry(symbol: symbol, createdAt: DateTime(2026, 1, 1));

  MonthlyRevenueEntry rev(
    String symbol,
    int year,
    int month, {
    double? yoy = 30.0,
  }) {
    return MonthlyRevenueEntry(
      symbol: symbol,
      date: DateTime(year, month),
      revenueYear: year,
      revenueMonth: month,
      revenue: 100000,
      yoyGrowth: yoy,
    );
  }

  setUp(() {
    mockDb = MockAppDatabase();
    mockFundRepo = MockFundamentalRepository();
    syncer = FundamentalSyncer(
      database: mockDb,
      fundamentalRepository: mockFundRepo,
      clock: _FixedClock(now),
    );

    when(
      () => mockFundRepo.syncMonthlyRevenue(
        symbol: any(named: 'symbol'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 16);
  });

  group('syncWatchlistRevenueHistory', () {
    test('自選股為空 → 0，不打 API', () async {
      when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);

      final count = await syncer.syncWatchlistRevenueHistory();

      expect(count, 0);
      verifyNever(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('近 3 個應公布月皆有 YoY → 冪等跳過，不打 API', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer(
        (_) async => {
          '2330': [
            rev('2330', 2026, 6),
            rev('2330', 2026, 5),
            rev('2330', 2026, 4),
          ],
        },
      );

      final count = await syncer.syncWatchlistRevenueHistory();

      expect(count, 0);
      verifyNever(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('只有最新一月（全市場批次的典型狀態）→ 回補該檔 ~16 個月', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer(
        (_) async => {
          '2330': [rev('2330', 2026, 6)],
        },
      );

      final count = await syncer.syncWatchlistRevenueHistory();

      expect(count, 16);
      final captured = verify(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
        ),
      ).captured;
      final start = captured[0] as DateTime;
      final end = captured[1] as DateTime;
      // 範圍必須涵蓋「近 3 月的前一年同月」（2025-04）才能算 YoY
      expect(start.isBefore(DateTime(2025, 4, 2)), isTrue);
      expect(end.isAfter(DateTime(2026, 6, 30)), isTrue);
    });

    test('近 3 月存在但 YoY 有缺值 → 視為 needy 回補', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer(
        (_) async => {
          '2330': [
            rev('2330', 2026, 6, yoy: null),
            rev('2330', 2026, 5),
            rev('2330', 2026, 4),
          ],
        },
      );

      await syncer.syncWatchlistRevenueHistory();

      verify(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('資料停在舊月份（非近 3 應公布月）→ 視為 needy 回補', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer(
        (_) async => {
          '2330': [
            rev('2330', 2026, 3),
            rev('2330', 2026, 2),
            rev('2330', 2026, 1),
          ],
        },
      );

      await syncer.syncWatchlistRevenueHistory();

      verify(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('ETF（00 開頭）無營收 → 過濾不回補', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('0050'), watch('00878')]);

      final count = await syncer.syncWatchlistRevenueHistory();

      expect(count, 0);
      verifyNever(() => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3));
      verifyNever(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('RateLimitException → rethrow（讓 coordinator 停止流程）', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer((_) async => {});
      when(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('FinMind 配額用盡'));

      expect(
        () => syncer.syncWatchlistRevenueHistory(),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('單檔 generic 失敗 → 記 warning 續跑其他檔（不中斷）', () async {
      when(
        () => mockDb.getWatchlist(),
      ).thenAnswer((_) async => [watch('2330'), watch('2317')]);
      when(
        () => mockDb.getRecentMonthlyRevenueBatch(any(), months: 3),
      ).thenAnswer((_) async => {});
      when(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('boom'));

      final count = await syncer.syncWatchlistRevenueHistory();

      expect(count, 16); // 2317 仍成功
      verify(
        () => mockFundRepo.syncMonthlyRevenue(
          symbol: '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });
}
