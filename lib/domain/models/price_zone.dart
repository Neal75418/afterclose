/// 代表聚類波段點的價格區域
///
/// 用於將相近的波段點聚類為支撐或壓力區域
class PriceZone {
  const PriceZone({
    required this.avgPrice,
    required this.touches,
    required this.recencyWeight,
  });

  /// 此區域所有點的平均價格
  final double avgPrice;

  /// 觸及此區域的波段點數量
  final int touches;

  /// 依觸及時間的時近性權重（0.0 到 1.0）
  final double recencyWeight;
}
