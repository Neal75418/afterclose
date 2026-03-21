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

  /// 法人連買 4 天以上加分
  static const int instBuyStreakLargeBonus = 30;

  /// 法人連買 2 天以上加分
  static const int instBuyStreakSmallBonus = 15;

  /// 法人連賣 4 天以上扣分
  static const int instSellStreakLargePenalty = -25;

  /// 法人連賣 2 天以上扣分
  static const int instSellStreakSmallPenalty = -12;

  // ==================================================
  // 2. Foreign Shareholding (外資持股)
  // ==================================================

  /// 外資持股比增加 >= 0.5%
  static const int foreignIncreaseLargeBonus = 25;

  /// 外資持股比增加 >= 0.2%
  static const int foreignIncreaseSmallBonus = 12;

  /// 外資持股比減少 <= -0.5%
  static const int foreignDecreaseLargePenalty = -15;

  /// 外資持股比減少 <= -0.2%
  static const int foreignDecreaseSmallPenalty = -8;

  // ==================================================
  // 3. Margin Trading (信用交易)
  // ==================================================

  /// 融資連增 4 天扣分 (散戶追高)
  static const int marginIncreasePenalty = -12;

  /// 融券連增 4 天加分 (軋空潛力)
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

  /// 當沖率 >= 35% 扣分 (過熱/投機)
  static const int dayTradingHighPenalty = -8;

  // ==================================================
  // 5. Holding Concentration (股權分散)
  // ==================================================

  /// 大戶持股比例 >= 60% 加分
  static const int concentrationHighBonus = 20;

  /// 大戶持股比例 >= 40% 加分
  static const int concentrationMediumBonus = 8;

  // ==================================================
  // 6. Insider Holding (內部人)
  // ==================================================

  /// 質押比 >= 30% 扣分
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
