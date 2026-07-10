/// 產業領導（sector rotation）選股參數
///
/// Used by: mode_recommendation_provider（排序 rank-blend）、SectorStrengthService
///
/// 設計：docs/plans/2026-06-28-sector-leadership-and-rs-design.md
abstract final class SectorParams {
  /// 產業領導 tilt 權重（rank-blend：finalScore = (1−W)·baseRank + W·sectorRank）。
  ///
  /// **0 = 停用（dormant）**。族群動能 tilt 在 `tool/calibration.db` **全期（2021-2026、
  /// 含 2022 空頭）backtest 無持續 edge**：上升 regime IC −0.008、全期 −0.012、逐年
  /// 2021~2025 皆 ≈0 或負。先前一度啟用 0.15 是因只用近期窗（2025-2026）的 +0.054，
  /// 事後證實那是 **2026 單年 outlier**（+0.127）。未過「全期要變好」gate → roll 回 0。
  ///
  /// 機制（rank-blend + 下方 regime gate）已建好並 dormant。**設正值前必過 calibration.db
  /// 全期 gate**（別只看近期窗 — 這就是當初誤啟用的教訓）。
  static const double tiltWeight = 0.0;

  /// regime gate 的市場趨勢回看天數：全市場 [regimeLookbackDays]D 平均報酬 > 0 視為
  /// 上升 regime、才套 tilt。用長窗（120D）而非短窗：short window 會把空頭反彈誤判
  /// 為上升（backtest 實測短窗 leak 22 個空頭反彈日、長窗只 leak 4 個）。
  static const int regimeLookbackDays = 120;

  /// regime 判定的最少有效股數：載入 universe 中歷史足 [regimeLookbackDays]+1 的
  /// 股票不足此數視為資料不足（fresh DB / 回補中），不做 regime 判定。
  static const int regimeMinEligibleStocks = 50;

  /// 「強產業」evidence chip 門檻：產業強弱百分位 ≥ 此值（前 20% 族群）視為強產業。
  static const double strongSectorChipThreshold = 0.8;
}
