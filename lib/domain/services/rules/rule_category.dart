/// 規則分類
enum RuleCategory {
  technical('TECHNICAL'),
  institutional('INSTITUTIONAL'),
  fundamental('FUNDAMENTAL'),
  market('MARKET'),
  risk('RISK');

  const RuleCategory(this.value);
  final String value;
}
