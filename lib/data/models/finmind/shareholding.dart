import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 外資持股比例資料
class FinMindShareholding {
  const FinMindShareholding({
    required this.stockId,
    required this.date,
    required this.foreignInvestmentRemainingShares,
    required this.foreignInvestmentSharesRatio,
    required this.foreignInvestmentUpperLimitRatio,
    required this.numberOfSharesIssued,
  });

  factory FinMindShareholding.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindShareholding(
      stockId: stockId.toString(),
      date: date.toString(),
      foreignInvestmentRemainingShares:
          JsonParsers.parseDouble(json['ForeignInvestmentRemainingShares']) ??
          0,
      foreignInvestmentSharesRatio:
          JsonParsers.parseDouble(json['ForeignInvestmentSharesRatio']) ?? 0,
      foreignInvestmentUpperLimitRatio:
          JsonParsers.parseDouble(json['ForeignInvestmentUpperLimitRatio']) ??
          0,
      numberOfSharesIssued:
          JsonParsers.parseDouble(json['NumberOfSharesIssued']) ?? 0,
    );
  }

  static FinMindShareholding? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindShareholding.fromJson,
        'FinMindShareholding',
      );

  final String stockId;
  final String date;
  final double foreignInvestmentRemainingShares; // 外資持股餘額(股)
  final double foreignInvestmentSharesRatio; // 外資持股比例(%)
  final double foreignInvestmentUpperLimitRatio; // 外資持股上限比例(%)
  final double numberOfSharesIssued; // 已發行股數
}
