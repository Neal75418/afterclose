/// TDCC 集保中心股權分散表單筆級距資料
class TdccHoldingLevel {
  const TdccHoldingLevel({
    required this.date,
    required this.symbol,
    required this.level,
    required this.shareholders,
    required this.shares,
    required this.percent,
  });

  /// 資料日期
  final DateTime date;

  /// 證券代號
  final String symbol;

  /// 持股分級代碼（1-17）
  final int level;

  /// 股東人數
  final int shareholders;

  /// 持有股數
  final double shares;

  /// 占集保庫存數比例（%）
  final double percent;
}
