import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 當沖比例資料
class FinMindDayTrading {
  const FinMindDayTrading({
    required this.stockId,
    required this.date,
    required this.buyDayTradingVolume,
    required this.sellDayTradingVolume,
    required this.dayTradingVolume,
    required this.dayTradingRatio,
    required this.tradeVolume,
  });

  factory FinMindDayTrading.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    final buyVolume = JsonParsers.parseDouble(json['BuyDayTradingVolume']) ?? 0;
    final sellVolume =
        JsonParsers.parseDouble(json['SellDayTradingVolume']) ?? 0;
    final tradeVolume = JsonParsers.parseDouble(json['tradeVolume']) ?? 0;
    final dayTradingVolume = (buyVolume + sellVolume) / 2;

    return FinMindDayTrading(
      stockId: stockId.toString(),
      date: date.toString(),
      buyDayTradingVolume: buyVolume,
      sellDayTradingVolume: sellVolume,
      dayTradingVolume: dayTradingVolume,
      dayTradingRatio: tradeVolume > 0
          ? (dayTradingVolume / tradeVolume) * 100
          : 0,
      tradeVolume: tradeVolume,
    );
  }

  static FinMindDayTrading? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindDayTrading.fromJson,
        'FinMindDayTrading',
      );

  final String stockId;
  final String date;
  final double buyDayTradingVolume; // 當沖買進成交量
  final double sellDayTradingVolume; // 當沖賣出成交量
  final double dayTradingVolume; // 當沖量 (平均)
  final double dayTradingRatio; // 當沖比例(%)
  final double tradeVolume; // 總成交量

  /// 是否為高當沖比例 (>30%)
  bool get isHighDayTrading => dayTradingRatio > 30;

  /// 是否為極高當沖比例 (>40%)
  bool get isExtremelyHighDayTrading => dayTradingRatio > 40;
}
