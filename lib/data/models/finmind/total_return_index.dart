import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind 含息報酬指數（TaiwanStockTotalReturnIndex）
///
/// 加權股價指數的含息版本，反映股息再投資的累積報酬。
/// 與大盤指數對比可看出股息對總報酬的貢獻。
///
/// API 回傳格式：
/// ```json
/// {"date": "2025-01-02", "stock_id": "TAIEX", "price": 50123.45}
/// ```
class FinMindTotalReturnIndex {
  const FinMindTotalReturnIndex({required this.date, required this.price});

  /// 解析 JSON，失敗回傳 null（靜默跳過格式錯誤的記錄）
  static FinMindTotalReturnIndex? tryFromJson(Map<String, dynamic> json) {
    try {
      final dateStr = json['date']?.toString();
      if (dateStr == null || dateStr.isEmpty) return null;

      final date = DateTime.tryParse(dateStr);
      if (date == null) return null;

      final price = JsonParsers.parseDouble(json['price']);
      if (price == null || price <= 0) return null;

      return FinMindTotalReturnIndex(date: date, price: price);
    } catch (_) {
      return null;
    }
  }

  final DateTime date;
  final double price;
}
