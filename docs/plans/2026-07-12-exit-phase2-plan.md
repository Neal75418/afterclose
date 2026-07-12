# 出場層 Phase 2：釘選追蹤 + timeStop — Implementation Plan

> **範圍（gate 定案，2026-07-12）**：釘選論點追蹤 + **timeStop 單一失效條件**。
> hardStop / trendBreak 經 81,989 樣本 gate 全 cell 為負、不上線
> （`docs/plans/2026-07-12-exit-gate-report.md`）；追蹤卡顯示參考價 vs 現價
> 作為資訊替代。spec：`docs/plans/2026-07-11-exit-thesis-invalidation-design.md`
> §4-§6（其中 §2 條件僅 timeStop 生效）。

**Goal:** 推薦卡片可釘選 → 快照論點 → 每日更新後檢查 timeStop（40 交易日未收高於參考價）→ 失效進警示頁；追蹤區顯示狀態與參考價對比。

**Tech:** Drift 新表（pre-launch schema fingerprint 自動重建、無手寫 migration）、post-update fail-safe service（RuleAccuracyService 模式）、Riverpod Notifier、i18n zh-TW/en 同步。

## Tasks（每 task TDD + commit）

1. **`pinned_thesis` 表 + DAO**：欄位照 spec §4（含 lastCheckedDate；invalidatedReason 值域現只有 TIME_STOP）。DAO：`pinThesis`（一 symbol 一 ACTIVE enforcement）、`getActiveTheses`、`getThesesByStatus`、`invalidateThesis`（僅 ACTIVE 可轉，凍結語意）、`archiveThesis`、`deletePinnedThesis`（取消）、`touchLastChecked`。build_runner + fingerprint 更新。
2. **`ThesisInvalidationRules`**（純函數，lib/domain/services/thesis/）：輸入 (referencePrice, pinnedDate 起的收盤序列) → timeStop 判定（≥40 列且從未 close > ref → 觸發日）；與 gate 的 `simulateExit` 同語意（停牌列數計）。
3. **`ThesisMonitorService`**：更新完成後 fail-safe 跑（UpdateService 接線比照 RuleAccuracyService）；逐筆 ACTIVE 全量重算、失效者寫 status/invalidatedDate/reason、全部 touch lastCheckedDate；錯誤不中斷更新。
4. **釘選 providers + UI**：
   - `pinnedThesisProvider`（Notifier：pin/cancel/archive、active map for 按鈕狀態）
   - 今日頁推薦卡 + 個股詳情 header 的 📌（已釘選 → filled icon、不可重複）
   - 今日頁「釘選追蹤」section：狀態徽章（ACTIVE/INVALIDATED+reason）、釘選日、參考價 vs 現價（`daily_price` 最新 close）、最後檢查日、下市提示（isActive=false）、取消/封存操作
   - 警示頁「論點失效」section（INVALIDATED、封存後離開）
   - i18n `thesis.*` 兩檔同步
5. **文件同步 + 收尾**：CLAUDE.md 關鍵路徑、update-pipeline.md（post-update 兩個 service）；全套件、code-reviewer、push。
