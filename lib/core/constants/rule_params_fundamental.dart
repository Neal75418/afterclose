/// 基本面分析參數（營收 / EPS / ROE / 估值 / 董監持股 / 警示）
///
/// Used by: fundamental_scan_rules.dart, insider_rules.dart, warning_rules.dart
abstract final class FundamentalParams {
  // ==================================================
  // 營收
  // ==================================================

  /// 營收年增率暴增門檻（%）
  ///
  /// 30% 在品質與數量間取得平衡。
  static const double revenueYoySurgeThreshold = 30.0;

  /// 營收年減率衰退門檻（%）
  static const double revenueYoyDeclineThreshold = 20.0;

  /// 營收月增連續成長月數
  ///
  /// 設為 1 以偵測單月暴增。
  static const int revenueMomConsecutiveMonths = 1;

  /// 營收月增率門檻（%）
  ///
  /// 10% 視為有意義的成長。
  static const double revenueMomGrowthThreshold = 10.0;

  // ==================================================
  // 估值（PE / PBR / 殖利率）
  // ==================================================

  /// 高殖利率門檻（%）
  ///
  /// 台股平均 4-6%，5.5% 可篩選出真正高殖利率股。
  static const double highDividendYieldThreshold = 5.5;

  /// 本益比低估門檻
  ///
  /// 本益比低於此值（且 > 0）視為低估。
  static const double peUndervaluedThreshold = 10.0;

  /// 本益比高估門檻
  ///
  /// 提高至 100 以聚焦泡沫區域。
  static const double peOvervaluedThreshold = 60.0;

  /// 股價淨值比低估門檻
  ///
  /// 股價淨值比低於 0.8 代表有意義的折價。
  static const double pbrUndervaluedThreshold = 0.8;

  /// 估值資料最大過期天數
  ///
  /// TWSE 並非每日更新所有股票的估值資料，超過此天數的資料視為過時。
  /// 7 天確保資料在合理時效內，避免用舊資料觸發規則。
  static const int valuationMaxStaleDays = 7;

  // ==================================================
  // Killer Features（董監持股 / 注意處置股）
  // ==================================================

  /// 董監連續減持月數門檻
  ///
  /// 連續 3 個月以上減持視為強賣訊號。
  static const int insiderSellingStreakMonths = 3;

  /// 董監顯著增持門檻（%）
  ///
  /// 單月持股比例增加 5% 以上視為買進訊號。
  static const double insiderSignificantBuyingThreshold = 5.0;

  /// 高質押比例門檻（%）
  ///
  /// 質押比例超過 50% 視為風險警示。
  static const double highPledgeRatioThreshold = 50.0;

  /// 處置股結束日期寬限天數
  ///
  /// 判斷處置股是否仍生效時，在結束日期後加上此天數作為緩衝。
  /// 1 天確保結束當日仍視為生效狀態。
  static const int disposalEndDateGraceDays = 1;

  /// 外資持股集中度警示門檻（%）
  ///
  /// 外資持股超過 60% 且快速增加時觸發風險警示。
  static const double foreignConcentrationWarningThreshold = 60.0;

  /// 外資持股集中度危險門檻（%）
  ///
  /// 外資持股超過 70% 視為高度集中風險。
  static const double foreignConcentrationDangerThreshold = 70.0;

  /// 外資流出天數
  ///
  /// 追蹤連續 N 天的外資流出趨勢。
  static const int foreignExodusLookbackDays = 5;

  /// 外資流出門檻（%）
  ///
  /// N 天內外資持股減少超過此比例視為流出警示。
  static const double foreignExodusThreshold = -2.0;

  // ==================================================
  // EPS
  // ==================================================

  /// EPS 年增暴增門檻（%）
  static const double epsYoYSurgeThreshold = 50.0;

  /// EPS 季增成長門檻（%）
  static const double epsGrowthThreshold = 10.0;

  /// EPS 連續成長最少季數
  static const int epsConsecutiveQuarters = 2;

  /// EPS 由負轉正最低門檻（元）
  static const double epsTurnaroundThreshold = 0.3;

  /// EPS 衰退警示門檻（%）
  static const double epsDeclineThreshold = 20.0;

  // ==================================================
  // ROE
  // ==================================================

  /// ROE 優異門檻（%）
  static const double roeExcellentThreshold = 15.0;

  /// ROE 改善門檻（百分點）
  static const double roeImprovingThreshold = 5.0;

  /// ROE 衰退門檻（百分點）
  static const double roeDecliningThreshold = 5.0;

  /// ROE 趨勢最少季數
  static const int roeMinQuarters = 2;

  // ==================================================
  // 掃描規則專用
  // ==================================================

  /// 掃描用殖利率最低門檻（%）
  ///
  /// 低於此值不觸發殖利率相關診斷日誌。
  static const double scanDividendYieldMin = 4.0;

  /// 異常殖利率過濾上限（%）
  ///
  /// 超過此值通常為資料錯誤或特殊情況。
  static const double scanDividendYieldMax = 20.0;

  /// PE 高估確認 RSI 門檻
  static const double scanRsiOverboughtThreshold = 75.0;

  /// 動能確認 RSI 門檻（EPS 轉機搭配 RSI 正向確認）
  static const double scanRsiMomentumThreshold = 50.0;

  /// EPS 年度回溯筆數（找去年同季需要的最少歷史資料）
  static const int epsYearLookback = 5;

  /// EPS 同期季度偏移（降序排列下去年同季的起始 index）
  static const int epsQuarterOffset = 4;
}
