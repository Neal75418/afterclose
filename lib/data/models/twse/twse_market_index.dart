/// TWSE 大盤指數資料
class TwseMarketIndex {
  const TwseMarketIndex({
    required this.date,
    required this.name,
    required this.close,
    required this.change,
    required this.changePercent,
  });

  final DateTime date;

  /// 指數名稱（如「發行量加權股價指數」、「電子類指數」）
  final String name;

  /// 收盤指數
  final double close;

  /// 漲跌點數
  final double change;

  /// 漲跌百分比（%）
  final double changePercent;

  /// 是否上漲
  bool get isUp => change > 0;

  /// 是否下跌
  bool get isDown => change < 0;
}
