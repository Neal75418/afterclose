import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 週 K 線資料
class FinMindWeeklyPrice {
  const FinMindWeeklyPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory FinMindWeeklyPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindWeeklyPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: JsonParsers.parseDouble(json['close']),
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  static FinMindWeeklyPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindWeeklyPrice.fromJson,
        'FinMindWeeklyPrice',
      );

  final String stockId;
  final String date; // 週結束日 YYYY-MM-DD
  final double? open; // 週開盤價
  final double? high; // 週最高價
  final double? low; // 週最低價
  final double? close; // 週收盤價
  final double? volume; // 週成交量
}
