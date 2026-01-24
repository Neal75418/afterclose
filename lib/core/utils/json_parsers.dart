/// JSON 值解析工具函數
abstract final class JsonParsers {
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
