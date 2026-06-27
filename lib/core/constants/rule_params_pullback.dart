/// 強股回檔進場參數（Mode C v2）
///
/// Used by: pullback_rules.dart
/// (PullbackToMa20 / PullbackToMa10 / HammerAtSupport / KdHighPullback)
///
/// **CALIBRATION_PENDING**：以下閾值為直覺值、缺台股 backtest。pre-launch 上線後
/// 靠 telemetry 30 天累積樣本校準。集中於此供日後一處調參。
abstract final class PullbackParams {
  // ---- 共用 helper ----

  /// 強勢 baseline：N 日累積漲幅 ≥ 5%（ma20Now > pastClose × 1.05）。
  static const double wasStrongMinRatio = 1.05;

  /// 強勢確認回溯天數。
  static const int strongLookbackDays = 20;

  /// 跌停 guard：當日跌幅 ≤ -9.5%（台股 ±10%、留 0.5% margin）一律 short-circuit。
  static const double limitDownRatio = -0.095;

  /// 過去 N 日內找至少 1 根紅 K 的窗口（過濾瀑布跌）。
  static const int recentBullishCandleDays = 5;

  /// 規則所需最少 K 棒數。
  static const int minHistoryDays = 21;

  // ---- Rule A: PULLBACK_TO_MA20 ----

  /// 拉回 MA20 區間下界（-1.5%）。
  static const double ma20PullbackBandLow = -0.015;

  /// 拉回 MA20 區間上界（+3%）。
  static const double ma20PullbackBandHigh = 0.03;

  /// 量縮判定：今日量 < volumeMA20 × 0.85（Rule A / A2 共用）。
  static const double volumeShrinkRatio = 0.85;

  // ---- Rule A2: PULLBACK_TO_MA10（淺回檔）----

  /// 拉回 MA10 區間下界（-1.5%）。
  static const double ma10PullbackBandLow = -0.015;

  /// 拉回 MA10 區間上界（+2.5%）。
  static const double ma10PullbackBandHigh = 0.025;

  // ---- Rule B: HAMMER_AT_SUPPORT ----

  /// 下影線觸及支撐的容差 ±4%（MA20 / MA60 共用）。
  static const double hammerSupportTouchBand = 0.04;

  /// 收盤站穩支撐：close ≥ supportLevel × 0.985。
  static const double hammerCloseHoldRatio = 0.985;

  /// close 上界：≤ MA20 × 1.06（與 HangingMan 高檔區互斥）。
  static const double hammerCloseMaxMa20Ratio = 1.06;

  /// 跳空下跌認定：(prevClose − open) / prevClose > 1%。
  static const double hammerGapDownRatio = 0.01;

  // ---- Rule C: KD_HIGH_PULLBACK ----

  /// 前日 KD 高檔門檻（prevKdK ≥ 78）。
  static const double kdHighPrevMin = 78;

  /// 今日 K 回落區間下界（含，60）。
  static const double kdPullbackBandLow = 60;

  /// 今日 K 回落區間上界（不含，80）。
  static const double kdPullbackBandHigh = 80;

  /// 收盤未破 MA20 過深：close ≥ MA20 × 0.99。
  static const double kdCloseMinMa20Ratio = 0.99;

  /// 單日 K 跌幅上限（≤ 30，panic 防護）。
  static const double kdMaxDailyDrop = 30;
}
