import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/mops_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

class MockMopsClient extends Mock implements MopsClient {}

class FakeMonthlyRevenueCompanion extends Fake
    implements MonthlyRevenueCompanion {}

StockMasterEntry _stock(String symbol, String market) => StockMasterEntry(
  symbol: symbol,
  name: '測試$symbol',
  market: market,
  industry: '測試',
  isActive: true,
  updatedAt: DateTime(2026, 8, 1),
);

/// MOPS 公布期漸進營收同步(2026-08-03)。
///
/// 行為契約:
/// - 每月 1~14 日(申報期+緩衝)內,每次更新都掃 MOPS 當月 CSV;
///   15 日後靜默跳過(openapi 已接手)
/// - 該市場當月覆蓋已達門檻 → 跳過該市場(不做白工)
/// - MOPS 掛掉(舊版隨時可能關站)→ fail-soft,不得中斷更新管線
/// - 目標月 = 上個月(1 月時 = 去年 12 月)
void main() {
  late MockAppDatabase db;
  late MockMopsClient mops;
  late FundamentalRepository repo;

  setUpAll(() {
    registerFallbackValue(FakeMonthlyRevenueCompanion());
    registerFallbackValue(<MonthlyRevenueCompanion>[]);
    registerFallbackValue(MopsMarket.sii);
  });

  MopsMonthlyRevenue row(String code, {double revenue = 1000}) =>
      MopsMonthlyRevenue(
        code: code,
        year: 2026,
        month: 7,
        revenue: revenue,
        momGrowth: 5.0,
        yoyGrowth: 10.0,
      );

  setUp(() {
    db = MockAppDatabase();
    mops = MockMopsClient();
    repo = FundamentalRepository(
      db: db,
      finMind: MockFinMindClient(),
      twse: MockTwseClient(),
      tpex: MockTpexClient(),
      mops: mops,
    );
    when(
      () => db.getAllActiveStocks(),
    ).thenAnswer((_) async => [_stock('2408', 'TWSE'), _stock('6538', 'TPEx')]);
    when(
      () => db.getRevenueCountForYearMonth(
        any(),
        any(),
        market: any(named: 'market'),
      ),
    ).thenAnswer((_) async => 0);
    when(() => db.insertMonthlyRevenue(any())).thenAnswer((_) async {});
  });

  test('🚨 公布期內(8/4):兩市場都掃,寫入 2026/7', () async {
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.sii,
      ),
    ).thenAnswer((_) async => [row('2408')]);
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.otc,
      ),
    ).thenAnswer((_) async => [row('6538')]);

    final count = await repo.syncInProgressRevenue(DateTime(2026, 8, 4));

    expect(count, 2);
    final captured = verify(
      () => db.insertMonthlyRevenue(captureAny()),
    ).captured;
    final all = captured
        .expand((c) => c as List<MonthlyRevenueCompanion>)
        .toList();
    expect(all, hasLength(2));
    expect(all.every((c) => c.revenueYear.value == 2026), isTrue);
    expect(all.every((c) => c.revenueMonth.value == 7), isTrue);
  });

  test('🚨 15 日後:靜默跳過,client 不被呼叫', () async {
    final count = await repo.syncInProgressRevenue(DateTime(2026, 8, 15));

    expect(count, isNull);
    verifyNever(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: any(named: 'market'),
      ),
    );
  });

  test('該市場覆蓋已達門檻 → 跳過該市場、另一市場照掃', () async {
    when(
      () => db.getRevenueCountForYearMonth(2026, 7, market: MarketCode.twse),
    ).thenAnswer((_) async => 1050); // 上市已滿(openapi 已接手)
    when(
      () => db.getRevenueCountForYearMonth(2026, 7, market: MarketCode.tpex),
    ).thenAnswer((_) async => 0);
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.otc,
      ),
    ).thenAnswer((_) async => [row('6538')]);

    final count = await repo.syncInProgressRevenue(DateTime(2026, 8, 4));

    expect(count, 1);
    verifyNever(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.sii,
      ),
    );
  });

  test('🚨 MOPS 掛掉 → fail-soft 不拋(舊站關站不得中斷管線)', () async {
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: any(named: 'market'),
      ),
    ).thenThrow(const ApiException('mopsov down', 404));

    final count = await repo.syncInProgressRevenue(DateTime(2026, 8, 4));

    expect(count, isNull);
    verifyNever(() => db.insertMonthlyRevenue(any()));
  });

  test('不在 stock_master 的代號被過濾(FK 防炸)', () async {
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.sii,
      ),
    ).thenAnswer((_) async => [row('2408'), row('9999')]);
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: MopsMarket.otc,
      ),
    ).thenAnswer((_) async => const []);

    final count = await repo.syncInProgressRevenue(DateTime(2026, 8, 4));

    expect(count, 1);
  });

  test('1 月的目標月 = 去年 12 月', () async {
    when(
      () => mops.getInProgressRevenue(
        year: any(named: 'year'),
        month: any(named: 'month'),
        market: any(named: 'market'),
      ),
    ).thenAnswer((_) async => const []);

    await repo.syncInProgressRevenue(DateTime(2027, 1, 5));

    verify(
      () => mops.getInProgressRevenue(
        year: 2026,
        month: 12,
        market: MopsMarket.sii,
      ),
    ).called(1);
  });
}
