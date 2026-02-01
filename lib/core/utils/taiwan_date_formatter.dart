/// 民國年（ROC calendar）格式化工具
///
/// 將西元年轉換為民國年顯示格式，符合台灣用戶習慣。
/// 民國元年 = 西元 1912 年。
class TaiwanDateFormatter {
  TaiwanDateFormatter._();

  /// 西元年與民國年的差距
  static const int _rocOffset = 1911;

  /// 將西元年轉為民國年數字
  ///
  /// 例：2024 → 113
  static int toROCYear(int year) => year - _rocOffset;

  /// 將西元年轉為民國年字串，附加「年」後綴
  ///
  /// 例：2024 → "113 年"
  static String formatYear(int year) => '${toROCYear(year)} 年';

  /// 格式化年/月（用於營收表格）
  ///
  /// 例：(2024, 1) → "113/01"
  static String formatYearMonth(int year, int month) {
    return '${toROCYear(year)}/${month.toString().padLeft(2, '0')}';
  }

  /// 格式化年度 + 季度（用於 EPS 表格）
  ///
  /// 例：(2024, 2) → "113 Q2"
  static String formatQuarter(int year, int quarter) {
    return '${toROCYear(year)} Q$quarter';
  }

  /// 同時顯示西元年與民國年
  ///
  /// 例：2024 → "2024 (民113)"
  static String formatDualYear(int year) {
    return '$year (民${toROCYear(year)})';
  }
}
