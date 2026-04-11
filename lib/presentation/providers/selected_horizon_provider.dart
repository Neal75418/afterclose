import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

/// 當前使用者選擇的 horizon（全域單一來源）
///
/// Stage 5c 的核心 state：由 `today_screen` 的 `SegmentedButton` 寫入，
/// 由 `TodayNotifier` / `stockDetailProvider` / `comparisonProvider` 讀取。
///
/// ## 為什麼是全域單一來源
///
/// AfterClose 的資訊架構是「Today → 點擊推薦 → Stock Detail」的 drill-down
/// 流程。如果使用者在 Today 切到長線視角，心智期望是進入 Stock Detail 後
/// 看到的 summary 也是長線 — 不該出現「Today 顯示長線但 Detail 還在講短線」
/// 的錯亂。把 horizon 放成 global 讓「我現在看的是哪個 horizon」只有一個
/// 答案。
///
/// ## 生命週期
///
/// - 預設為 [Horizon.short]（盤後看今天誰強的主要使用情境）
/// - **非持久化**：重開 app 回到 default。Pre-launch 使用者行為模式還沒穩定，
///   不急著鎖住持久化格式
/// - Stage 5d+ 若要跨 session 記住，把此 provider 升級為 `AsyncNotifier`
///   讀 `AppSettings` 即可，public API 幾乎不變
///
/// ## 消費者 pattern（Stage 5c 決議 + 實作修正）
///
/// 原始設計假設 `stockDetailProvider` / `comparisonProvider` 使用 `ref.watch`
/// 造成整個 notifier rebuild，但實作時發現這兩個 notifier 跟 `TodayNotifier`
/// 一樣都是 command-based（`build()` 只回空 state、資料由 imperative command
/// 載入），所以正確 pattern 是**統一使用 `ref.listen`** 搭配各自的 regen method：
/// - `stockDetailProvider`：`ref.listen` → `_regenerateAiSummary`
/// - `comparisonProvider`：`ref.listen` → `_regenerateAllSummaries`
/// - `TodayNotifier`（Commit 2）：`ref.listen` → `_reloadForHorizon`
class SelectedHorizonNotifier extends Notifier<Horizon> {
  @override
  Horizon build() => Horizon.short;

  /// 外部 caller 用來切換 horizon（通常來自 `today_screen` 的 SegmentedButton）。
  void select(Horizon horizon) {
    state = horizon;
  }
}

final selectedHorizonProvider =
    NotifierProvider<SelectedHorizonNotifier, Horizon>(
      SelectedHorizonNotifier.new,
    );
