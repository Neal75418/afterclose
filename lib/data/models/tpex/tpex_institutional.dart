/// TPEX 法人買賣超資料
class TpexInstitutional {
  const TpexInstitutional({
    required this.date,
    required this.code,
    required this.name,
    required this.foreignBuy,
    required this.foreignSell,
    required this.foreignNet,
    required this.investmentTrustBuy,
    required this.investmentTrustSell,
    required this.investmentTrustNet,
    required this.dealerBuy,
    required this.dealerSell,
    required this.dealerNet,
    required this.totalNet,
  });

  final DateTime date;
  final String code;
  final String name;
  final double foreignBuy;
  final double foreignSell;
  final double foreignNet;
  final double investmentTrustBuy;
  final double investmentTrustSell;
  final double investmentTrustNet;
  final double dealerBuy;
  final double dealerSell;
  final double dealerNet;
  final double totalNet;
}
