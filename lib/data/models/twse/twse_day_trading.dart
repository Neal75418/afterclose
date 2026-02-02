/// TWSE 當沖資料（TWTB4U）
///
/// **重要:** TWSE TWTB4U API 提供的是買賣金額（新台幣），
/// 而非成交量（股數）。欄位名稱維持 "volume" 以相容 FinMind 資料，
/// 但實際存放的是金額。
/// [ratio] 需另行從每日價格成交量資料計算。
class TwseDayTrading {
  const TwseDayTrading({
    required this.date,
    required this.code,
    required this.name,
    required this.buyVolume,
    required this.sellVolume,
    required this.totalVolume,
    required this.ratio,
  });

  final DateTime date;
  final String code;
  final String name;

  /// 當沖買進金額 (NT$) - Note: TWSE provides amounts, not volumes
  final double buyVolume;

  /// 當沖賣出金額 (NT$) - Note: TWSE provides amounts, not volumes
  final double sellVolume;

  /// 當沖成交股數 (shares)
  final double totalVolume;

  /// 當沖比例 (%) - calculated from daily price volume
  final double ratio;

  /// 是否為高當沖比例 (>= 30%)
  bool get isHighRatio => ratio >= 30.0;

  /// 是否為極高當沖比例 (>= 50%)
  bool get isExtremeRatio => ratio >= 50.0;
}
