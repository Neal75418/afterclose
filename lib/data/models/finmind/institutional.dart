import 'package:afterclose/core/utils/json_parsers.dart';
import 'package:afterclose/core/utils/logger.dart';

/// FinMind API 原始法人資料列
/// 註: API 每種法人類型回傳一列，需要彙整
class FinMindInstitutionalRow {
  const FinMindInstitutionalRow({
    required this.stockId,
    required this.date,
    required this.name,
    required this.buy,
    required this.sell,
  });

  factory FinMindInstitutionalRow.fromJson(Map<String, dynamic> json) {
    return FinMindInstitutionalRow(
      stockId: json['stock_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      buy: JsonParsers.parseDouble(json['buy']) ?? 0,
      sell: JsonParsers.parseDouble(json['sell']) ?? 0,
    );
  }

  final String stockId;
  final String date;
  final String name;
  final double buy;
  final double sell;
}

/// FinMind 彙整後的法人資料
class FinMindInstitutional {
  const FinMindInstitutional({
    required this.stockId,
    required this.date,
    required this.foreignBuy,
    required this.foreignSell,
    required this.investmentTrustBuy,
    required this.investmentTrustSell,
    required this.dealerBuy,
    required this.dealerSell,
  });

  /// 將多列（每種法人類型一列）彙整為單一記錄
  /// API 每個日期會為每種法人類型回傳獨立的列
  factory FinMindInstitutional.aggregate(List<FinMindInstitutionalRow> rows) {
    if (rows.isEmpty) {
      throw const FormatException('Cannot aggregate empty row list');
    }

    double foreignBuy = 0, foreignSell = 0;
    double trustBuy = 0, trustSell = 0;
    double dealerBuy = 0, dealerSell = 0;

    for (final row in rows) {
      switch (row.name) {
        case 'Foreign_Investor':
        case 'Foreign_Dealer_Self':
          foreignBuy += row.buy;
          foreignSell += row.sell;
        case 'Investment_Trust':
          trustBuy += row.buy;
          trustSell += row.sell;
        case 'Dealer_self':
        case 'Dealer_Hedging':
          dealerBuy += row.buy;
          dealerSell += row.sell;
      }
    }

    return FinMindInstitutional(
      stockId: rows.first.stockId,
      date: rows.first.date,
      foreignBuy: foreignBuy,
      foreignSell: foreignSell,
      investmentTrustBuy: trustBuy,
      investmentTrustSell: trustSell,
      dealerBuy: dealerBuy,
      dealerSell: dealerSell,
    );
  }

  /// 嘗試從 JSON 解析（向後相容用，不建議使用）
  static FinMindInstitutional? tryFromJson(Map<String, dynamic> json) {
    // 這是單一列，建立只有一筆的彙整
    try {
      final row = FinMindInstitutionalRow.fromJson(json);
      if (row.stockId.isEmpty || row.date.isEmpty) return null;
      return FinMindInstitutional.aggregate([row]);
    } catch (e) {
      AppLogger.debug('FinMindInstitutional', '解析失敗: ${json['stock_id']} ($e)');
      return null;
    }
  }

  final String stockId;
  final String date;
  final double foreignBuy;
  final double foreignSell;
  final double investmentTrustBuy;
  final double investmentTrustSell;
  final double dealerBuy;
  final double dealerSell;

  /// 外資淨買賣
  double get foreignNet => foreignBuy - foreignSell;

  /// 投信淨買賣
  double get investmentTrustNet => investmentTrustBuy - investmentTrustSell;

  /// 自營商淨買賣
  double get dealerNet => dealerBuy - dealerSell;
}
