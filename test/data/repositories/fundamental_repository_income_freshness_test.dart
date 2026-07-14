// 損益表新鮮度檢查 — 發布行事曆感知
//
// 2026-07-14 實測 bug：原檢查為「最新資料距今 < 60 天才算新鮮」，但
// financial_data 的日期是**季度截止日**（如 Q1 = 3/31）。7/14 距 3/31
// 已 105 天 → 判過期 → 重抓；抓完最新一季仍是 Q1（Q2 要 8/14 才發布）
// → 下次更新再判過期。每季發布後僅 ~2-6 週「新鮮」，一年多數日子每次
// 更新都白燒 54 檔候選股的 FinMind 呼叫。
//
// 修正後語意與資產負債表一致：「此刻應已發布的最新一季」已在 DB → 跳過。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/models/finmind/financial_statement.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

class _FixedClock implements AppClock {
  const _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMind;

  setUpAll(() {
    registerFallbackValue(<FinancialDataCompanion>[]);
  });

  FundamentalRepository buildRepo(DateTime now) => FundamentalRepository(
    db: mockDb,
    finMind: mockFinMind,
    twse: MockTwseClient(),
    tpex: MockTpexClient(),
    clock: _FixedClock(now),
  );

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMind = MockFinMindClient();

    when(
      () => mockFinMind.getFinancialStatements(
        stockId: any(named: 'stockId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => <FinMindFinancialStatement>[]);
    when(() => mockDb.insertFinancialData(any())).thenAnswer((_) async {});
  });

  Future<int> sync(FundamentalRepository repo) => repo.syncFinancialStatements(
    symbol: '2330',
    startDate: DateTime(2024, 7, 14),
    endDate: DateTime(2026, 7, 14),
  );

  test('發布死區（7/14 已有 Q1）→ 跳過、不打 FinMind', () async {
    when(
      () => mockDb.getLatestFinancialDataDate('2330', 'INCOME'),
    ).thenAnswer((_) async => DateTime(2026, 3, 31));

    final count = await sync(buildRepo(DateTime(2026, 7, 14)));

    expect(count, 0);
    verifyNever(
      () => mockFinMind.getFinancialStatements(
        stockId: any(named: 'stockId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    );
  });

  test('Q2 應已發布（8/20 只有 Q1）→ 重抓', () async {
    when(
      () => mockDb.getLatestFinancialDataDate('2330', 'INCOME'),
    ).thenAnswer((_) async => DateTime(2026, 3, 31));

    await sync(buildRepo(DateTime(2026, 8, 20)));

    verify(
      () => mockFinMind.getFinancialStatements(
        stockId: '2330',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).called(1);
  });

  test('DB 無資料 → 抓', () async {
    when(
      () => mockDb.getLatestFinancialDataDate('2330', 'INCOME'),
    ).thenAnswer((_) async => null);

    await sync(buildRepo(DateTime(2026, 7, 14)));

    verify(
      () => mockFinMind.getFinancialStatements(
        stockId: '2330',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).called(1);
  });
}
