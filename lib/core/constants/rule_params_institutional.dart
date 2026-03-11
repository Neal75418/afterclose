/// 法人動向 / 籌碼面 / 延伸市場資料參數
///
/// Used by: institutional_rules.dart, extended_market_rules.dart
abstract final class InstitutionalParams {
  // ==================================================
  // 法人連續買賣超規則
  // ==================================================

  /// 法人資料回溯天數
  static const int institutionalLookbackDays = 10;

  /// 法人連續買賣天數門檻
  static const int institutionalStreakDays = 4;

  /// 法人每日最低淨買賣門檻（股）
  ///
  /// 每日淨買賣超須達此門檻才算有效交易日。
  static const int institutionalMinDailyNetShares = 50000;

  /// 法人每日顯著淨買賣門檻（股）
  ///
  /// 超過此門檻的交易日視為「顯著」交易日。
  static const int institutionalSignificantDailyNetShares = 150000;

  /// 法人連買總量門檻（股）
  ///
  /// 連續買超期間的總淨買超須達此門檻。
  /// 從 2,000,000 降至 1,500,000，因三重過濾（連續天數 + 總量 + 日均）
  /// 導致觸發率過低（0-2 檔/日）。
  static const int institutionalBuyTotalThresholdShares = 1500000;

  /// 法人連買日均門檻（股）
  ///
  /// 連續買超期間的日均淨買超須達此門檻。
  /// 從 300,000 降至 200,000，配合總量門檻調降。
  static const int institutionalBuyDailyAvgThresholdShares = 200000;

  /// 法人連賣總量門檻（股）
  ///
  /// 連續賣超期間的總淨賣超須達此門檻（負值）。
  static const int institutionalSellTotalThresholdShares = -2000000;

  /// 法人連賣日均門檻（股）
  ///
  /// 連續賣超期間的日均淨賣超須達此門檻（負值）。
  static const int institutionalSellDailyAvgThresholdShares = -300000;

  // ==================================================
  // 法人成交量與比例門檻
  // ==================================================

  /// 法人分析最低成交量（1000 張 = 1,000,000 股）
  static const double institutionalMinVolumeShares = 1000000;

  /// 法人數據有效最低成交量（2000 張 = 2,000,000 股）
  static const double institutionalValidVolumeShares = 2000000;

  /// 法人佔總成交量顯著比例門檻
  static const double institutionalSignificantRatio = 0.35;

  /// 法人佔總成交量爆量比例門檻
  static const double institutionalExplosiveRatio = 0.50;

  /// 法人反轉訊號最低量（500 張 = 500,000 股）
  static const double institutionalReversalShares = 500000;

  /// 法人小量方向判斷門檻（100 張 = 100,000 股）
  static const double institutionalSmallShares = 100000;

  /// 法人大量訊號門檻（5000 張 = 5,000,000 股）
  static const double institutionalLargeSignalShares = 5000000;

  /// 法人加速買賣倍數門檻
  static const double institutionalAccelerationMult = 2.0;

  /// 法人加速買賣最低量（1000 張 = 1,000,000 股）
  static const double institutionalAccelerationMinShares = 1000000;

  /// 法人大量訊號價格變動確認門檻（1%）
  static const double institutionalSignificantPriceChange = 0.01;

  /// 法人方向計算取樣數
  static const int institutionalDirectionSampleSize = 5;

  // ==================================================
  // 延伸市場資料（外資持股 / 當沖 / 集中度）
  // ==================================================

  /// 外資持股增加門檻（%）
  ///
  /// N 天內外資持股增加此百分比時觸發。
  static const double foreignShareholdingIncreaseThreshold = 0.5;

  /// 外資持股變化回溯天數
  static const int foreignShareholdingLookbackDays = 5;

  /// 高當沖比例門檻（50%）
  static const double dayTradingHighThreshold = 50.0;

  /// 極高當沖比例門檻（70%）
  static const double dayTradingExtremeThreshold = 70.0;

  /// 大戶持股集中度門檻（%）
  ///
  /// 400 張以上大戶持有此比例的股票。
  static const double concentrationHighThreshold = 60.0;
}
