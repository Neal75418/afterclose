// 上櫃財報永遠拿不到同步名額 —— 兩市場候選串接後上市恆佔滿上限
//
// `price_repository.dart:375-378` 把候選組成 `[...twse, ...tpex]`，而
// `UpdateService.selectFinancialSyncTargets` 依序 take 到
// `ApiConfig.financialSyncMaxCandidates`(150)。上市候選檔數遠大於上限
// （2026-07-27 日誌：「價格同步: 2129 筆 (上市 1225, 上櫃 904, 候選 1372)」，
// 且 250+ 個交易日的 update_run 中上市候選恆為 500~800 以上），
// 於是 **上櫃永遠是餘數，而餘數是 0**。
//
// 影響（2026-07-27 正式 DB 快照實查，資料日 07-27）：
//   財報覆蓋率  上市 403/1225 = 32.9%
//               上櫃  14/904  =  1.5%   ← 待回填 890 檔
//
// 缺料**不是** FinMind 供不出上櫃財報：已有的那 14 檔（3088 艾訊、3163 波若威、
// 3374 精材、3491 昇達科、4541 晟田、4939 亞電、5351 鈺創、5483 中美晶、
// 6274 台燿、6488 環球晶、6538 倉和、8069 元太、8299 群聯、8383 千附）
// **每檔 550~770 筆、完整到 2026-03-31**。純粹是名額分配問題。
//
// 額度也不是瓶頸：2026-07-27 實測整輪 FinMind 約 113/600 呼叫
// （清單/歷史價/報酬指數 3 + 外資持股 39 + 資負 33 + 損益 33 + 上櫃持股 5），
// 餘裕 487 次。上櫃 100 檔 × 2 表 = 200 次上限，加總 313/600。
//
// ## 為什麼配額不能只做 take(N)
//
// 沿用上市那條路徑的 take-前綴會立刻復發兩個已知病：
//
// 1. **ETF 佔位**（3faea63、22bdfd0 兩次修過的同型）：上櫃今日有價格的 904 檔
//    中 15 檔是 ETF，且**全部 0 筆財報**。它們的排序鍵恆為「無資料」＝最舊，
//    不濾掉就是每輪固定霸佔 15 個名額、永遠排在最前面。
//
// 2. **前綴永不輪替**（52abc24 對外資持股修過的同型）：候選順序在價格走快取
//    路徑時退化為代號升冪，take 前 N 每天都是同一批；補完後他們變新鮮、
//    同步 0 筆，而後面的 790 檔永遠輪不到 —— 這是硬性停滯，不是變慢。
//
// 修法：**最舊優先**（無資料視為最舊）+ **ETF 在取前 N 之前排除**。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/domain/services/update/fundamental_syncer.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFundamentalRepository extends Mock implements FundamentalRepository {}

void main() {
  DateTime? q(int? month) => month == null ? null : DateTime(2026, month, 31);

  group('selectOtcFinancialTargets', () {
    test('🚨 ETF 不得佔用配額（無財報 → 排序鍵恆為最舊 → 每輪霸佔名額且永遠排最前）', () {
      final picked = selectOtcFinancialTargets(
        // 實測分佈：上櫃今日有價格 904 檔中 ETF 15 檔、個股 889 檔
        candidates: ['00679B', '00687B', '00929', '3088', '5471'],
        latestDates: {
          '3088': q(3), // 已補完
          // 其餘皆無資料；ETF 三檔在正式 DB 實查為 0 筆財報
        },
        limit: 3,
      );

      expect(
        picked.where((s) => s.startsWith('00')),
        isEmpty,
        reason: '上櫃 15 檔 ETF 全部 0 筆財報，永遠不會變新鮮 → 不排除就是永久佔位',
      );
      expect(picked, ['5471', '3088'], reason: '扣掉 ETF 後仍應取滿可取的部分，名額不得空轉');
    });

    test('🚨 無財報者最優先（890 檔待回填全在此類）', () {
      final picked = selectOtcFinancialTargets(
        candidates: ['3088', '8069', '5471', '6488'],
        latestDates: {
          '3088': q(3), // 已補完到 2026-03-31
          '8069': q(3),
          '6488': q(1), // 較舊
          // 5471 完全無資料
        },
        limit: 2,
      );

      expect(picked, ['5471', '6488'], reason: '無資料者排最前，其次才是最舊的');
    });

    test('🚨 補完者必須排到後面，否則跨輪不會收斂', () {
      // 模擬回填第二輪：第一輪的 100 檔已補到 03-31，不該再佔名額
      final done = [for (var i = 0; i < 3; i++) 'D$i'];
      final pending = [for (var i = 0; i < 3; i++) 'P$i'];

      final picked = selectOtcFinancialTargets(
        candidates: [...done, ...pending],
        latestDates: {for (final s in done) s: q(3)},
        limit: 3,
      );

      expect(picked, pending, reason: '若補完者仍排前面，每輪都同步同一批 → 890 檔永遠補不完（硬性停滯）');
    });

    test('排序具決定性：同一份輸入不得因 Map 迭代序而漂移', () {
      final picked = selectOtcFinancialTargets(
        candidates: ['9999', '1111', '5555'],
        latestDates: {'9999': q(3), '1111': q(3), '5555': q(3)},
        limit: 2,
      );

      expect(picked, ['1111', '5555'], reason: '日期相同時以代號升冪決勝，保證跨輪可重現');
    });

    test('對照組：候選少於上限時取全部，不得虛報', () {
      final picked = selectOtcFinancialTargets(
        candidates: ['5471', '6488'],
        latestDates: const {},
        limit: 100,
      );

      expect(picked, ['5471', '6488']);
    });

    test('對照組：候選為空時回空清單', () {
      expect(
        selectOtcFinancialTargets(
          candidates: const [],
          latestDates: const {},
          limit: 100,
        ),
        isEmpty,
      );
    });
  });

  group('selectOtcFinancialBacklog（接 DB 的挑選）', () {
    late MockAppDatabase mockDb;
    late FundamentalSyncer syncer;

    StockMasterEntry entry(String symbol) => StockMasterEntry(
      symbol: symbol,
      name: symbol,
      market: MarketCode.tpex,
      industry: '半導體',
      isActive: true,
      updatedAt: DateTime(2026, 7, 27),
    );

    setUp(() {
      mockDb = MockAppDatabase();
      syncer = FundamentalSyncer(
        database: mockDb,
        fundamentalRepository: MockFundamentalRepository(),
      );
      when(
        () => mockDb.getStocksByMarket(MarketCode.tpex),
      ).thenAnswer((_) async => [entry('5471'), entry('6488'), entry('3088')]);
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), any()),
      ).thenAnswer((_) async => {'3088': q(3)!, '6488': q(1)!});
    });

    test('🚨 上櫃候選要拿到專屬名額（現行 [...twse, ...tpex] 串接下恆為 0）', () async {
      final picked = await syncer.selectOtcFinancialBacklog(
        // 模擬串接：上市在前、上櫃在後
        candidates: ['2330', '2317', '5471', '6488', '3088'],
        limit: 2,
      );

      expect(picked, ['5471', '6488'], reason: '只挑上櫃、且最舊優先；上市候選不由此路徑處理');
    });

    test('🚨 DB 查詢失敗時 fail-closed 回空清單，不得 fail-open', () async {
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), any()),
      ).thenThrow(Exception('db down'));

      final picked = await syncer.selectOtcFinancialBacklog(
        candidates: ['5471', '6488', '3088'],
        limit: 100,
      );

      expect(
        picked,
        isEmpty,
        reason:
            '拿不到最新財報日就無從排序，fail-open 會讓整包上櫃候選逐檔打 FinMind；'
            '這條路徑的價值是回填、少跑一輪無害，額度爆掉才是真傷害',
      );
    });

    test('對照組：候選中沒有上櫃股時不查日期、回空', () async {
      final picked = await syncer.selectOtcFinancialBacklog(
        candidates: ['2330', '2317'],
        limit: 100,
      );

      expect(picked, isEmpty);
      verifyNever(() => mockDb.getLatestFinancialDataDatesBatch(any(), any()));
    });

    test('對照組：預設上限取自 ApiConfig，不得在函式內寫死', () async {
      when(() => mockDb.getStocksByMarket(MarketCode.tpex)).thenAnswer(
        (_) async => [
          for (var i = 0; i < ApiConfig.otcFinancialSyncMaxCount + 20; i++)
            entry('${5000 + i}'),
        ],
      );
      when(
        () => mockDb.getLatestFinancialDataDatesBatch(any(), any()),
      ).thenAnswer((_) async => const {});

      final picked = await syncer.selectOtcFinancialBacklog(
        candidates: [
          for (var i = 0; i < ApiConfig.otcFinancialSyncMaxCount + 20; i++)
            '${5000 + i}',
        ],
      );

      expect(picked.length, ApiConfig.otcFinancialSyncMaxCount);
    });
  });
}
