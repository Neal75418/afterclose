import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 每日價格資料
class FinMindDailyPrice {
  const FinMindDailyPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindDailyPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    // 解析收盤價 - 分析的關鍵欄位
    final close = JsonParsers.parseDouble(json['close']);
    if (close == null) {
      throw FormatException('Missing or invalid close price', json);
    }

    return FinMindDailyPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: close,
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null 並記錄日誌
  static FinMindDailyPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindDailyPrice.fromJson,
        'FinMindDailyPrice',
      );

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
}
