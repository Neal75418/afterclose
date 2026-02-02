/// 分析摘要服務的判斷參數
///
/// 集中管理 [AnalysisSummaryService] 使用的評分門檻、
/// 情緒判斷比例和信心度計分規則。
abstract final class AnalysisParams {
  // ==========================================
  // 分數評級門檻
  // ==========================================

  /// 強烈信號分數門檻
  static const int scoreStrongThreshold = 60;

  /// 值得關注分數門檻
  static const int scoreWatchThreshold = 35;

  /// 中性分數門檻（低於此值為「謹慎」）
  static const int scoreNeutralThreshold = 15;

  // ==========================================
  // 輔助數據判斷門檻
  // ==========================================

  /// PE 低估判定門檻（低於此值視為低估）
  static const double peUndervaluedThreshold = 15.0;

  /// 高殖利率判定門檻
  static const double highDividendYieldThreshold = 4.0;

  /// 營收年增率顯著變動門檻（正負皆適用）
  static const double revenueYoySignificantThreshold = 20.0;

  // ==========================================
  // 基本面修正參數
  // ==========================================

  /// PE 深度低估門檻（修正加分）
  static const double peDeepValueThreshold = 10.0;

  /// 高殖利率修正門檻
  static const double highYieldBiasThreshold = 5.5;

  /// 營收強勁成長修正門檻
  static const double revenueStrongGrowthThreshold = 30.0;

  /// 營收顯著衰退修正門檻
  static const double revenueSignificantDeclineThreshold = -20.0;

  /// 基本面修正分值
  static const double fundamentalBiasPoints = 5.0;

  // ==========================================
  // 情緒判斷門檻
  // ==========================================

  /// 衝突狀態下的看多門檻（比例）
  static const double conflictBullRatioThreshold = 0.65;

  /// 衝突狀態下的看多最低分數
  static const int conflictBullScoreThreshold = 35;

  /// 衝突狀態下的看空門檻（比例）
  static const double conflictBearRatioThreshold = 0.35;

  /// 衝突狀態下的看空分數上限
  static const int conflictBearScoreThreshold = 15;

  /// 一般看多門檻（比例）
  static const double bullRatioThreshold = 0.6;

  /// 一般看多最低分數
  static const int bullScoreThreshold = 30;

  /// 一般看空門檻（比例）
  static const double bearRatioThreshold = 0.4;

  /// 一般看空分數上限
  static const int bearScoreThreshold = 20;

  // ==========================================
  // 信心度計分
  // ==========================================

  /// 高信心度門檻（累計點數）
  static const int confidenceHighThreshold = 5;

  /// 中等信心度門檻（累計點數）
  static const int confidenceMediumThreshold = 3;

  /// 多訊號加分門檻（>= 此值加 2 分）
  static const int manySignalsThreshold = 5;

  /// 少量訊號加分門檻（>= 此值加 1 分）
  static const int someSignalsThreshold = 3;
}
