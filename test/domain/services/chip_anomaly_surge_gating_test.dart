// 法人集中買賣：停牌股冒充今日 + 薄流動性股佔用名額
//
// 實測（2026-07-26 正式 DB，資料日 2026-07-24）：
//
// **一、停牌股用一個月前的資料冒充今日**
// `today` CTE 取 `rn = 1`——「60 天窗內最近的一列」，但**沒有比對目標
// 日期**。6806 森崴能源的法人與價格資料都停在 2026-06-22（停牌），那筆
// 32 天前的 -3,151 張仍被列入，而面板標題寫的是「今日偵測到 N 項異常」。
// 24 檔命中裡有 2 檔日期不是 7/24（森崴能源落後 32 天、佳總落後 9 天），
// 而森崴能源正好排在全域第 3、佔據上市面板首位。
// 這與評分管線先前修掉的 staleBar 是同一類：取「最近一筆」而非「當日那筆」。
//
// **二、薄流動性股把真訊號擠出名單**
// 判準是純比值（單日 |淨額| > 30 日均值 × 5），分母對法人幾乎不參與的
// 股票趨近於零，於是任何微小成交都破表。5523 豐謙除了當日 -13 張，前面
// 每天都是 ±1~5 張，均量 1.6 張 → 8.1 倍過關；而它的 20 日**中位**成交值
// 只有 0.013 億（每天約 130 萬元），根本買不到。
//
// 而 `maxResultsPerType = 5` 是**全域**上限（非每市場），排序又依倍數，
// 所以雜訊直接吃掉名額：8 個顯示位置有 6 個是不可交易的股票，而華星光
// （中位成交 25.66 億、當日 3,115 張）排第 9 永遠看不到。
//
// 提高倍數門檻治不好——雜訊的倍數反而更高（竣邦 30.0×、光隆 17.7×、
// 豐謙 8.1× vs 華星光 5.5×），拉高門檻會先殺掉真訊號。
//
// **修法**：沿用候選層既有的流動性下限（`RuleParams
// .liquidityMinMedianTurnoverNtd` 3,000 萬 / 20 日**中位數**，2026-07-11
// 實測校準：砍 56% 無效運算、訊號股僅損失 7%），連同「資料不足 permissive
// 放行」與「自選清單豁免」一併比照 `CandidateSelector`。中位數而非平均是
// 關鍵——統一美國50 的 20 日平均 0.31 億過關、中位數 0.291 億不過，正是
// 該常數註解所說的「單日爆量讓殭屍股短暫通過」。
//
// 排序維持倍數：閘門管「值不值得看」、排序管「多異常」，兩件事分開。
// 過濾必須在取前 N **之前**，否則只是把名單變短，真訊號不會遞補上來。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/chip_anomaly_service.dart';

void main() {
  late AppDatabase db;
  late ChipAnomalyService service;

  final asOf = DateTime.utc(2026, 7, 24);

  /// 高於門檻的日成交值（3,000 萬的十倍，確保中位數穩穩過關）
  const liquidTurnover = RuleParams.liquidityMinMedianTurnoverNtd * 10;

  /// 遠低於門檻（每天約 130 萬，對應實測的 5523 豐謙）
  const thinTurnover = 1300000.0;

  setUp(() async {
    db = AppDatabase.forTesting();
    service = ChipAnomalyService(database: db);
  });

  tearDown(() async => db.close());

  Future<void> addStock(String symbol, String name, {String market = 'TWSE'}) =>
      db.upsertStocks([
        StockMasterCompanion.insert(symbol: symbol, name: name, market: market),
      ]);

  /// 灌 [days] 個交易日的價格，日成交值固定為 [turnoverPerDay]。
  /// close 固定 100 → volume = turnover / 100。
  Future<void> addPrices(
    String symbol, {
    required double turnoverPerDay,
    int days = 25,
    DateTime? lastDate,
  }) async {
    final last = lastDate ?? asOf;
    await db.insertPrices([
      for (var i = 0; i < days; i++)
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: last.subtract(Duration(days: i)),
          close: const Value(100.0),
          volume: Value(turnoverPerDay / 100),
        ),
    ]);
  }

  /// 平常每天 [baseline] 股，最新一日 [todayNet] 股。
  /// [lastDate] 用來模擬停牌（最新一列早於 asOf）。
  Future<void> addInstitutional(
    String symbol, {
    required double baseline,
    required double todayNet,
    DateTime? lastDate,
  }) async {
    final last = lastDate ?? asOf;
    await db.insertInstitutionalData([
      DailyInstitutionalCompanion.insert(
        symbol: symbol,
        date: last,
        foreignNet: Value(todayNet),
      ),
      for (var i = 1; i <= 20; i++)
        DailyInstitutionalCompanion.insert(
          symbol: symbol,
          date: last.subtract(Duration(days: i)),
          // 正負交錯，避免同時觸發連續買賣超類判斷
          foreignNet: Value(i.isEven ? baseline : -baseline),
        ),
    ]);
  }

  Future<List<String>> surgeSymbols() async {
    final byMarket = await service.detectAnomaliesByMarket(asOf);
    return [
      for (final list in byMarket.values)
        for (final a in list)
          if (a.type == ChipAnomalyType.institutionalSurge) a.symbol,
    ];
  }

  group('停牌股不得冒充今日', () {
    test('🚨 最新法人列早於資料日者不列入（實測 6806 森崴能源落後 32 天）', () async {
      await addStock('6806', '森崴能源');
      await addPrices('6806', turnoverPerDay: liquidTurnover);
      // 資料停在 32 天前，仍是它自己「最近的一列」
      await addInstitutional(
        '6806',
        baseline: 100000,
        todayNet: -3151000,
        lastDate: asOf.subtract(const Duration(days: 32)),
      );

      expect(
        await surgeSymbols(),
        isNot(contains('6806')),
        reason: '面板標題寫「今日偵測到」，一個月前的停牌資料不是今日訊號',
      );
    });

    test('當日有列者照常列入（確認上一條不是把功能整個關掉）', () async {
      await addStock('2330', '台積電');
      await addPrices('2330', turnoverPerDay: liquidTurnover);
      await addInstitutional('2330', baseline: 100000, todayNet: -3151000);

      expect(await surgeSymbols(), contains('2330'));
    });
  });

  group('流動性閘門', () {
    test('🚨 薄流動性股不得列入（實測 5523 豐謙：13 張 / 中位成交 130 萬）', () async {
      await addStock('5523', '豐謙', market: 'TPEx');
      await addPrices('5523', turnoverPerDay: thinTurnover);
      await addInstitutional('5523', baseline: 1600, todayNet: -13000);

      expect(
        await surgeSymbols(),
        isNot(contains('5523')),
        reason: '每天只成交 130 萬元的股票，滑價會吃掉整個 edge——訊號必須可交易',
      );
    });

    test('🚨 過濾須在取前 N 之前：雜訊讓位後真訊號要遞補上來', () async {
      // maxResultsPerType 個雜訊（倍數更高，會排在真訊號前面）
      for (var i = 0; i < RuleParams.liquidityMedianWindowDays && i < 6; i++) {
        final s = 'N$i';
        await addStock(s, '雜訊$i', market: 'TPEx');
        await addPrices(s, turnoverPerDay: thinTurnover);
        // 倍數 ~20 倍，遠高於真訊號
        await addInstitutional(s, baseline: 1000, todayNet: -20000);
      }
      // 真訊號：倍數較低但完全可交易
      await addStock('4979', '華星光', market: 'TPEx');
      await addPrices('4979', turnoverPerDay: liquidTurnover);
      await addInstitutional('4979', baseline: 500000, todayNet: 3115000);

      expect(
        await surgeSymbols(),
        contains('4979'),
        reason: '若先取前 N 再過濾，名單只會變短；真訊號永遠遞補不上來',
      );
    });

    test('自選清單豁免（與 CandidateSelector 一致——使用者主動追蹤）', () async {
      await addStock('5523', '豐謙', market: 'TPEx');
      await addPrices('5523', turnoverPerDay: thinTurnover);
      await addInstitutional('5523', baseline: 1600, todayNet: -13000);
      await db.addToWatchlist('5523');

      expect(await surgeSymbols(), contains('5523'));
    });

    test('價格資料不足無法判定中位數時 permissive 放行（與候選層同慣例）', () async {
      await addStock('9999', '新上市', market: 'TPEx');
      // 只有 3 天價格 → 低於 liquidityMinDataDays，無法判定
      await addPrices('9999', turnoverPerDay: thinTurnover, days: 3);
      await addInstitutional('9999', baseline: 100000, todayNet: -3151000);

      expect(
        await surgeSymbols(),
        contains('9999'),
        reason: '無法判定 ≠ 不流動；候選層對這種情況也是放行',
      );
    });
  });
}
