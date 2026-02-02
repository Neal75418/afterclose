/// TPEX 融資融券資料
class TpexMarginTrading {
  const TpexMarginTrading({
    required this.date,
    required this.code,
    required this.name,
    required this.marginBuy,
    required this.marginSell,
    required this.marginBalance,
    required this.shortBuy,
    required this.shortSell,
    required this.shortBalance,
  });

  final DateTime date;
  final String code;
  final String name;
  final double marginBuy; // 融資買進
  final double marginSell; // 融資賣出
  final double marginBalance; // 融資餘額
  final double shortBuy; // 融券買進 (回補)
  final double shortSell; // 融券賣出
  final double shortBalance; // 融券餘額

  /// 融資增減
  double get marginNet => marginBuy - marginSell;

  /// 融券增減
  double get shortNet => shortSell - shortBuy;
}
