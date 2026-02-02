import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 還原股價資料
class FinMindAdjustedPrice {
  const FinMindAdjustedPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory FinMindAdjustedPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindAdjustedPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: JsonParsers.parseDouble(json['close']),
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  static FinMindAdjustedPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindAdjustedPrice.fromJson,
        'FinMindAdjustedPrice',
      );

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open; // 還原開盤價
  final double? high; // 還原最高價
  final double? low; // 還原最低價
  final double? close; // 還原收盤價
  final double? volume; // 成交量
}
