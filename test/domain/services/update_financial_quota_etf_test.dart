// 財報同步的 150 檔配額在 ETF 過濾之前就切完，名額空轉不遞補
//
// `UpdateService.selectFinancialSyncTargets` 依候選順序 take 到上限，而
// ETF 過濾在下游 `fundamental_syncer.dart:306`（INCOME）、`:409`（BALANCE）
//   .where((s) => !StockPatterns.isEtfCode(s))
// 被丟掉的名額不會由第 N+1 名遞補。
//
// **這是 3faea63 立下的同一條規則沒掃到的地方**：
//   「必須在取前 N 之前過濾……若先取前 N 再過濾，名單只會變短、真訊號
//     永遠遞補不上來」
// 該 commit 修的是 chip_anomaly_service 的 ETF 排除；同型的這處漏了。
//
// 為什麼名額會被 ETF 佔滿：價格走快取路徑時 `quickFilterCandidatesFromDb`
// 完全不排序、DAO 也沒有 ORDER BY，實際回傳序退化為 symbol 升冪
// → 0050, 0051, … 全在最前面。維護者自己在 52abc24（外資持股配額改最舊
// 優先）的 commit message 就記過同一條退化路徑。
//
// 實測（2026-07-24 正式資料，1,415 檔候選）：
//   watchlist 27 ∪ popularStocks 15（重疊 3 檔）= 39 → remainingSlots = 111
//   扣掉 priority 後**前 111 檔 100% 是 00 開頭 ETF**
//   update_run 72 次分佈在 8 個 run_date → 約 89% 的 run 走快取路徑
//
// 影響（DB 實查）：有 EPS 的股票 386 檔，其中 ETF **0** 檔；分市場
//   TWSE 372 / TPEx **14**。而自選清單裡的 4 檔上櫃股（3088 艾訊／
//   3374 精材／4541 晟田／8069 元太）**全部 7 季完整**
//   → FinMind 供得出上櫃財報，缺料是名額分配造成的，不是 API 限制。
//
// 原 finding 宣稱「897 檔候選中只有 39 檔有 EPS/ROE」**不成立**
// （實際 386），故 severity 由 high 降為 medium。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/domain/services/update_service.dart';

void main() {
  /// 重現快取路徑的 symbol 升冪退化：ETF 全在前段
  final etfHeavyCandidates = <String>[
    for (var i = 0; i < 200; i++) '00${600 + i}',
    for (var i = 0; i < 400; i++) '${2000 + i}',
  ];

  /// 實測 priority 為 39 檔（watchlist 27 ∪ popularStocks 15、重疊 3）
  final priority = {for (var i = 0; i < 39; i++) 'P${1000 + i}'};

  /// 下游 fundamental_syncer 一律再濾一次 ETF——這是實際會被同步的集合
  List<String> actuallySynced(List<String> targets) =>
      targets.where((s) => !StockPatterns.isEtfCode(s)).toList();

  test('🚨 ETF 不得佔用財報配額（佔了也不遞補，等於名額空轉）', () {
    final targets = UpdateService.selectFinancialSyncTargets(
      prioritySymbols: priority,
      marketCandidates: etfHeavyCandidates,
    );

    expect(
      targets.where(StockPatterns.isEtfCode),
      isEmpty,
      reason: 'ETF 無財報，不該被選進配額——下游會丟掉它們，而名額不會遞補',
    );
    expect(
      actuallySynced(targets).length,
      ApiConfig.financialSyncMaxCandidates,
      reason:
          '150 個名額應被用滿。修法前前 111 名全是 ETF、下游濾掉後不遞補，'
          '實際只剩 priority 那 39 檔——那一輪沒有任何非自選股拿到新財報',
    );
  });

  test('對照組：非 ETF 候選充足時本來就該取滿（證明上一條不是靠改上限過關）', () {
    final targets = UpdateService.selectFinancialSyncTargets(
      prioritySymbols: priority,
      marketCandidates: [for (var i = 0; i < 400; i++) '${2000 + i}'],
    );

    expect(targets.length, ApiConfig.financialSyncMaxCandidates);
    expect(targets.take(priority.length).toSet(), priority);
  });

  test('對照組：候選不足時取全部，不得虛報', () {
    final targets = UpdateService.selectFinancialSyncTargets(
      prioritySymbols: priority,
      marketCandidates: ['2330', '2317', '00878'],
    );

    expect(actuallySynced(targets).length, priority.length + 2);
    expect(targets, containsAll(['2330', '2317']));
  });

  test('對照組：priority 本身含 ETF 時維持原樣（使用者自選的 ETF 不被剔除）', () {
    final targets = UpdateService.selectFinancialSyncTargets(
      prioritySymbols: {'0050', '2330'},
      marketCandidates: etfHeavyCandidates,
    );

    expect(
      targets,
      contains('0050'),
      reason: '自選是使用者主動追蹤，配額分配不該替他剔除；ETF 無財報由下游自然跳過',
    );
  });
}
