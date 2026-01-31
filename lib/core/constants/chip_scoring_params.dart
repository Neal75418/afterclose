/// 籌碼分析參數配置
///
/// 提取自 [ChipAnalysisService] 以便於調整策略權重。
class ChipScoringParams {
  ChipScoringParams._();

  // ==========================================
  // 1. Institutional (三大法人)
  // ==========================================
  
  /// 法人連買 4 天以上加分
  static const int instBuyStreakLargeBonus = 20;
  
  /// 法人連買 2 天以上加分
  static const int instBuyStreakSmallBonus = 10;
  
  /// 法人連賣 4 天以上扣分
  static const int instSellStreakLargePenalty = -15;
  
  /// 法人連賣 2 天以上扣分
  static const int instSellStreakSmallPenalty = -8;

  // ==========================================
  // 2. Foreign Shareholding (外資持股)
  // ==========================================
  
  /// 外資持股比增加 >= 0.5%
  static const int foreignIncreaseLargeBonus = 15;
  
  /// 外資持股比增加 >= 0.2%
  static const int foreignIncreaseSmallBonus = 8;
  
  /// 外資持股比減少 <= -0.5%
  static const int foreignDecreaseLargePenalty = -10;
  
  /// 外資持股比減少 <= -0.2%
  static const int foreignDecreaseSmallPenalty = -5;

  // ==========================================
  // 3. Margin Trading (信用交易)
  // ==========================================
  
  /// 融資連增 4 天扣分 (散戶追高)
  static const int marginIncreasePenalty = -8;
  
  /// 融券連增 4 天加分 (軋空潛力)
  static const int shortIncreaseBonus = 5;

  // ==========================================
  // 4. Day Trading (當沖)
  // ==========================================
  
  /// 當沖率 >= 35% 扣分 (過熱/投機)
  static const int dayTradingHighPenalty = -5;

  // ==========================================
  // 5. Holding Concentration (股權分散)
  // ==========================================
  
  /// 大戶持股比例 >= 60% 加分
  static const int concentrationHighBonus = 12;
  
  /// 大戶持股比例 >= 40% 加分
  static const int concentrationMediumBonus = 5;

  // ==========================================
  // 6. Insider Holding (內部人)
  // ==========================================
  
  /// 質押比 >= 30% 扣分
  static const int insiderPledgePenalty = -10;
  
  /// 內部人增持加分
  static const int insiderBuyBonus = 8;
  
  /// 內部人減持扣分
  static const int insiderSellPenalty = -8;
}
