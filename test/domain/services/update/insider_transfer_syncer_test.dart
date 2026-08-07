import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/data/models/tpex/tpex_insider_transfer.dart';
import 'package:daredevil/data/remote/tpex_client.dart';
import 'package:daredevil/data/remote/twse_client.dart';
import 'package:daredevil/domain/services/update/insider_transfer_syncer.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

class FakeCompanion extends Fake implements InsiderTransferCompanion {}

TpexInsiderTransfer _transfer(String symbol) => TpexInsiderTransfer(
  symbol: symbol,
  companyName: '測試$symbol',
  reportDate: DateTime(2026, 8, 4),
  identity: '董事',
  name: '某人',
  transferMethod: '一般交易',
  transferShares: 1000,
  currentHolding: 5000,
);

StockMasterEntry _stock(String symbol, String market) => StockMasterEntry(
  symbol: symbol,
  name: '測試$symbol',
  market: market,
  industry: '測試',
  isActive: true,
  updatedAt: DateTime(2026, 8, 1),
);

/// 內部人轉讓雙源同步(2026-08-05 補接上市源)。
///
/// 契約:
/// - 上市(t187ap12_L)+上櫃(ap12_O)合併寫入——原本只有上櫃,面板
///   左欄永遠空白,空白被誤讀成「今天沒異動」
/// - **per-source 隔離**:單側連線故障記 warning、另一側照常(同日
///   TPEx 大檔曾三連斷線的實例);兩側都掛才往上拋
/// - RateLimitException 一律直接 rethrow(全域狀態)
void main() {
  setUpAll(() {
    registerFallbackValue(FakeCompanion());
    registerFallbackValue(<InsiderTransferCompanion>[]);
  });

  late MockAppDatabase db;
  late MockTwseClient twse;
  late MockTpexClient tpex;
  late InsiderTransferSyncer syncer;

  setUp(() {
    db = MockAppDatabase();
    twse = MockTwseClient();
    tpex = MockTpexClient();
    syncer = InsiderTransferSyncer(
      database: db,
      twseClient: twse,
      tpexClient: tpex,
    );
    when(
      () => db.getAllActiveStocks(),
    ).thenAnswer((_) async => [_stock('2330', 'TWSE'), _stock('6538', 'TPEx')]);
    when(() => db.insertInsiderTransfers(any())).thenAnswer((_) async {});
  });

  test('🚨 雙源合併寫入(上市+上櫃)', () async {
    when(
      () => twse.getInsiderTransfers(),
    ).thenAnswer((_) async => [_transfer('2330')]);
    when(
      () => tpex.getInsiderTransfers(),
    ).thenAnswer((_) async => [_transfer('6538')]);

    final count = await syncer.sync();

    expect(count, 2);
    final captured =
        verify(() => db.insertInsiderTransfers(captureAny())).captured.single
            as List<InsiderTransferCompanion>;
    expect(captured.map((c) => c.symbol.value).toSet(), {'2330', '6538'});
  });

  test('🚨 單側故障不砍另一側(per-source 隔離)', () async {
    when(
      () => twse.getInsiderTransfers(),
    ).thenThrow(const ApiException('twse down', 500));
    when(
      () => tpex.getInsiderTransfers(),
    ).thenAnswer((_) async => [_transfer('6538')]);

    final count = await syncer.sync();

    expect(count, 1, reason: '上市掛掉,上櫃照常寫入');
  });

  test('兩側都掛 → 拋出(讓 UpdateService 記 errors)', () async {
    when(
      () => twse.getInsiderTransfers(),
    ).thenThrow(const ApiException('twse down', 500));
    when(() => tpex.getInsiderTransfers()).thenThrow(Exception('tpex down'));

    await expectLater(syncer.sync(), throwsA(anything));
    verifyNever(() => db.insertInsiderTransfers(any()));
  });

  test('RateLimitException 直接 rethrow,不進單側容錯', () async {
    when(
      () => twse.getInsiderTransfers(),
    ).thenThrow(const RateLimitException('429'));

    await expectLater(syncer.sync(), throwsA(isA<RateLimitException>()));
    verifyNever(() => tpex.getInsiderTransfers());
  });

  test('單源 harness(僅上櫃)向後相容', () async {
    final soloSyncer = InsiderTransferSyncer(database: db, tpexClient: tpex);
    when(
      () => tpex.getInsiderTransfers(),
    ).thenAnswer((_) async => [_transfer('6538')]);

    expect(await soloSyncer.sync(), 1);
  });
}
