import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
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

/// 可變的假指數資料表，供跨輪次（run）測試模擬真實 DB 累積狀態
/// （mocktail 的 mock 本身不持久化，需手動接線 upsert/query 才能驗證
/// 「第二輪不重打第一輪已寫入的日期」這類跨呼叫行為）。
class _FakeIndexStore {
  final List<MarketIndexEntry> rows = [];

  void upsert(List<MarketIndexCompanion> companions) {
    for (final c in companions) {
      final date = c.date.value;
      final name = c.name.value;
      rows.removeWhere((r) => r.date == date && r.name == name);
      rows.add(
        MarketIndexEntry(
          id: rows.length + 1,
          date: date,
          name: name,
          close: c.close.value,
          change: c.change.value,
          changePercent: c.changePercent.value,
          createdAt: date,
        ),
      );
    }
  }

  List<MarketIndexEntry> historyFor(String name) {
    final filtered = rows.where((r) => r.name == name).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }
}

void main() {
  late MockAppDatabase mockDb;
  late MockTwseClient mockTwse;
  late MarketIndexSyncer syncer;

  // 固定「現在」=2026-06-15（週一），使 2026-12-18 髒資料偏移 ~186 天必被拒
  final fixedNow = DateTime(2026, 6, 15);

  MarketIndexEntry entryAt(
    DateTime date, {
    String name = MarketIndexNames.taiex,
  }) {
    return MarketIndexEntry(
      id: 1,
      date: date,
      name: name,
      close: 22000.0,
      change: 0.0,
      changePercent: 0.0,
      createdAt: fixedNow,
    );
  }

  /// 智慧型 getIndexHistoryBatch stub：依 `days` 參數區分呼叫來源。
  ///
  /// - `days` 達深度回補目標門檻（[ApiConfig.indexBackfillTargetCalendarDays]）
  ///   → 視為 [MarketIndexSyncer.backfillDeepHistory] 的查詢，回傳
  ///   [deepHistory]（預設空，即「尚無既有資料」）。
  /// - 其餘（`_backfillIfNeeded` / `backfill` 的近期查詢）→ 固定回傳 30 筆
  ///   fixedNow 資料，確保近期回補門檻永遠滿足、不干擾深度回補測試。
  void stubHistoryBatch({List<MarketIndexEntry> deepHistory = const []}) {
    when(
      () => mockDb.getIndexHistoryBatch(
        any(),
        days: any(named: 'days'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((invocation) async {
      final days = invocation.namedArguments[#days] as int;
      if (days >= ApiConfig.indexBackfillTargetCalendarDays) {
        return {MarketIndexNames.taiex: deepHistory};
      }
      return {MarketIndexNames.taiex: List.filled(30, entryAt(fixedNow))};
    });
  }

  setUpAll(() {
    registerFallbackValue(<MarketIndexCompanion>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(DateTime(2020));
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockTwse = MockTwseClient();
    syncer = MarketIndexSyncer(
      database: mockDb,
      twseClient: mockTwse,
      clock: _FixedClock(fixedNow),
      requestDelay: Duration.zero, // 測試不需節流等待
    );

    // 寫入捕捉
    when(() => mockDb.upsertMarketIndices(any())).thenAnswer((_) async {});

    // 預設：近期回補門檻永遠滿足（30 筆）、深度回補視為尚無資料（略過）。
    // 個別測試視需要覆寫 stubHistoryBatch(deepHistory: ...)。
    stubHistoryBatch();
  });

  group('sync (既有行為)', () {
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
  });

  group('backfillDeepHistory（指數深度回補）', () {
    test('尚無既有資料時略過、不呼叫 API', () async {
      stubHistoryBatch(); // 預設空

      final inserted = await syncer.backfillDeepHistory();

      expect(inserted, 0);
      verifyNever(() => mockTwse.getMarketIndices(date: any(named: 'date')));
    });

    test('已達目標深度時略過、不呼叫 API', () async {
      final alreadyDeepEnough = fixedNow.subtract(
        const Duration(days: ApiConfig.indexBackfillTargetCalendarDays),
      );
      stubHistoryBatch(deepHistory: [entryAt(alreadyDeepEnough)]);

      final inserted = await syncer.backfillDeepHistory();

      expect(inserted, 0);
      verifyNever(() => mockTwse.getMarketIndices(date: any(named: 'date')));
    });

    test('從既有最早一筆資料的前一天開始往回走', () async {
      final earliestExisting = DateTime(2026, 6, 10); // 週三，交易日
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);
      when(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).thenAnswer((_) async => <TwseMarketIndex>[]);

      await syncer.backfillDeepHistory();

      final captured = verify(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).captured.cast<DateTime>();

      expect(captured, isNotEmpty);
      // earliest 前一天（2026-06-09，週二）為第一個被請求的日期
      expect(captured.first, DateTime(2026, 6, 9));
      // 從未請求 earliest 當天本身或更晚的日期
      expect(captured.any((d) => !d.isBefore(earliestExisting)), isFalse);
    });

    test('單次呼叫數不超過每輪上限（即使缺口遠超過一年）', () async {
      final earliestExisting = DateTime(2026, 6, 10);
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);
      when(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).thenAnswer((_) async => <TwseMarketIndex>[]);

      await syncer.backfillDeepHistory();

      final captured = verify(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).captured;

      expect(captured.length, ApiConfig.indexBackfillMaxDaysPerRun);
    });

    test('跳過已知休市日、不呼叫 API（2026 元旦）', () async {
      final earliestExisting = DateTime(2026, 1, 5); // 週一
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);
      when(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).thenAnswer((_) async => <TwseMarketIndex>[]);

      await syncer.backfillDeepHistory();

      final captured = verify(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).captured.cast<DateTime>();

      // 元旦（休市日）從未被請求
      expect(captured.contains(DateTime(2026, 1, 1)), isFalse);
      // 前後相鄰的交易日則有被請求（正對照組，證明並非整批被誤擋）
      expect(captured.contains(DateTime(2026, 1, 2)), isTrue);
      expect(captured.contains(DateTime(2025, 12, 31)), isTrue);
    });

    test('第二輪不重打第一輪已寫入的日期、且持續往更早推進', () async {
      final store = _FakeIndexStore()
        ..upsert([
          MarketIndexCompanion.insert(
            date: DateTime(2026, 6, 10),
            name: MarketIndexNames.taiex,
            close: 22000,
            change: 0,
            changePercent: 0,
          ),
        ]);

      when(
        () => mockDb.getIndexHistoryBatch(
          any(),
          days: any(named: 'days'),
          now: any(named: 'now'),
        ),
      ).thenAnswer((invocation) async {
        final days = invocation.namedArguments[#days] as int;
        if (days >= ApiConfig.indexBackfillTargetCalendarDays) {
          return {
            MarketIndexNames.taiex: store.historyFor(MarketIndexNames.taiex),
          };
        }
        return {MarketIndexNames.taiex: List.filled(30, entryAt(fixedNow))};
      });

      when(() => mockDb.upsertMarketIndices(any())).thenAnswer((
        invocation,
      ) async {
        store.upsert(
          invocation.positionalArguments[0] as List<MarketIndexCompanion>,
        );
      });

      when(
        () => mockTwse.getMarketIndices(date: any(named: 'date')),
      ).thenAnswer((invocation) async {
        final date = invocation.namedArguments[#date] as DateTime;
        return [
          TwseMarketIndex(
            date: date,
            name: MarketIndexNames.taiex,
            close: 21000,
            change: 1,
            changePercent: 0.01,
          ),
        ];
      });

      final firstRunInserted = await syncer.backfillDeepHistory();
      expect(firstRunInserted, greaterThan(0));

      final datesAfterFirstRun = store
          .historyFor(MarketIndexNames.taiex)
          .map((e) => e.date)
          .toSet();
      final earliestAfterFirstRun = datesAfterFirstRun.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      // 第一輪應已往更早推進（超越原本的 2026-06-10）
      expect(earliestAfterFirstRun.isBefore(DateTime(2026, 6, 10)), isTrue);

      clearInteractions(mockTwse);

      final secondRunInserted = await syncer.backfillDeepHistory();
      expect(secondRunInserted, greaterThan(0));

      final capturedSecondRun = verify(
        () => mockTwse.getMarketIndices(date: captureAny(named: 'date')),
      ).captured.cast<DateTime>();

      // 第二輪請求的日期全部早於第一輪寫入後的最早日期（不重打）
      expect(
        capturedSecondRun.every((d) => d.isBefore(earliestAfterFirstRun)),
        isTrue,
      );
      expect(
        capturedSecondRun.toSet().intersection(datesAfterFirstRun),
        isEmpty,
      );
    });

    test('重跑（相同既有資料、未真正持久化）不出錯且結果一致', () async {
      final earliestExisting = DateTime(2026, 6, 10);
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);
      when(
        () => mockTwse.getMarketIndices(date: any(named: 'date')),
      ).thenAnswer((invocation) async {
        final date = invocation.namedArguments[#date] as DateTime;
        return [
          TwseMarketIndex(
            date: date,
            name: MarketIndexNames.taiex,
            close: 21000,
            change: 1,
            changePercent: 0.01,
          ),
        ];
      });

      final firstResult = await syncer.backfillDeepHistory();
      final secondResult = await syncer.backfillDeepHistory();

      expect(secondResult, firstResult);
      expect(firstResult, greaterThan(0));
    });

    test('RateLimitException 中途觸發時提前中止，已完成呼叫的資料仍正確寫入'
        '（2026-07-16 活體驗證重現：60 天排隊、真撞 TWSE 限流於第 50 次）', () async {
      final earliestExisting = DateTime(2026, 6, 10);
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);

      var callCount = 0;
      const succeedBeforeLimit = 5;
      when(
        () => mockTwse.getMarketIndices(date: any(named: 'date')),
      ).thenAnswer((invocation) async {
        callCount++;
        if (callCount > succeedBeforeLimit) {
          throw const RateLimitException();
        }
        final date = invocation.namedArguments[#date] as DateTime;
        return [
          TwseMarketIndex(
            date: date,
            name: MarketIndexNames.taiex,
            close: 21000,
            change: 1,
            changePercent: 0.01,
          ),
        ];
      });

      // 直接呼叫 backfillDeepHistory（非透過 sync()）：驗證 RateLimitException
      // 在方法內部就被吸收（break，不 rethrow），不需仰賴外層 try/catch。
      final inserted = await syncer.backfillDeepHistory();

      // 提前中止前已成功寫入的筆數：5 個交易日 × 1 個指數
      expect(inserted, succeedBeforeLimit);
      expect(callCount, succeedBeforeLimit + 1); // 含觸發限流的那次呼叫
    });

    test('fail-soft：TWSE client 拋例外時不影響 sync() 當日同步結果', () async {
      final earliestExisting = DateTime(2026, 6, 10);
      stubHistoryBatch(deepHistory: [entryAt(earliestExisting)]);

      // 當日主同步：正常寫入 1 筆
      when(() => mockTwse.getMarketIndices()).thenAnswer(
        (_) async => [
          TwseMarketIndex(
            date: fixedNow,
            name: MarketIndexNames.taiex,
            close: 22000.0,
            change: 10.0,
            changePercent: 0.05,
          ),
        ],
      );

      // 深度回補用到的逐日查詢一律拋 NetworkException
      // （專案慣例中 NetworkException 通常必須 rethrow，此處驗證深度回補
      // 刻意 fail-soft、不遵循該慣例，因其屬於背景 best-effort 步驟）
      //
      // `that: isNotNull` 是必要條件，而非防禦性寫法：`any(named: 'date')`
      // 預設也匹配 null，會連帶攔截上面 getMarketIndices()（隱式
      // date: null）的當日主同步 stub，讓兩個 when() 互相打架。
      when(
        () => mockTwse.getMarketIndices(
          date: any(named: 'date', that: isNotNull),
        ),
      ).thenThrow(const NetworkException('boom'));

      final synced = await syncer.sync();

      // 當日同步不受影響：仍寫入 1 筆、sync() 未拋出例外
      expect(synced, 1);
    });
  });
}
