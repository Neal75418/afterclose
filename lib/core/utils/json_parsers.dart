import 'package:afterclose/core/utils/logger.dart';

/// JSON 值解析工具函數
abstract final class JsonParsers {
  /// 嘗試解析 JSON 為指定型別，失敗時回傳 null 並記錄日誌
  ///
  /// [json] - 要解析的 JSON Map
  /// [fromJson] - 解析函數（例如 ClassName.fromJson）
  /// [typeName] - 型別名稱，用於日誌記錄
  ///
  /// 使用範例：
  /// ```dart
  /// static FinMindRevenue? tryFromJson(Map<String, dynamic> json) {
  ///   return JsonParsers.tryParse(json, FinMindRevenue.fromJson, 'FinMindRevenue');
  /// }
  /// ```
  static T? tryParse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
    String typeName,
  ) {
    try {
      return fromJson(json);
    } catch (e) {
      AppLogger.debug(
        'JsonParsers',
        '解析 $typeName 失敗: ${json['stock_id'] ?? json['Code'] ?? 'unknown'} ($e)',
      );
      return null;
    }
  }

  /// 將動態值解析為 double
  ///
  /// 支援 null、num、String 型別。
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 將動態值解析為 int
  ///
  /// 支援 null、int、num、String 型別。
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
