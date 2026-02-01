/// 台股漲跌停板檢測工具
///
/// 台股普通股漲跌幅限制為前一交易日收盤價的 ±10%。
/// 漲跌停價以「tick 級距」進位/截斷，此處以百分比近似判斷。
class PriceLimit {
  PriceLimit._();

  /// 漲跌幅限制百分比
  static const double limitPercent = 10.0;

  /// 判斷為漲/跌停的容差（考慮 tick 級距捨入誤差）
  static const double _tolerance = 0.15;

  /// 判斷是否觸及漲停
  ///
  /// [changePercent] 漲跌幅百分比（正數為漲）
  static bool isLimitUp(double? changePercent) {
    if (changePercent == null) return false;
    return changePercent >= limitPercent - _tolerance;
  }

  /// 判斷是否觸及跌停
  ///
  /// [changePercent] 漲跌幅百分比（負數為跌）
  static bool isLimitDown(double? changePercent) {
    if (changePercent == null) return false;
    return changePercent <= -(limitPercent - _tolerance);
  }

  /// 判斷是否觸及漲停或跌停
  static bool isAtLimit(double? changePercent) {
    return isLimitUp(changePercent) || isLimitDown(changePercent);
  }
}
