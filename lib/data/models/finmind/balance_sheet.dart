import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 資產負債表資料
class FinMindBalanceSheet {
  const FinMindBalanceSheet({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindBalanceSheet.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindBalanceSheet(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindBalanceSheet? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindBalanceSheet.fromJson,
        'FinMindBalanceSheet',
      );

  final String stockId;
  final String date;
  final String type; // 項目名稱 (e.g., "TotalAssets", "TotalLiabilities")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用資產負債表項目類型
  static const String typeTotalAssets = 'TotalAssets';
  static const String typeTotalLiabilities = 'TotalLiabilities';
  static const String typeEquity = 'Equity';
  static const String typeCurrentAssets = 'CurrentAssets';
  static const String typeCurrentLiabilities = 'CurrentLiabilities';
  static const String typeCash = 'CashAndCashEquivalents';
}
