/// K 線型態參數
///
/// Used by: candlestick_rules.dart (Doji, Engulfing, Hammer, Gap, Star, ThreeLine)
abstract final class PatternParams {
  /// 錘子線實體最小比例（5%）
  ///
  /// 實體須至少占振幅的 5%，過小視為十字線。
  static const double hammerBodyMinRatio = 0.05;

  /// 錘子線下影線倍數（2 倍實體）
  ///
  /// 下影線須至少為實體的 2 倍。
  static const double hammerLowerShadowMultiplier = 2.0;

  /// 錘子線上影線最大倍數（0.5 倍實體）
  ///
  /// 上影線不可超過實體的 0.5 倍。
  static const double hammerUpperShadowMaxRatio = 0.5;

  /// 三白兵/三黑鴉每根 K 線最小實體比例（1%）
  ///
  /// 每根 K 線的 |open - close| / close 須 >= 1%，
  /// 避免微小漲跌幅的 K 線誤觸發。
  static const double threeLineMinBodyRatio = 0.01;

  /// 十字線實體最大比例（10%）
  ///
  /// 實體小於振幅的 10% 視為十字線。
  static const double dojiBodyMaxRatio = 0.1;

  /// 跳空缺口最小比例（0.5%）
  ///
  /// 缺口須至少為前日收盤的 0.5%。
  static const double gapMinThreshold = 0.005;

  /// 星線小實體最大比例（0.5 倍第一根）
  ///
  /// 第二根 K 線實體不可超過第一根的 0.5 倍。
  static const double starSmallBodyMaxRatio = 0.5;

  /// 強勢 K 線跌幅門檻（1.0%）
  static const double strongCandleDropThreshold = 0.01;
}
