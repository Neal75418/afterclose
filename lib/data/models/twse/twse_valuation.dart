/// TWSE 估值資料（BWIBBU_d）
class TwseValuation {
  const TwseValuation({
    required this.date,
    required this.code,
    this.per,
    this.dividendYield,
    this.pbr,
  });

  final DateTime date;
  final String code;
  final double? per;
  final double? dividendYield;
  final double? pbr;
}
