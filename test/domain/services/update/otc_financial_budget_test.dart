// 上櫃財報回填的固定配額 100 會在同一小時的第二輪把 FinMind 額度打爆
//
// 回填佇列是**最舊優先**（selectOtcFinancialTargets），設計上保證每一輪都能
// 選出 100 檔「完全無資料」的上櫃股 —— 補完第 1~100 名，下一輪就輪到
// 101~200 名，同樣全是 stale。也就是說**重跑不會變便宜**，這與上市那條
// （_filterNeedingStatementSync 讓重跑時 needy 為空、零呼叫）性質相反。
//
// 2026-07-27 實測，同一個 sliding 1hr 窗內的兩輪：
//   16:33  113/600   （回填上線前：3 + 39 外資持股 + 33 檔×2 + 5）
//   17:08  384/600   （回填上線後：3 + 39 + 169 檔×2 + 4）
//   合計   497/600，餘裕 103
// 第三輪會再要約 200 次（下一批 100 檔 × 損益/資負兩表）→ 約 700 > 600。
//
// ApiBudgetTracker 是 **app session 級的單一實例**（providers.dart:74 的
// plain Provider）＋ sliding 1 小時（api_budget_tracker.dart:78/123），
// 所以跨輪會累加。同檔 :17 的註解記著這事發生過：
//   「實際各 syncer 加總打了 1125 calls，撞 hourly cap 整套 abort」
//
// 修法：回填量改由**剩餘額度**決定，而非固定 100。回填本來就是低優先度的
// 補課，讓它退讓，把「硬撞上限」換成「這輪少補一點」。
//
// 只約束上櫃這條自己的用量：上市那條的 financialSyncMaxCandidates=150 維持
// 不動（它先於本功能存在，且重跑時 needy 為空、不是壓力來源）。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/domain/services/update_service.dart';

void main() {
  const max = ApiConfig.otcFinancialSyncMaxCount;
  const reserve = ApiConfig.otcFinancialBackfillReserve;
  const budget = 600;

  int limitFor(int used) => UpdateService.otcFinancialLimitForBudget(
    usage: (used: used, budget: budget),
  );

  test('對照組：額度充裕時取滿上限', () {
    // 第一輪走到步驟 4.7 時約已用 42（清單/歷史價/報酬指數 3 + 外資持股 39）
    expect(limitFor(42), max);
  });

  test('🚨 額度吃緊時必須縮量，不得硬要 100', () {
    // 同一小時的第二輪：前一輪 384 + 本輪走到 4.7 前的 42
    final limit = limitFor(426);

    expect(limit, lessThan(max), reason: '剩 ${budget - 426} 次，硬補 100 檔要 200 次');
    expect(limit, (budget - 426 - reserve) ~/ 2);
    expect(
      limit * 2,
      lessThanOrEqualTo(budget - 426 - reserve),
      reason: '每檔要打損益＋資負兩次，用 1 次估會低估一半',
    );
  });

  test('🚨 額度已耗盡時回 0，不得回負數', () {
    expect(limitFor(budget), 0);
    expect(limitFor(budget + 50), 0, reason: 'sliding 窗內可能已超額，相減會是負的');
    expect(limitFor(budget - reserve), 0);
  });

  test('🚨 usage 為 null 時維持上限——「量不到」不等於「沒額度」', () {
    // FinMindClient.hourlyUsage 在沒有 tracker 時回 null（2249e4b 刻意的設計：
    // 回 0 會被讀成「這輪沒打 API」，那是把預設值當成量測結果）。
    // 這裡若把 null 當成 0 額度，會讓沒掛 tracker 的環境完全停掉回填。
    expect(UpdateService.otcFinancialLimitForBudget(usage: null), max);
  });

  test('保留額度須涵蓋步驟 4.7 之後的 FinMind 消費者', () {
    // 4.7 之後唯一還吃 FinMind 的是步驟 6.5 的上櫃外資持股，配額寫死在
    // market_data_updater.dart:389 `int maxSyncCount = 20`（不在 ApiConfig，
    // 是既有的魔術數字；此處不順手重構，只確保保留額度蓋得住它）。
    const otcShareholdingQuota = 20;

    expect(
      reserve,
      greaterThanOrEqualTo(otcShareholdingQuota),
      reason: '保留額度若小於後續步驟的配額，止血就只是把爆點往後挪一步',
    );
  });

  test('單調性：已用越多、可補越少，且永不超過上限', () {
    var prev = max + 1;
    for (var used = 0; used <= budget + 100; used += 7) {
      final limit = limitFor(used);
      expect(limit, lessThanOrEqualTo(max));
      expect(limit, greaterThanOrEqualTo(0));
      expect(limit, lessThanOrEqualTo(prev), reason: 'used=$used 時反而變多了');
      prev = limit;
    }
    expect(prev, 0, reason: '額度用滿後應收斂到 0');
  });
}
