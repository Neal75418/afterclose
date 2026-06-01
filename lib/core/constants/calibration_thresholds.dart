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
/// 對齊 Stage 2 LEAN scoring overhaul plan 鎖定的設計決策
/// （`docs/plans/2026-04-11-scoring-stage2-design.md`）：
///
/// - **Success threshold**：5D ≥ 3%（短線吃到肉的下限）、60D ≥ 12%
///   （長線有明顯價值）。10D / 20D 線性內插。
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
  /// - **5D**：3%（短線吃到肉的最低標準）
  /// - **10D**：5%（中線合理目標）
  /// - **20D**：8%（中線強勁目標）
  /// - **60D**：12%（長線有明顯價值）
  static const Map<int, double> successThresholds = {
    5: 3.0,
    10: 5.0,
    20: 8.0,
    60: 12.0,
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
