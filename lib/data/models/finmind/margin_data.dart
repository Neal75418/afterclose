import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 融資融券資料
class FinMindMarginData {
  const FinMindMarginData({
    required this.stockId,
    required this.date,
    required this.marginBuy,
    required this.marginSell,
    required this.marginCashRepay,
    required this.marginBalance,
    required this.marginLimit,
    required this.marginUseRate,
    required this.shortBuy,
    required this.shortSell,
    required this.shortCashRepay,
    required this.shortBalance,
    required this.shortLimit,
    required this.offsetMarginShort,
    required this.note,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindMarginData.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    final marginBalance =
        JsonParsers.parseDouble(json['MarginPurchaseTodayBalance']) ?? 0;
    final marginLimit =
        JsonParsers.parseDouble(json['MarginPurchaseLimit']) ?? 0;

    return FinMindMarginData(
      stockId: stockId.toString(),
      date: date.toString(),
      marginBuy: JsonParsers.parseDouble(json['MarginPurchaseBuy']) ?? 0,
      marginSell: JsonParsers.parseDouble(json['MarginPurchaseSell']) ?? 0,
      marginCashRepay:
          JsonParsers.parseDouble(json['MarginPurchaseCashRepayment']) ?? 0,
      marginBalance: marginBalance,
      marginLimit: marginLimit,
      // 融資使用率 = 融資餘額 / 融資限額 * 100
      marginUseRate: marginLimit > 0 ? (marginBalance / marginLimit) * 100 : 0,
      shortBuy: JsonParsers.parseDouble(json['ShortSaleBuy']) ?? 0,
      shortSell: JsonParsers.parseDouble(json['ShortSaleSell']) ?? 0,
      shortCashRepay:
          JsonParsers.parseDouble(json['ShortSaleCashRepayment']) ?? 0,
      shortBalance: JsonParsers.parseDouble(json['ShortSaleTodayBalance']) ?? 0,
      shortLimit: JsonParsers.parseDouble(json['ShortSaleLimit']) ?? 0,
      offsetMarginShort:
          JsonParsers.parseDouble(json['OffsetLoanAndShort']) ?? 0,
      note: json['Note']?.toString() ?? '',
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null
  static FinMindMarginData? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindMarginData.fromJson,
        'FinMindMarginData',
      );

  final String stockId;
  final String date;

  // 融資 (Margin Purchase)
  final double marginBuy; // 融資買進
  final double marginSell; // 融資賣出
  final double marginCashRepay; // 現金償還
  final double marginBalance; // 融資餘額
  final double marginLimit; // 融資限額
  final double marginUseRate; // 融資使用率

  // 融券 (Short Sale)
  final double shortBuy; // 融券買進
  final double shortSell; // 融券賣出
  final double shortCashRepay; // 現券償還
  final double shortBalance; // 融券餘額
  final double shortLimit; // 融券限額
  final double offsetMarginShort; // 資券互抵

  final String note; // 備註

  /// 融資淨買超
  double get marginNet => marginBuy - marginSell - marginCashRepay;

  /// 融券淨賣超
  double get shortNet => shortSell - shortBuy - shortCashRepay;

  /// 券資比 (融券餘額 / 融資餘額 * 100)
  double get shortMarginRatio =>
      marginBalance > 0 ? (shortBalance / marginBalance) * 100 : 0;
}
