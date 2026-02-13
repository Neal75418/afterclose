/// 輸入驗證工具
///
/// 提供各種輸入驗證函式，防止：
/// - SQL injection
/// - 資源耗盡攻擊
/// - 無效輸入導致的錯誤
///
/// 使用範例：
/// ```dart
/// if (!InputValidators.isValidStockSymbol(symbol)) {
///   throw ValidationException('Invalid stock symbol: $symbol');
/// }
/// ```
class InputValidators {
  /// 股票代碼格式正則表達式
  /// 台股代碼：4-6 位數字
  static const stockSymbolPattern = r'^[0-9]{4,6}$';

  /// 最大日期範圍（天數）
  /// 防止查詢過大範圍的歷史資料
  static const maxDateRangeDays = 3650; // 10年

  /// 最大股票代碼長度
  static const maxSymbolLength = 6;

  /// 最小股票代碼長度
  static const minSymbolLength = 4;

  /// 驗證股票代碼格式
  ///
  /// 台股代碼必須是 4-6 位數字
  static bool isValidStockSymbol(String symbol) {
    if (symbol.isEmpty) return false;
    if (symbol.length < minSymbolLength || symbol.length > maxSymbolLength) {
      return false;
    }
    return RegExp(stockSymbolPattern).hasMatch(symbol);
  }

  /// 驗證日期範圍
  ///
  /// 確保日期範圍在合理範圍內（最多 10 年）
  static bool isValidDateRange(DateTime start, DateTime end) {
    // 結束日期不能早於開始日期
    if (end.isBefore(start)) {
      return false;
    }

    // 計算日期範圍
    final days = end.difference(start).inDays;

    // 不能超過最大範圍
    return days <= maxDateRangeDays;
  }

  /// 驗證日期不在未來
  ///
  /// 股票資料不應該有未來的日期
  static bool isNotFutureDate(DateTime date) {
    final now = DateTime.now();
    // 允許最多 1 天的誤差（時區問題）
    return date.isBefore(now.add(const Duration(days: 1)));
  }

  /// 淨化股票代碼
  ///
  /// 移除非數字字元並限制長度
  static String sanitizeStockSymbol(String input) {
    // 移除所有非數字字元
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');

    // 限制長度
    if (digits.length > maxSymbolLength) {
      return digits.substring(0, maxSymbolLength);
    }

    return digits;
  }

  /// 驗證分頁參數
  ///
  /// 確保分頁參數在合理範圍內
  static bool isValidPagination({
    required int page,
    required int pageSize,
    int maxPageSize = 100,
  }) {
    // 頁碼必須 >= 1
    if (page < 1) return false;

    // 每頁數量必須在 1-100 之間
    if (pageSize < 1 || pageSize > maxPageSize) return false;

    return true;
  }

  /// 驗證分數範圍
  ///
  /// 分數應該在 0-100 之間
  static bool isValidScore(double score) {
    return score >= 0 && score <= 100;
  }

  /// 驗證百分比
  ///
  /// 百分比應該在 -100 到 100 之間（支援負成長）
  static bool isValidPercentage(double percentage) {
    return percentage >= -100 && percentage <= 100;
  }

  /// 驗證年份
  ///
  /// 年份應該在合理範圍內（1990 - 當前年份 + 1）
  static bool isValidYear(int year) {
    final currentYear = DateTime.now().year;
    return year >= 1990 && year <= currentYear + 1;
  }

  /// 驗證季度
  ///
  /// 季度應該是 1-4
  static bool isValidQuarter(int quarter) {
    return quarter >= 1 && quarter <= 4;
  }

  /// 驗證月份
  ///
  /// 月份應該是 1-12
  static bool isValidMonth(int month) {
    return month >= 1 && month <= 12;
  }

  /// 驗證字串長度
  ///
  /// 防止過長的字串導致效能問題
  static bool isValidStringLength(
    String input, {
    int maxLength = 1000,
    int minLength = 0,
  }) {
    return input.length >= minLength && input.length <= maxLength;
  }

  /// 驗證清單大小
  ///
  /// 防止過大的清單導致記憶體問題
  static bool isValidListSize(List<dynamic> list, {int maxSize = 1000}) {
    return list.length <= maxSize;
  }
}

/// 驗證異常
class ValidationException implements Exception {
  ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}
