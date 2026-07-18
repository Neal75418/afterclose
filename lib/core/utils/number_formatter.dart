import 'package:easy_localization/easy_localization.dart';

/// 統一數字格式化工具
///
/// 提供千分位、本地化單位（億/B、萬/K）等常用數字格式化方法。
class AppNumberFormat {
  AppNumberFormat._();

  static final _intFormat = NumberFormat('#,##0');
  static final _decFormat = NumberFormat('#,##0.0');
  static final _dec2Format = NumberFormat('#,##0.00');

  /// 整數千分位格式（如 1,234,567）
  static String integer(double value) => _intFormat.format(value);

  /// 自動選擇本地化單位：億/B、萬/K、千分位
  ///
  /// 用於成交量、金額等大數值的友善顯示。
  static String compact(double value) {
    if (value.abs() >= 1e8) {
      return '${(value / 1e8).toStringAsFixed(1)}${'unit.billion'.tr()}';
    }
    if (value.abs() >= 1e4) {
      return '${(value / 1e4).toStringAsFixed(1)}${'unit.tenThousand'.tr()}';
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

  /// 依顯示精度捨入，供「文字」與「配色/方向」共用同一個值。
  ///
  /// 例：`roundForDisplay(-0.004, 2) == 0`——顯示為 0.00% 時，配色與箭頭
  /// 也應據此判為中性（不著漲跌色、不指方向），避免文字與顏色互相矛盾。
  static double roundForDisplay(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals));

  /// 帶正負號的定點小數：**先依 [decimals] 捨入再判正負**。
  ///
  /// 平盤（或微負值捨入後歸零）一律回傳正零（如 `0.00`），
  /// 不帶 `+`、也不會出現 `-0.00` 負零。
  static String signedFixed(double value, {int decimals = 2}) {
    final rounded = roundForDisplay(value, decimals);
    if (rounded == 0) return 0.0.toStringAsFixed(decimals);
    return '${rounded > 0 ? '+' : ''}${rounded.toStringAsFixed(decimals)}';
  }

  /// 帶正負號的百分比：**先捨入再判正負**（如 +1.67% / 0.00% / -2.30%）。
  ///
  /// 平盤與微負值捨入後歸零時顯示 `0.00%`（不帶 `+`、非 `-0.00%`）。
  static String signedPercent(double value, {int decimals = 2}) =>
      '${signedFixed(value, decimals: decimals)}%';
}
