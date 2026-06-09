/// 籌碼分析參數配置
///
/// 提取自 [ChipAnalysisService] 以便於調整策略權重。
///
/// 基底分為 0，各項信號累加後 clamp(0, 100)。
/// 正面信號合計最大約 95，負面信號合計最小約 -87。
class ChipScoringParams {
  ChipScoringParams._();

  // ==================================================
  // 1. Institutional (三大法人)
  // ==================================================

  /// 法人連續買賣「大門檻」天數
  static const int instStreakLargeDays = 4;

  /// 法人連續買賣「小門檻」天數
  static const int instStreakSmallDays = 2;

  /// 法人連買 >= [instStreakLargeDays] 加分
  static const int instBuyStreakLargeBonus = 30;

  /// 法人連買 >= [instStreakSmallDays] 加分
  static const int instBuyStreakSmallBonus = 15;

  /// 法人連賣 >= [instStreakLargeDays] 扣分
  static const int instSellStreakLargePenalty = -25;

  /// 法人連賣 >= [instStreakSmallDays] 扣分
  static const int instSellStreakSmallPenalty = -12;

  // ==================================================
  // 2. Foreign Shareholding (外資持股)
  // ==================================================

  /// 外資持股比變動「大門檻」百分比（正向為增、負向為減）
  static const double foreignDiffLargePct = 0.5;

  /// 外資持股比變動「小門檻」百分比（正向為增、負向為減）
  static const double foreignDiffSmallPct = 0.2;

  /// 外資持股比增加 >= [foreignDiffLargePct] 加分
  static const int foreignIncreaseLargeBonus = 25;

  /// 外資持股比增加 >= [foreignDiffSmallPct] 加分
  static const int foreignIncreaseSmallBonus = 12;

  /// 外資持股比減少 <= -[foreignDiffLargePct] 扣分
  static const int foreignDecreaseLargePenalty = -15;

  /// 外資持股比減少 <= -[foreignDiffSmallPct] 扣分
  static const int foreignDecreaseSmallPenalty = -8;

  // ==================================================
  // 3. Margin Trading (信用交易)
  // ==================================================

  /// 融資/融券判定回溯天數（最多比對最近 5 個 pair）
  static const int marginLookbackPairs = 5;

  /// 融資/融券連增判定天數（連續 >= 此值觸發加/扣分）
  static const int marginStreakDays = 4;

  /// 融資連增 >= [marginStreakDays] 扣分 (散戶追高)
  static const int marginIncreasePenalty = -12;

  /// 融券連增 >= [marginStreakDays] 加分 (軋空潛力)
  static const int shortIncreaseBonus = 8;

  /// 券資比高於此值視為軋空潛力大 (%)
  static const double highShortMarginRatio = 30.0;

  /// 券資比低於此值視為新空單建立 (%)
  static const double lowShortMarginRatio = 10.0;

  /// 低券資比下融券連增的扣分
  static const int shortIncreaseLowRatioPenalty = -3;

  // ==================================================
  // 4. Day Trading (當沖)
  // ==================================================

  /// 當沖率高門檻（%）— 超過此比例視為過熱/投機
  static const double dayTradingHighThresholdPct = 35.0;

  /// 當沖率 >= dayTradingHighThresholdPct 扣分
  static const int dayTradingHighPenalty = -8;

  // ==================================================
  // 5. Holding Concentration (股權分散)
  // ==================================================

  /// 大戶持股集中度高門檻（%）
  static const double concentrationHighThresholdPct = 60.0;

  /// 大戶持股集中度中門檻（%）
  static const double concentrationMediumThresholdPct = 40.0;

  /// 大戶判定最低張數（張）— 400 張以上視為大戶
  static const int largeHolderMinLot = 400;

  /// 大戶持股比例 >= concentrationHighThresholdPct 加分
  static const int concentrationHighBonus = 20;

  /// 大戶持股比例 >= concentrationMediumThresholdPct 加分
  static const int concentrationMediumBonus = 8;

  // ==================================================
  // 6. Insider Holding (內部人)
  // ==================================================

  /// 質押比高門檻（%）— 超過此比例視為高質押風險
  static const double pledgeHighThresholdPct = 30.0;

  /// 質押比 >= pledgeHighThresholdPct 扣分
  static const int insiderPledgePenalty = -15;

  /// 內部人增持加分
  static const int insiderBuyBonus = 12;

  /// 內部人減持扣分
  static const int insiderSellPenalty = -12;
}

/// 籌碼異動偵測參數
///
/// 集中管理 [ChipAnomalyService] 使用的篩選門檻與回溯天數。
class ChipAnomalyParams {
  ChipAnomalyParams._();

  /// 每種異動類型最多回傳筆數（避免大量結果淹沒 dashboard）
  static const int maxResultsPerType = 5;

  /// 內部人轉讓：回溯天數
  static const int insiderTransferLookbackDays = 30;

  /// 融券暴增：回溯天數
  static const int shortSurgeLookbackDays = 15;

  /// 融券暴增：當日融券賣出超過近期均量的倍率門檻
  static const double shortSurgeMultiplier = 3.0;

  /// 法人集中大買/賣：回溯天數
  static const int institutionalSurgeLookbackDays = 60;

  /// 法人集中大買/賣：當日淨額超過近期均值的倍率門檻
  static const double institutionalSurgeMultiplier = 5.0;
}
