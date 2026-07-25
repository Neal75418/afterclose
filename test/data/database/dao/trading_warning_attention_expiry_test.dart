// 注意股（ATTENTION）失效語意 — 逐日名單，不在最新名單即失效
//
// 2026-07-25 實測缺陷：`updateExpiredWarnings` 唯一失效條件是
// `disposal_end_date < now`，但 ATTENTION 的該欄恆為 NULL，SQL 三值邏輯下
// `NULL < ?` 永不為真 → 注意股一旦寫入就永久 is_active=1。使用者 DB 實測
// 437 筆 / 140 檔 active，當日真實名單只有 19 檔（121 檔幽靈），而
// `TRADING_WARNING_ATTENTION` 是 -15 分，直接把股票壓出推薦榜。
//
// ⚠️ 修法陷阱：表無 market 欄，若粗暴地「把舊日期全部失效」，在只同步上櫃
// 的情境（非交易日 TWSE 端點被跳過）會誤殺全部上市注意股。故失效必須
// **限定在本輪成功同步的市場**。以下測試釘住此不變量。
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  final d1 = DateTime(2026, 7, 23); // 舊名單日
  final d2 = DateTime(2026, 7, 24); // 新名單日

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: '2330',
        name: '台積電',
        market: MarketCode.twse,
      ),
      StockMasterCompanion.insert(
        symbol: '2317',
        name: '鴻海',
        market: MarketCode.twse,
      ),
      StockMasterCompanion.insert(
        symbol: '3088',
        name: '艾訊',
        market: MarketCode.tpex,
      ),
      StockMasterCompanion.insert(
        symbol: '8069',
        name: '元太',
        market: MarketCode.tpex,
      ),
    ]);
  });

  tearDown(() async => db.close());

  Future<void> seedAttention(List<String> symbols, DateTime date) async {
    await db.insertWarningData([
      for (final s in symbols)
        TradingWarningCompanion.insert(
          symbol: s,
          date: date,
          warningType: 'ATTENTION',
          isActive: const Value(true),
        ),
    ]);
  }

  Future<Set<String>> activeAttention() async {
    final rows = await db.getActiveWarningsByType('ATTENTION');
    return rows.map((r) => r.symbol).toSet();
  }

  group('注意股逐日名單失效', () {
    test('不在最新名單的注意股失效，名單內的維持生效', () async {
      await seedAttention(['2330', '2317', '3088'], d1);
      expect(await activeAttention(), {'2330', '2317', '3088'});

      // 7/24 名單只剩 2330（上市）與 3088（上櫃），兩市場都同步成功
      await seedAttention(['2330', '3088'], d2);
      await db.deactivateStaleAttentionWarnings(
        currentSymbols: {'2330', '3088'},
        syncedMarkets: {MarketCode.twse, MarketCode.tpex},
        syncDate: d2,
      );

      expect(await activeAttention(), {
        '2330',
        '3088',
      }, reason: '2317 已不在 7/24 名單，必須失效');
    });

    test('⚠️ 只同步上櫃時，上市注意股不得被誤殺', () async {
      await seedAttention(['2330', '2317', '3088'], d1);

      // 非交易日情境：TWSE 端點被跳過，只有 TPEx 名單是新的（且今日為空）
      await db.deactivateStaleAttentionWarnings(
        currentSymbols: const {},
        syncedMarkets: {MarketCode.tpex},
        syncDate: d2,
      );

      expect(await activeAttention(), {
        '2330',
        '2317',
      }, reason: '上櫃 3088 應失效；上市 2330/2317 未同步、必須原封不動');
    });

    test('該市場今日名單為空時，其舊列全部失效', () async {
      await seedAttention(['3088', '8069'], d1);

      await db.deactivateStaleAttentionWarnings(
        currentSymbols: const {},
        syncedMarkets: {MarketCode.tpex},
        syncDate: d2,
      );

      expect(await activeAttention(), isEmpty);
    });

    test('不得誤傷 DISPOSAL（處置股走 disposalEndDate 期間語意）', () async {
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: d1,
          warningType: 'DISPOSAL',
          disposalEndDate: Value(DateTime(2026, 8, 31)),
          isActive: const Value(true),
        ),
      ]);
      await seedAttention(['2317'], d1);

      await db.deactivateStaleAttentionWarnings(
        currentSymbols: const {},
        syncedMarkets: {MarketCode.twse, MarketCode.tpex},
        syncDate: d2,
      );

      final disposals = await db.getActiveWarningsByType('DISPOSAL');
      expect(disposals.map((r) => r.symbol), [
        '2330',
      ], reason: '處置股仍在處置期內，不得被注意股清理波及');
      expect(await activeAttention(), isEmpty);
    });

    test('同一檔連續多日上榜，只保留今日那列 active', () async {
      await seedAttention(['2330'], d1);
      await seedAttention(['2330'], d2);

      await db.deactivateStaleAttentionWarnings(
        currentSymbols: {'2330'},
        syncedMarkets: {MarketCode.twse},
        syncDate: d2,
      );

      final rows = await db.getActiveWarningsByType('ATTENTION');
      expect(
        rows.length,
        1,
        reason: '多筆 active 會讓讀取端 tie-break 取到過期的 reasonDescription',
      );
      expect(rows.single.date, d2);
    });

    test('未同步任何市場時為 no-op', () async {
      await seedAttention(['2330', '3088'], d1);

      final n = await db.deactivateStaleAttentionWarnings(
        currentSymbols: const {},
        syncedMarkets: const {},
        syncDate: d2,
      );

      expect(n, 0);
      expect(await activeAttention(), {'2330', '3088'});
    });
  });
}
