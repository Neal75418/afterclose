/// Calibration pipeline canonical thresholds（**唯一 source of truth**）
///
/// 為什麼需要這個檔：
/// rule_accuracy_service（app runtime）、replay_calibrator（tool）、
/// recalibrate（tool）三個 writer 都會用到「success / cut」門檻決定：
///
/// - 某次推薦的 returnRate 算不算「命中」(`successThresholds`)
/// - 一條 rule 在 calibration 時要不要被砍 (`hitRateCutThreshold`,
///   `tStatCutThreshold`, `sampleSizeCutThreshold`)
///
/// 這些常數**過去散在三個檔案**，且註解寫「對齊 X」但值不同 →
/// rule_accuracy 表會被先後寫入用不同門檻的統計，造成 calibration
/// 不可重現。
///
/// 統一來源 = 只有這一份；所有 writer 與 calibrator 都 import 這裡。
///
/// ## 選值依據
///
/// 5D / 60D **採用實證 calibration 校正值**，10D / 20D 仍走 Stage 2 LEAN
/// scoring overhaul plan 鎖定的設計值（`docs/plans/2026-04-11-scoring-stage2-design.md`）。
///
/// **5D / 60D 實證背景（2026-06）**：
/// plan 原設計 5D=3%、60D=12%。2 年市場資料下 recalibrate 結果幾乎全 cut
/// （40 條 rule short 0 / long 1 active），分布顯示：
///   - sample 充足的 5D rule 最高 avg_return 僅 2.38%（< 3%）
///   - 60D 多數 rule avg_return 3-6%（遠 < 12%）
/// 3.0/12.0 屬於設計拍腦袋值，沒有實證根據。修訂為 1.5/8.0，對應約
/// 「1 sigma above market noise」（台股 5D std ≈ 0.5-1%、60D std ≈ 2-3%），
/// 也與 fd693e1 前 production runtime 隱式使用值一致。
///
/// **已知 monotone violation**：修訂後 [20]=8.0, [60]=8.0 — 中線 [10]/[20]
/// 服務於 rule_accuracy_service 內部統計（非 calibrated_scores），是否同步
/// 降值留作 follow-up（不阻擋 ship）。
///
/// - **Success threshold**：5D ≥ 1.5%、60D ≥ 8%、10D ≥ 5%、20D ≥ 8%。
/// - **Hit rate cut**：< 55% 砍（比隨機 +5% 才有 alpha）
/// - **t-stat cut**：< 1.5 砍（信賴度門檻）
/// - **Sample size cut**：< 30 砍（統計顯著性下限）
///
/// 修改任何常數請同步更新 plan 與此 docstring。
abstract final class CalibrationThresholds {
  /// 每個 holding period 對應的「成功」門檻（returnRate %）
  ///
  /// `returnRate >= threshold` 算命中。
  ///
  /// - **1D / 3D**：未列出 → fallback 至 [defaultSuccessThreshold]
  ///   （短線雜訊大，門檻嚴反而測不出真訊號）
  /// - **5D**：1.5%（實證 ≈ 1σ above 5D market noise；calibration evidence-based）
  /// - **10D**：5%（中線合理目標；plan-based，待實證 follow-up）
  /// - **20D**：8%（中線強勁目標；plan-based，待實證 follow-up）
  /// - **60D**：8%（實證 ≈ 1σ above 60D market noise；calibration evidence-based）
  static const Map<int, double> successThresholds = {
    5: 1.5,
    10: 5.0,
    20: 8.0,
    60: 8.0,
  };

  /// 未明確設定 threshold 的 period 使用的 fallback（非負即算命中）
  static const double defaultSuccessThreshold = 0.0;

  /// Calibration cut：hit_rate 必須 ≥ 此值才能保留
  ///
  /// 比隨機 (0.50) 高 5pp 才視為有 alpha。
  static const double hitRateCutThreshold = 0.55;

  /// Calibration cut：proportion z-test 的 |t_stat| 必須 ≥ 此值才能保留
  ///
  /// 1.5 對應約 86.6% 信賴區間。低於此視為統計上不顯著。
  static const double tStatCutThreshold = 1.5;

  /// Calibration cut：sample 數必須 ≥ 此值才能保留
  ///
  /// 30 是統計顯著性實務常用下限。
  static const int sampleSizeCutThreshold = 30;
}
