import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/models/twse/twse_daily_price.dart';

/// TWSE 法人買賣超資料
class TwseInstitutional {
  const TwseInstitutional({
    required this.date,
    required this.code,
    required this.name,
    required this.foreignBuy,
    required this.foreignSell,
    required this.foreignNet,
    required this.investmentTrustBuy,
    required this.investmentTrustSell,
    required this.investmentTrustNet,
    required this.dealerBuy,
    required this.dealerSell,
    required this.dealerNet,
    required this.totalNet,
  });

  factory TwseInstitutional.fromJson(Map<String, dynamic> json) {
    final code = json['Code'];
    final dateStr = json['Date'];

    if (code == null || code.toString().isEmpty) {
      throw FormatException('Missing Code', json);
    }

    return TwseInstitutional(
      date: dateStr != null
          ? TwseDailyPrice.parseRocDate(dateStr.toString())
          : DateTime.now(),
      code: code.toString(),
      name: json['Name']?.toString() ?? '',
      foreignBuy: _parseDouble(json['ForeignInvestorsBuy']) ?? 0,
      foreignSell: _parseDouble(json['ForeignInvestorsSell']) ?? 0,
      foreignNet: _parseDouble(json['ForeignInvestorsNetBuySell']) ?? 0,
      investmentTrustBuy: _parseDouble(json['InvestmentTrustBuy']) ?? 0,
      investmentTrustSell: _parseDouble(json['InvestmentTrustSell']) ?? 0,
      investmentTrustNet: _parseDouble(json['InvestmentTrustNetBuySell']) ?? 0,
      dealerBuy: _parseDouble(json['DealerTotalBuy']) ?? 0,
      dealerSell: _parseDouble(json['DealerTotalSell']) ?? 0,
      dealerNet: _parseDouble(json['DealerTotalNetBuySell']) ?? 0,
      totalNet: _parseDouble(json['TotalNetBuySell']) ?? 0,
    );
  }

  static TwseInstitutional? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseInstitutional.fromJson(json);
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseInstitutional 失敗: ${json['Code']}');
      return null;
    }
  }

  final DateTime date;
  final String code;
  final String name;
  final double foreignBuy;
  final double foreignSell;
  final double foreignNet;
  final double investmentTrustBuy;
  final double investmentTrustSell;
  final double investmentTrustNet;
  final double dealerBuy;
  final double dealerSell;
  final double dealerNet;
  final double totalNet;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}
