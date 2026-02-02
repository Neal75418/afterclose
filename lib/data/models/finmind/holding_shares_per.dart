import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 股權分散表資料
class FinMindHoldingSharesPer {
  const FinMindHoldingSharesPer({
    required this.stockId,
    required this.date,
    required this.holdingSharesLevel,
    required this.people,
    required this.percent,
    required this.unit,
  });

  factory FinMindHoldingSharesPer.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindHoldingSharesPer(
      stockId: stockId.toString(),
      date: date.toString(),
      holdingSharesLevel: json['HoldingSharesLevel']?.toString() ?? '',
      people: JsonParsers.parseInt(json['people']) ?? 0,
      percent: JsonParsers.parseDouble(json['percent']) ?? 0,
      unit: JsonParsers.parseDouble(json['unit']) ?? 0,
    );
  }

  static FinMindHoldingSharesPer? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindHoldingSharesPer.fromJson,
        'FinMindHoldingSharesPer',
      );

  final String stockId;
  final String date;
  final String holdingSharesLevel; // 持股分級 (e.g., "1-999", "1000-5000")
  final int people; // 股東人數
  final double percent; // 占集保庫存數比例(%)
  final double unit; // 股數
}
