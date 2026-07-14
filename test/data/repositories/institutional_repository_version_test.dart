// InstitutionalRepository.ensureDataVersion — 法人資料口徑版本檢核
//
// 背景：force 同步原本每次都 clearAllData 再重抓，動機是「新舊資料單位
// 混用」（FinMind 逐檔路徑口徑不同）——但該路徑已與 daily_institutional
// 寫入斷接，production DB 已全為 TWSE 批次口徑（2026-07-14 實證 140,037
// 筆 dealer_self_net 皆有值）。破壞式全清改為版本檢核：只在口徑版本
// 變更時清一次（未來若換來源/改單位，bump DataFreshness.
// institutionalDataVersion 即觸發一次性遷移），其餘時候 upsert 即可。
//
// 原子性不變式：clear 與 marker 寫入包在同一交易——避免「清了但沒標記
// → 下次入口又重清剛寫的新資料」的窗口（review 建議的 hardening）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late InstitutionalRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    repo = InstitutionalRepository(
      database: mockDb,
      finMindClient: MockFinMindClient(),
      twseClient: MockTwseClient(),
      tpexClient: MockTpexClient(),
    );

    when(() => mockDb.setSetting(any(), any())).thenAnswer((_) async {});
    when(() => mockDb.clearAllInstitutionalData()).thenAnswer((_) async => 0);
    when(() => mockDb.transaction<void>(any())).thenAnswer((inv) async {
      await (inv.positionalArguments[0] as Future<void> Function())();
    });
  });

  test('版本相符 → 不清、不寫、回 false', () async {
    when(
      () => mockDb.getSetting('institutional_data_version'),
    ).thenAnswer((_) async => DataFreshness.institutionalDataVersion);

    final migrated = await repo.ensureDataVersion();

    expect(migrated, isFalse);
    verifyNever(() => mockDb.clearAllInstitutionalData());
    verifyNever(() => mockDb.setSetting(any(), any()));
  });

  test('無版本記錄（marker 引入前的既有 DB）→ 認養現有資料：只寫 marker、不清、回 false', () async {
    // 升級路徑不變式：null 不是「版本錯誤」的證據——marker 引入前的 DB
    // 都沒有記錄，但其資料已實證為現行口徑（production 140,037 筆
    // dealer_self_net 全有值）。若把 null 當不符去清，升級後第一次
    // 「日常更新」就會把 103 天法人歷史砍到 15 天回補窗，surge
    // baseline（60 日）與 streak 深度全毀。fresh DB 兩種語意等價
    // （本來就沒資料可清）。
    when(
      () => mockDb.getSetting('institutional_data_version'),
    ).thenAnswer((_) async => null);

    final migrated = await repo.ensureDataVersion();

    expect(migrated, isFalse);
    verifyNever(() => mockDb.clearAllInstitutionalData());
    verify(
      () => mockDb.setSetting(
        'institutional_data_version',
        DataFreshness.institutionalDataVersion,
      ),
    ).called(1);
  });

  test('版本不符（口徑變更後首跑）→ 先清再寫 marker、回 true', () async {
    when(
      () => mockDb.getSetting('institutional_data_version'),
    ).thenAnswer((_) async => 'finmind-legacy');

    final migrated = await repo.ensureDataVersion();

    expect(migrated, isTrue);
    verifyInOrder([
      () => mockDb.clearAllInstitutionalData(),
      () => mockDb.setSetting(
        'institutional_data_version',
        DataFreshness.institutionalDataVersion,
      ),
    ]);
  });
}
