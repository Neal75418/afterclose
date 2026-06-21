import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/update/market_index_syncer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  late MockAppDatabase mockDb;
  late MockTwseClient mockTwse;
  late MarketIndexSyncer syncer;

  // 固定「現在」=2026-06-15，使 2026-12-18 髒資料偏移 ~186 天必被拒
  final fixedNow = DateTime(2026, 6, 15);

  setUpAll(() {
    registerFallbackValue(<MarketIndexCompanion>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockTwse = MockTwseClient();
    syncer = MarketIndexSyncer(
      database: mockDb,
      twseClient: mockTwse,
      clock: _FixedClock(fixedNow),
    );

    // 寫入捕捉
    when(() => mockDb.upsertMarketIndices(any())).thenAnswer((_) async {});

    // backfillIfNeeded：回傳足量歷史避免觸發回補
    when(
      () => mockDb.getIndexHistoryBatch(
        any(),
        days: any(named: 'days'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async {
      final entry = MarketIndexEntry(
        id: 1,
        date: fixedNow,
        name: '發行量加權股價指數',
        close: 22000.0,
        change: 0.0,
        changePercent: 0.0,
        createdAt: fixedNow,
      );
      return {'發行量加權股價指數': List.filled(30, entry)};
    });
  });

  test('skips implausible future-dated index row at write time', () async {
    // API 回傳一筆正常 + 一筆髒未來日期（固定 12-18 模式）
    when(() => mockTwse.getMarketIndices()).thenAnswer(
      (_) async => [
        TwseMarketIndex(
          date: fixedNow, // 正常：等於請求日期
          name: '發行量加權股價指數',
          close: 22000.0,
          change: 10.0,
          changePercent: 0.05,
        ),
        TwseMarketIndex(
          date: DateTime(2026, 12, 18), // 髒資料：偏移過大
          name: '電子工業類指數',
          close: 99999.0,
          change: 0.0,
          changePercent: 0.0,
        ),
      ],
    );

    await syncer.sync();

    // 捕捉實際寫入的 companions
    final captured = verify(
      () => mockDb.upsertMarketIndices(captureAny()),
    ).captured;

    // 攤平所有 upsert 呼叫的 companion
    final allCompanions = captured
        .expand((c) => c as List<MarketIndexCompanion>)
        .toList();

    // 只有正常那筆被寫入，髒未來日期被跳過
    expect(allCompanions.length, 1);
    expect(allCompanions.first.name, const Value('發行量加權股價指數'));
    expect(allCompanions.first.date, Value(fixedNow));
  });

  test('keeps all rows when dates are plausible', () async {
    when(() => mockTwse.getMarketIndices()).thenAnswer(
      (_) async => [
        TwseMarketIndex(
          date: fixedNow,
          name: '發行量加權股價指數',
          close: 22000.0,
          change: 10.0,
          changePercent: 0.05,
        ),
        TwseMarketIndex(
          date: fixedNow,
          name: '電子工業類指數',
          close: 800.0,
          change: 5.0,
          changePercent: 0.6,
        ),
      ],
    );

    await syncer.sync();

    final captured = verify(
      () => mockDb.upsertMarketIndices(captureAny()),
    ).captured;
    final allCompanions = captured
        .expand((c) => c as List<MarketIndexCompanion>)
        .toList();

    expect(allCompanions.length, 2);
  });
}
