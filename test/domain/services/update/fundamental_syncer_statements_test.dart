// FundamentalSyncer 財報段 — 批次 freshness 預篩
//
// 2026-07-15 儀表實測：步驟 4.6→4.7 花 7.1 秒但「損益=0、資負=已快取」
// ——什麼都沒抓。成分：54 檔 × 2 表的**逐檔** MAX(date) freshness 查詢
// （isolate roundtrip 累積）+ chunk 之間 500ms 的無條件睡眠（與法人節流
// 同款病：sleep 保護不會發生的 API 呼叫）。
//
// 修法：chunk 前先用**一次** GROUP BY 批次查詢拿全部 symbols 的最新
// 季度，配合 TaiwanCalendar.expectedLatestReportQuarter 預篩出真正需要
// 同步的檔；穩態 needy 為空 → 零逐檔查詢、零睡眠。repo 內的逐檔
// freshness 檢查保留（對 needy 是雙重保險，成本可忽略）。
// 預篩查詢失敗 → fail-open 回全清單（退回舊行為，不漏抓）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/domain/services/update/fundamental_syncer.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFundamentalRepository extends Mock implements FundamentalRepository {}

class MockMarketDataRepository extends Mock implements MarketDataRepository {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  late MockAppDatabase mockDb;
  late MockFundamentalRepository mockFundRepo;
  late MockMarketDataRepository mockMarketRepo;
  late FundamentalSyncer syncer;

  // 2026-07-15 → 預期最新季 = 2026 Q1（起始 1/1）
  final freshDate = DateTime(2026, 3, 31); // Q1 截止日，不早於 1/1 → 新鮮
  final staleDate = DateTime(2025, 12, 31); // 早於 1/1 → 缺最新季

  setUp(() {
    mockDb = MockAppDatabase();
    mockFundRepo = MockFundamentalRepository();
    mockMarketRepo = MockMarketDataRepository();
    syncer = FundamentalSyncer(
      database: mockDb,
      fundamentalRepository: mockFundRepo,
      marketDataRepository: mockMarketRepo,
      clock: _FixedClock(DateTime(2026, 7, 15)),
    );

    when(
      () => mockFundRepo.syncFinancialStatements(
        symbol: any(named: 'symbol'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 100);
    when(
      () => mockMarketRepo.syncBalanceSheet(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 100);
  });

  group('損益表批次預篩', () {
    test('穩態全新鮮 → 一次批次查詢、零逐檔呼叫', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'INCOME'),
      ).thenAnswer(
        (_) async => {'2330': freshDate, '2317': freshDate, '1301': freshDate},
      );

      final count = await syncer.syncFinancialStatements(
        symbols: ['2330', '2317', '1301'],
      );

      expect(count, 0);
      verify(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'INCOME'),
      ).called(1);
      verifyNever(
        () => mockFundRepo.syncFinancialStatements(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('部分缺最新季 → 只抓 needy（stale + 無資料）', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'INCOME'),
      ).thenAnswer(
        (_) async => {'2330': freshDate, '2317': staleDate}, // 1301 無資料
      );

      await syncer.syncFinancialStatements(symbols: ['2330', '2317', '1301']);

      verifyNever(
        () => mockFundRepo.syncFinancialStatements(
          symbol: '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
      verify(
        () => mockFundRepo.syncFinancialStatements(
          symbol: '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
      verify(
        () => mockFundRepo.syncFinancialStatements(
          symbol: '1301',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });

    test('批次查詢失敗 → fail-open 全抓（repo 逐檔檢查仍把關）', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'INCOME'),
      ).thenAnswer((_) async => throw const DatabaseException('查詢失敗'));

      await syncer.syncFinancialStatements(symbols: ['2330', '2317']);

      verify(
        () => mockFundRepo.syncFinancialStatements(
          symbol: any(named: 'symbol'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(2);
    });

    test('ETF 先剔除再預篩（不進批次查詢）', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'INCOME'),
      ).thenAnswer((_) async => {'2330': freshDate});

      await syncer.syncFinancialStatements(symbols: ['2330', '0050', '00878']);

      final captured =
          verify(
                () => mockDb.getLatestFinancialDataDatesBatch(
                  captureAny(),
                  'INCOME',
                ),
              ).captured.single
              as List<String>;
      expect(captured, ['2330']);
    });
  });

  group('資產負債表批次預篩', () {
    test('穩態全新鮮 → 零逐檔呼叫、回 null（皆已快取語意）', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'BALANCE'),
      ).thenAnswer((_) async => {'2330': freshDate, '2317': freshDate});

      final count = await syncer.syncBalanceSheets(symbols: ['2330', '2317']);

      expect(count, isNull);
      verifyNever(
        () => mockMarketRepo.syncBalanceSheet(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('缺最新季 → 只抓 needy', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), 'BALANCE'),
      ).thenAnswer((_) async => {'2330': freshDate, '2317': staleDate});

      await syncer.syncBalanceSheets(symbols: ['2330', '2317']);

      verifyNever(
        () => mockMarketRepo.syncBalanceSheet(
          '2330',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
      verify(
        () => mockMarketRepo.syncBalanceSheet(
          '2317',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });
}
