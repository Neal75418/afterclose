import 'package:intl/intl.dart';

/// 統一數字格式化工具
///
/// 提供千分位、中文單位（萬/億）等常用數字格式化方法。
class AppNumberFormat {
  AppNumberFormat._();

  static final _intFormat = NumberFormat('#,##0');
  static final _decFormat = NumberFormat('#,##0.0');
  static final _dec2Format = NumberFormat('#,##0.00');

  /// 整數千分位格式（如 1,234,567）
  static String integer(double value) => _intFormat.format(value);

  /// 一位小數千分位（如 1,234.5）
  static String decimal1(double value) => _decFormat.format(value);

  /// 兩位小數千分位（如 1,234.56）
  static String decimal2(double value) => _dec2Format.format(value);

  /// 自動選擇中文單位：億 / 萬 / 千分位
  ///
  /// 用於成交量、金額等大數值的友善顯示。
  static String compact(double value) {
    if (value.abs() >= 1e8) {
      return '${(value / 1e8).toStringAsFixed(1)}億';
    }
    if (value.abs() >= 1e4) {
      return '${(value / 1e4).toStringAsFixed(1)}萬';
    }
    return _intFormat.format(value);
  }

  /// 帶正負號的千分位整數（如 +1,234 / -567）
  static String signedInteger(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_intFormat.format(value)}';
  }

  /// NT$ 貨幣格式（如 NT$1,234 / NT$123.45）
  static String currency(double value, {int decimals = 0}) {
    final formatted = switch (decimals) {
      0 => _intFormat.format(value),
      1 => _decFormat.format(value),
      _ => _dec2Format.format(value),
    };
    return 'NT\$$formatted';
  }

  /// 帶正負號的 NT$ 貨幣格式（如 +NT$1,234 / -NT$567）
  static String signedCurrency(double value, {int decimals = 0}) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${currency(value, decimals: decimals)}';
  }
}
