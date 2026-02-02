import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 本益比/股價淨值比資料
class FinMindPER {
  const FinMindPER({
    required this.stockId,
    required this.date,
    required this.per,
    required this.pbr,
    required this.dividendYield,
  });

  factory FinMindPER.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindPER(
      stockId: stockId.toString(),
      date: date.toString(),
      per: JsonParsers.parseDouble(json['PER']) ?? 0,
      pbr: JsonParsers.parseDouble(json['PBR']) ?? 0,
      dividendYield: JsonParsers.parseDouble(json['dividend_yield']) ?? 0,
    );
  }

  static FinMindPER? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindPER.fromJson, 'FinMindPER');

  final String stockId;
  final String date;
  final double per; // 本益比
  final double pbr; // 股價淨值比
  final double dividendYield; // 殖利率
}
