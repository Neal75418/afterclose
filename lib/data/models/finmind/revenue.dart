import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 月營收資料
class FinMindRevenue {
  FinMindRevenue({
    required this.stockId,
    required this.date,
    required this.revenue,
    required this.revenueMonth,
    required this.revenueYear,
    this.momGrowth,
    this.yoyGrowth,
  });

  factory FinMindRevenue.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindRevenue(
      stockId: stockId.toString(),
      date: date.toString(),
      revenue: JsonParsers.parseDouble(json['revenue']) ?? 0,
      revenueMonth: JsonParsers.parseInt(json['revenue_month']) ?? 0,
      revenueYear: JsonParsers.parseInt(json['revenue_year']) ?? 0,
    );
  }

  static FinMindRevenue? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindRevenue.fromJson, 'FinMindRevenue');

  /// 計算營收清單的月增率及年增率
  /// 回傳已填入成長率的相同清單
  static List<FinMindRevenue> calculateGrowthRates(
    List<FinMindRevenue> revenues,
  ) {
    if (revenues.isEmpty) return revenues;

    // 依日期排序（年/月）
    final sorted = List<FinMindRevenue>.from(revenues)
      ..sort((a, b) {
        final yearCompare = a.revenueYear.compareTo(b.revenueYear);
        if (yearCompare != 0) return yearCompare;
        return a.revenueMonth.compareTo(b.revenueMonth);
      });

    // 建立查詢 Map 以快速存取
    final Map<String, FinMindRevenue> lookup = {};
    for (final rev in sorted) {
      lookup['${rev.revenueYear}-${rev.revenueMonth}'] = rev;
    }

    // 計算成長率
    for (final rev in sorted) {
      // 月增率: 與上月比較
      int prevMonth = rev.revenueMonth - 1;
      int prevYear = rev.revenueYear;
      if (prevMonth < 1) {
        prevMonth = 12;
        prevYear -= 1;
      }
      final prevMonthKey = '$prevYear-$prevMonth';
      final prevMonthRev = lookup[prevMonthKey];
      if (prevMonthRev != null && prevMonthRev.revenue > 0) {
        rev.momGrowth =
            ((rev.revenue - prevMonthRev.revenue) / prevMonthRev.revenue) * 100;
      }

      // 年增率: 與去年同月比較
      final yoyKey = '${rev.revenueYear - 1}-${rev.revenueMonth}';
      final yoyRev = lookup[yoyKey];
      if (yoyRev != null && yoyRev.revenue > 0) {
        rev.yoyGrowth = ((rev.revenue - yoyRev.revenue) / yoyRev.revenue) * 100;
      }
    }

    return sorted;
  }

  final String stockId;
  final String date;
  final double revenue; // 當月營收 (千元)
  final int revenueMonth; // 營收月份
  final int revenueYear; // 營收年份

  /// 月增率 (MoM %)
  double? momGrowth;

  /// 年增率 (YoY %)
  double? yoyGrowth;

  /// 營收 (億元)
  double get revenueInBillion => revenue / 100000;
}
