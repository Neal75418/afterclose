/// TPEX 月營收資料
class TpexMonthlyRevenue {
  const TpexMonthlyRevenue({
    required this.date,
    required this.code,
    required this.name,
    required this.revenue,
    required this.revenueYear,
    required this.revenueMonth,
    this.momGrowth,
    this.yoyGrowth,
  });

  final DateTime date;
  final String code;
  final String name;
  final double revenue; // 當月營收（千元）
  final int revenueYear; // 營收年份（西元）
  final int revenueMonth; // 營收月份
  final double? momGrowth; // 月增率 (%)
  final double? yoyGrowth; // 年增率 (%)

  /// 營收（億元）
  double get revenueInBillion => revenue / 100000;
}
