/// Utility functions for parsing JSON values
abstract final class JsonParsers {
  /// Parse a dynamic value to double
  ///
  /// Handles null, num, and String types
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse a dynamic value to int
  ///
  /// Handles null, int, num, and String types
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
