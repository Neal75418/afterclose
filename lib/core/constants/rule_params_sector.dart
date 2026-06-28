/// 產業領導（sector rotation）選股參數
///
/// Used by: mode_recommendation_provider（排序 rank-blend）、SectorStrengthService
///
/// 設計：docs/plans/2026-06-28-sector-leadership-and-rs-design.md
abstract final class SectorParams {
  /// 產業領導 tilt 權重（rank-blend：finalScore = (1−W)·baseRank + W·sectorRank）。
  ///
  /// **0 = 停用**。2026-06-28 in-sample（2025-04~2026-05）正向（IC +0.054、強族群 20D
  /// 超額 +6.2%），一度啟用 0.15；但 2022 空頭 OOS 複驗顯示因子 **regime-dependent、
  /// 空頭反向**（IC −0.039、後半 −0.079 = momentum crash）→ naive 常開未過完整 gate、
  /// roll 回 0。
  ///
  /// 啟用條件改走「市場 regime gate」：僅大盤上升趨勢套 tilt、下降趨勢 W→0（待建 +
  /// 重驗）。無條件設正值會在空頭系統性排錯。
  static const double tiltWeight = 0.0;

  /// 「強產業」evidence chip 門檻：產業強弱百分位 ≥ 此值（前 20% 族群）視為強產業。
  static const double strongSectorChipThreshold = 0.8;
}
