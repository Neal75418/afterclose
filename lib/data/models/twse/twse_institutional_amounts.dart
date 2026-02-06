/// TWSE 三大法人買賣金額統計（市場總計）
///
/// 從 BFI82U API 取得，單位為元
class TwseInstitutionalAmounts {
  const TwseInstitutionalAmounts({
    required this.date,
    required this.foreignNet,
    required this.trustNet,
    required this.dealerNet,
  });

  final DateTime date;

  /// 外資及陸資買賣超（元）
  final double foreignNet;

  /// 投信買賣超（元）
  final double trustNet;

  /// 自營商買賣超（元）- 含自行買賣與避險
  final double dealerNet;

  /// 三大法人合計（元）
  double get totalNet => foreignNet + trustNet + dealerNet;
}
