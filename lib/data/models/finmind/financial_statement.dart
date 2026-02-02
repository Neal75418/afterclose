import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 綜合損益表資料
/// 註: 財務報表以 type/value 配對呈現，這是簡化版本
class FinMindFinancialStatement {
  const FinMindFinancialStatement({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindFinancialStatement.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindFinancialStatement(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindFinancialStatement? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindFinancialStatement.fromJson,
        'FinMindFinancialStatement',
      );

  final String stockId;
  final String date; // YYYY-QQ format (e.g., "2024-Q1")
  final String type; // 項目名稱 (e.g., "Revenue", "NetIncome")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用損益表項目類型
  static const String typeRevenue = 'Revenue';
  static const String typeGrossProfit = 'GrossProfit';
  static const String typeOperatingIncome = 'OperatingIncome';
  static const String typeNetIncome = 'NetIncome';
  static const String typeEPS = 'EPS';
}
