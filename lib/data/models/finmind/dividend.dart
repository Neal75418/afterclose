import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 股利資料
class FinMindDividend {
  const FinMindDividend({
    required this.stockId,
    required this.year,
    required this.cashDividend,
    required this.stockDividend,
    this.exDividendDate,
    this.exRightsDate,
  });

  factory FinMindDividend.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }

    return FinMindDividend(
      stockId: stockId.toString(),
      year:
          JsonParsers.parseInt(json['year']) ??
          JsonParsers.parseInt(json['date']?.toString().substring(0, 4)) ??
          0,
      cashDividend:
          JsonParsers.parseDouble(json['CashEarningsDistribution']) ?? 0,
      stockDividend:
          JsonParsers.parseDouble(json['StockEarningsDistribution']) ?? 0,
      exDividendDate: json['CashExDividendTradingDate']?.toString(),
      exRightsDate: json['StockExDividendTradingDate']?.toString(),
    );
  }

  static FinMindDividend? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindDividend.fromJson, 'FinMindDividend');

  final String stockId;
  final int year;
  final double cashDividend; // 現金股利
  final double stockDividend; // 股票股利
  final String? exDividendDate; // 除息日
  final String? exRightsDate; // 除權日

  /// 總股利
  double get totalDividend => cashDividend + stockDividend;
}
