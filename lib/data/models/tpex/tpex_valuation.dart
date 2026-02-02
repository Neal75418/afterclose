/// TPEX 估值資料（本益比、股價淨值比、殖利率）
class TpexValuation {
  const TpexValuation({
    required this.date,
    required this.code,
    required this.name,
    this.per,
    this.pbr,
    this.dividendYield,
    this.dividendPerShare,
  });

  final DateTime date;
  final String code;
  final String name;
  final double? per; // 本益比
  final double? pbr; // 股價淨值比
  final double? dividendYield; // 殖利率 (%)
  final double? dividendPerShare; // 每股配息
}
