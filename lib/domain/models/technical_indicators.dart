/// 規則評估用的技術指標
class TechnicalIndicators {
  const TechnicalIndicators({
    this.rsi,
    this.kdK,
    this.kdD,
    this.prevKdK,
    this.prevKdD,
    this.ma5,
    this.ma20,
    this.ma60,
  });

  final double? rsi;
  final double? kdK;
  final double? kdD;
  final double? prevKdK;
  final double? prevKdD;
  final double? ma5;
  final double? ma20;
  final double? ma60;
}
