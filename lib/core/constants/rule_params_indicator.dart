/// RSI / KD / 均線 / 52 週高低點參數
///
/// Used by: indicator_rules.dart (RSI*, KD*, MAAlignment*, Week52*)
abstract final class IndicatorParams {
  // ==================================================
  // RSI
  // ==================================================

  /// RSI 週期（預設 14）
  static const int rsiPeriod = 14;

  /// RSI 超買門檻（RSI 高於此值避免買入）
  static const double rsiOverbought = 75.0;

  /// RSI 超賣門檻（RSI 低於此值避免賣出）
  static const double rsiOversold = 20.0;

  /// RSI 極度超買（高風險區）
  ///
  /// 標準超買起點為 75，85 以上即為極度超買。
  static const double rsiExtremeOverbought = 85.0;

  /// RSI 極度超賣（潛在反彈區）
  ///
  /// RSI 30 以下即為超賣區。
  static const double rsiExtremeOversold = 30.0;

  // ==================================================
  // KD
  // ==================================================

  /// KD %K 計算週期
  static const int kdPeriodK = 9;

  /// KD %D 平滑週期
  static const int kdPeriodD = 3;

  /// KD 超買門檻
  static const double kdOverbought = 80.0;

  /// KD 超賣門檻
  static const double kdOversold = 20.0;

  /// KD 黃金交叉有效區域（低檔區）
  ///
  /// K 值需低於此門檻才視為有效黃金交叉。
  static const double kdGoldenCrossZone = 30.0;

  /// KD 死亡交叉有效區域（高檔區）
  ///
  /// K 值需高於此門檻才視為有效死亡交叉。
  static const double kdDeathCrossZone = 70.0;

  /// KD 交叉價格動能門檻（1%）
  ///
  /// 黃金交叉需有至少此漲幅才算有效。
  static const double kdCrossPriceChangeThreshold = 0.01;

  // ==================================================
  // 52 週高低點
  // ==================================================

  /// 一年交易日數（約 52 週 * 5 天）
  static const int week52Days = 250;

  /// 歷史資料完成度最低天數
  ///
  /// 股票需有此天數以上的價格資料，才視為「歷史資料完整」。
  /// 200 天約涵蓋 10 個月的交易日，可進行大部分技術分析。
  static const int historicalDataMinDays = 200;

  /// 接近 52 週新高緩衝百分比
  ///
  /// 收盤價在 52 週最高價的 1% 範圍內觸發。
  /// 維持嚴格門檻確保只有真正突破的股票才觸發。
  static const double week52HighThreshold = 0.01;

  /// 接近 52 週新低緩衝百分比
  ///
  /// 收盤價在 52 週最低價的 3% 範圍內觸發。
  /// 比新高稍寬鬆（3% vs 1%），因為：
  /// 1. 新低是逆勢操作，需要更多緩衝
  /// 2. 底部區域通常有支撐震盪
  /// 3. 避免 0 個新低的極端情況
  static const double week52LowThreshold = 0.03;

  // ==================================================
  // 均線排列
  // ==================================================

  /// 排列檢查用均線週期
  static const List<int> maAlignmentPeriods = [5, 10, 20, 60];

  /// 有效排列的均線最小間距（0.3%）
  ///
  /// 從 0.5% 降至 0.3%，在高價股（如 500 元以上）
  /// 0.5% 間距僅 2.5 元，容易誤判均線糾結為有效排列。
  static const double maMinSeparation = 0.003;

  /// 均線乖離率過濾門檻（5%）
  ///
  /// 收盤價離 MA 超過此距離時過濾，避免追高殺低
  static const double maDeviationThreshold = 0.05;

  /// 多頭排列成交量倍數門檻
  ///
  /// 成交量需達 20 日均量的此倍數。
  /// 1.3 倍（原設計 2.0 倍）考量台股常有量縮上漲現象。
  static const double maAlignmentVolumeMultiplier = 1.3;
}
