/// 產業領導（sector rotation）選股參數
///
/// Used by: mode_recommendation_provider（排序 rank-blend）、SectorStrengthService
///
/// 設計：docs/plans/2026-06-28-sector-leadership-and-rs-design.md
abstract final class SectorParams {
  /// 產業領導 tilt 權重（rank-blend：finalScore = (1−W)·baseRank + W·sectorRank）。
  ///
  /// **0.15 = 啟用（保守）**。2026-06-28 backtest（2025-04~2026-05、IC +0.054、兩段
  /// walk-forward 皆正、強族群 20D 超額 +6.2%）通過人工 review 後啟用。小 W = 溫和
  /// 傾斜、主訊號仍主導。**rollback = 設回 0**（零成本、機制即休眠）。
  ///
  /// ⚠️ 驗證僅涵蓋近期單一 regime（無空頭 OOS）→ 待 2022 空頭年資料補深後跨 regime
  /// 複驗，再決定維持 / 上調 0.20 / 調低。
  static const double tiltWeight = 0.15;

  /// 「強產業」evidence chip 門檻：產業強弱百分位 ≥ 此值（前 20% 族群）視為強產業。
  static const double strongSectorChipThreshold = 0.8;
}
