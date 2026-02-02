/// TPEX 董監持股資料
class TpexInsiderHolding {
  const TpexInsiderHolding({
    required this.date,
    required this.code,
    required this.name,
    this.insiderRatio,
    this.pledgeRatio,
    this.sharesIssued,
  });

  final DateTime date;
  final String code;
  final String name;
  final double? insiderRatio; // 董監持股比例 (%)
  final double? pledgeRatio; // 質押比例 (%)
  final double? sharesIssued; // 已發行股數
}
