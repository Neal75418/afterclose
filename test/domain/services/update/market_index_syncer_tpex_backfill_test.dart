// 櫃買指數歷史一次性回補（FinMind TaiwanStockPrice data_id=TPEx）
//
// TPEx 官方 OpenAPI 不支援日期參數、只回傳近月資料——櫃買指數位階
// （MA60）過去只能靠每日同步自然累積（~2 個多月）。FinMind 的
// TaiwanStockPrice 以 `TPEx` 為 data_id 可一次拉整年日線，且數值與
// 官方 TPEx OpenAPI 分毫不差（2026-07-22 實測 368.53/381.96 逐筆吻合）。
//
// 配額設計：整段回補=1 次 API 呼叫；達目標深度後前置檢查短路 → 穩態
// 零呼叫。fail-soft 由 sync() 包裹（與 backfillDeepHistory 同慣例）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/update/market_index_syncer.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class MockFinMindClient extends Mock implements FinMindClient {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  final now = DateTime(2026, 7, 22);
  late MockAppDatabase mockDb;
  late MockTwseClient mockTwse;
  late MockFinMindClient mockFinMind;
  late MarketIndexSyncer syncer;

  MarketIndexEntry entry(String name, DateTime date, {double close = 380}) {
    return MarketIndexEntry(
      id: 1,
      date: date,
      name: name,
      close: close,
      change: 0,
      changePercent: 0,
      createdAt: date,
    );
  }

  FinMindDailyPrice price(String date, double close) {
    return FinMindDailyPrice(
      stockId: 'TPEx',
      date: date,
      open: close,
      high: close,
      low: close,
      close: close,
      volume: 0,
    );
  }

  setUp(() {
    mockDb = MockAppDatabase();
    mockTwse = MockTwseClient();
    mockFinMind = MockFinMindClient();
    syncer = MarketIndexSyncer(
      database: mockDb,
      twseClient: mockTwse,
      finMindClient: mockFinMind,
      clock: _FixedClock(now),
      requestDelay: Duration.zero,
    );
    when(() => mockDb.upsertMarketIndices(any())).thenAnswer((_) async {});
  });

  void stubTpexHistory(List<MarketIndexEntry> rows) {
    when(
      () => mockDb.getIndexHistoryBatch(
        [MarketIndexNames.tpexIndex],
        days: any(named: 'days'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => {MarketIndexNames.tpexIndex: rows});
  }

  group('backfillTpexIndexHistory', () {
    test('已達目標深度 → 零 API 呼叫（穩態不耗配額）', () async {
      // 最早一筆已早於目標深度（370 日曆天前）
      stubTpexHistory([
        entry(
          MarketIndexNames.tpexIndex,
          now.subtract(const Duration(days: 380)),
        ),
        entry(MarketIndexNames.tpexIndex, now),
      ]);

      final count = await syncer.backfillTpexIndexHistory();

      expect(count, 0);
      verifyNever(
        () => mockFinMind.getDailyPrices(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('深度不足 → 恰好一次 API 呼叫、首筆無基期跳過、漲跌算對', () async {
      stubTpexHistory([
        entry(MarketIndexNames.tpexIndex, DateTime(2026, 7, 1)),
        entry(MarketIndexNames.tpexIndex, DateTime(2026, 7, 21)),
      ]);
      when(
        () => mockFinMind.getDailyPrices(
          stockId: 'TPEx',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => [
          price('2025-08-01', 100.0),
          price('2025-08-04', 102.0),
          price('2025-08-05', 101.0),
        ],
      );

      final count = await syncer.backfillTpexIndexHistory();

      expect(count, 2); // 3 筆輸入 → 首筆無前日基期，寫入 2 筆
      verify(
        () => mockFinMind.getDailyPrices(
          stockId: 'TPEx',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);

      final companions =
          verify(() => mockDb.upsertMarketIndices(captureAny())).captured.single
              as List<MarketIndexCompanion>;
      expect(companions, hasLength(2));
      expect(companions[0].name.value, MarketIndexNames.tpexIndex);
      expect(companions[0].date.value, DateTime(2025, 8, 4));
      expect(companions[0].close.value, 102.0);
      expect(companions[0].change.value, closeTo(2.0, 1e-9));
      expect(companions[0].changePercent.value, closeTo(2.0, 1e-9));
      expect(companions[1].change.value, closeTo(-1.0, 1e-9));
      expect(
        companions[1].changePercent.value,
        closeTo(-1.0 / 102.0 * 100, 1e-9),
      );
    });

    test('DB 全空（fresh install）→ 照樣回補', () async {
      stubTpexHistory(const []);
      when(
        () => mockFinMind.getDailyPrices(
          stockId: 'TPEx',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => [price('2025-08-01', 100.0), price('2025-08-04', 102.0)],
      );

      final count = await syncer.backfillTpexIndexHistory();

      expect(count, 1);
    });

    test('回應不足 2 筆 → 不寫入、回 0', () async {
      stubTpexHistory(const []);
      when(
        () => mockFinMind.getDailyPrices(
          stockId: 'TPEx',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => [price('2025-08-01', 100.0)]);

      final count = await syncer.backfillTpexIndexHistory();

      expect(count, 0);
      verifyNever(() => mockDb.upsertMarketIndices(any()));
    });

    test('未注入 FinMind client → 0、不炸', () async {
      final bare = MarketIndexSyncer(
        database: mockDb,
        twseClient: mockTwse,
        clock: _FixedClock(now),
        requestDelay: Duration.zero,
      );
      expect(await bare.backfillTpexIndexHistory(), 0);
    });

    test('RateLimitException 往上拋（由 sync 的 fail-soft 吸收）', () async {
      stubTpexHistory(const []);
      when(
        () => mockFinMind.getDailyPrices(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('quota'));

      expect(
        () => syncer.backfillTpexIndexHistory(),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  group('sync() 接線（fail-soft）', () {
    test('櫃買回補丟 RateLimitException → sync 不中止、正常回傳', () async {
      when(() => mockTwse.getMarketIndices()).thenAnswer((_) async => []);
      when(() => mockFinMind.getTotalReturnIndex()).thenAnswer((_) async => []);
      // 通用 stub：dashboard 檢查給足量深歷史（跳過近期/深度回補）、
      // 櫃買給空（觸發櫃買回補）
      when(
        () => mockDb.getIndexHistoryBatch(
          any(),
          days: any(named: 'days'),
          now: any(named: 'now'),
        ),
      ).thenAnswer((inv) async {
        final names = inv.positionalArguments.first as List<String>;
        return {
          for (final n in names)
            n: n == MarketIndexNames.tpexIndex
                ? <MarketIndexEntry>[]
                : [
                    for (var i = 0; i < 25; i++)
                      entry(n, now.subtract(Duration(days: 385 - i * 15))),
                  ],
        };
      });
      when(
        () => mockFinMind.getDailyPrices(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('quota'));

      // 不應丟出例外（fail-soft），也不影響回傳
      final synced = await syncer.sync();
      expect(synced, 0);
    });
  });
}
