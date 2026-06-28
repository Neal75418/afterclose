/// 產業領導（sector rotation）選股參數
///
/// Used by: mode_recommendation_provider（排序 rank-blend）、SectorStrengthService
///
/// 設計：docs/plans/2026-06-28-sector-leadership-and-rs-design.md
abstract final class SectorParams {
  /// 產業領導 tilt 權重（rank-blend：finalScore = (1−W)·baseRank + W·sectorRank）。
  ///
  /// **0 = 停用**（production 排序零變更、機制 dormant）。待離線 backtest 掃出最佳
  /// W、人工 review 通過後才設正值啟動（spec 規定 selection 改動必過 backtest gate）。
  /// rollback 也是設回 0。
  static const double tiltWeight = 0.0;

  /// 「強產業」evidence chip 門檻：產業強弱百分位 ≥ 此值（前 20% 族群）視為強產業。
  static const double strongSectorChipThreshold = 0.8;
}
