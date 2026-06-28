/// 產業領導（sector rotation）選股參數
///
/// Used by: mode_recommendation_provider（排序 rank-blend）、SectorStrengthService
///
/// 設計：docs/plans/2026-06-28-sector-leadership-and-rs-design.md
abstract final class SectorParams {
  /// 產業領導 tilt 權重（rank-blend：finalScore = (1−W)·baseRank + W·sectorRank）。
  ///
  /// **0.15 = 啟用（保守、受 regime gate 保護）**。族群動能因子 regime-dependent：
  /// 持續多頭有效（in-sample IC +0.054、regime-split 上升 IC +0.041~0.054）、空頭/
  /// 轉折反向（2022 OOS IC −0.078 = momentum crash）。故 tilt **僅在市場上升 regime
  /// 套用**（見 [regimeLookbackDays] 與 isMarketUptrend）；下降趨勢自動 effectiveW=0。
  ///
  /// 此值是上升 regime 下的 W。**rollback = 設回 0**（任何 regime 都不套）。
  static const double tiltWeight = 0.15;

  /// regime gate 的市場趨勢回看天數：全市場 [regimeLookbackDays]D 平均報酬 > 0 視為
  /// 上升 regime、才套 tilt。用長窗（120D）而非短窗：short window 會把空頭反彈誤判
  /// 為上升（backtest 實測短窗 leak 22 個空頭反彈日、長窗只 leak 4 個）。
  static const int regimeLookbackDays = 120;

  /// 「強產業」evidence chip 門檻：產業強弱百分位 ≥ 此值（前 20% 族群）視為強產業。
  static const double strongSectorChipThreshold = 0.8;
}
