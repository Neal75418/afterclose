import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 股票資訊
class FinMindStockInfo {
  const FinMindStockInfo({
    required this.stockId,
    required this.stockName,
    required this.industryCategory,
    required this.type,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindStockInfo.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }

    return FinMindStockInfo(
      stockId: stockId.toString(),
      stockName: json['stock_name']?.toString() ?? '',
      industryCategory: json['industry_category']?.toString() ?? '',
      type: json['type']?.toString() ?? 'twse',
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null 並記錄日誌
  static FinMindStockInfo? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindStockInfo.fromJson, 'FinMindStockInfo');

  final String stockId;
  final String stockName;
  final String industryCategory;
  final String type; // "twse" 或 "tpex"

  /// 將 type 轉換為市場列舉字串
  String get market => type.toLowerCase() == 'twse' ? 'TWSE' : 'TPEx';
}
