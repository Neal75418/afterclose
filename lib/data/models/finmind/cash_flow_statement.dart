import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 現金流量表資料
class FinMindCashFlowStatement {
  const FinMindCashFlowStatement({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindCashFlowStatement.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindCashFlowStatement(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindCashFlowStatement? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindCashFlowStatement.fromJson,
        'FinMindCashFlowStatement',
      );

  final String stockId;
  final String date;
  final String type; // 項目名稱
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用現金流量項目類型
  static const String typeOperatingCashFlow =
      'CashFlowsFromOperatingActivities';
  static const String typeInvestingCashFlow =
      'CashFlowsFromInvestingActivities';
  static const String typeFinancingCashFlow =
      'CashFlowsFromFinancingActivities';
  static const String typeFreeCashFlow = 'FreeCashFlow';
}
