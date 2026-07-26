// 上櫃外資持股同步的配額分配 — finding「take(N) 取候選前綴且從不輪替」
//
// 實測（2026-07-26 正式 DB）：`shareholding` 表裡上櫃股「最新持股日 =
// 2026-07-24」的**恰好 20 檔**，正是 `maxSyncCount`。其餘 249 檔上櫃候選
// 從未被同步過——全市場只有 88 檔上櫃有任何持股資料，而候選池有 263 檔、
// 其中 177 檔**完全無資料**。
//
// 兩層原因：
//
// 1. `take(maxSyncCount)` 在新鮮度檢查**之前**執行 → 配額先分配給前 20 名，
//    才發現他們已經新鮮。2026-07-26 日誌實證：「上櫃外資持股新鮮度檢查:
//    跳過 20 檔」+「持股=0」——整個步驟空轉。
//
// 2. 更根本的是**排序**。新鮮度定義是「持股日期 ≥ 最新交易日」，所以每到
//    新的一天全部股票同時變舊；若仍按候選順序取前 N，跨天仍是同一批
//    （價格走快取路徑時候選順序退化為代號升冪，故恆為 00877, 00887, …）。
//    只加過濾不改排序，治得了同日重複跑、治不了「249 檔永遠輪不到」。
//
// 修法：**最舊優先**（無資料視為最舊）。模擬顯示 9 個交易日後涵蓋率達
// 100%，而現行邏輯恆為 88 檔、永不成長。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/update/market_data_updater.dart';

void main() {
  final freshnessDate = DateTime(2026, 7, 24);

  DateTime? d(int? day) => day == null ? null : DateTime(2026, 7, day);

  group('selectOtcShareholdingTargets', () {
    test('🚨 無持股資料者最優先（現行邏輯永遠輪不到它們）', () {
      final picked = selectOtcShareholdingTargets(
        candidates: ['00877', '00887', '3141', '9999'],
        latestDates: {
          '00877': d(24), // 已新鮮
          '00887': d(24), // 已新鮮
          '3141': d(21), // 較舊
          // 9999 無資料
        },
        freshnessDate: freshnessDate,
        limit: 2,
      );

      expect(picked, ['9999', '3141'], reason: '無資料者排最前，其次才是最舊的；已新鮮者不該佔用配額');
    });

    test('🚨 已新鮮者一律排除，配額不得空轉', () {
      // 2026-07-26 實測情境：前 20 名全部已新鮮 → 現行邏輯同步 0 檔
      final picked = selectOtcShareholdingTargets(
        candidates: ['00877', '00887', '00888', '3141', '3147'],
        latestDates: {
          '00877': d(24),
          '00887': d(24),
          '00888': d(24),
          '3141': d(21),
          '3147': d(20),
        },
        freshnessDate: freshnessDate,
        limit: 3,
      );

      expect(picked, ['3147', '3141'], reason: '三檔已新鮮者排除，剩兩檔依最舊優先');
    });

    test('全部已新鮮時回空清單（無事可做，非錯誤）', () {
      final picked = selectOtcShareholdingTargets(
        candidates: ['00877', '00887'],
        latestDates: {'00877': d(24), '00887': d(24)},
        freshnessDate: freshnessDate,
        limit: 20,
      );

      expect(picked, isEmpty);
    });

    test('同日期時以代號排序保證決定性（避免同一批反覆抖動）', () {
      final picked = selectOtcShareholdingTargets(
        candidates: ['3300', '3100', '3200'],
        latestDates: {'3300': d(20), '3100': d(20), '3200': d(20)},
        freshnessDate: freshnessDate,
        limit: 2,
      );

      expect(picked, ['3100', '3200']);
    });

    test('候選數未超過配額時全取', () {
      final picked = selectOtcShareholdingTargets(
        candidates: ['3141', '3147'],
        latestDates: {'3141': d(21)},
        freshnessDate: freshnessDate,
        limit: 20,
      );

      expect(picked.toSet(), {'3141', '3147'});
    });
  });
}
