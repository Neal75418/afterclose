/// 日期處理工具類別，確保應用程式中日期處理的一致性
///
/// 提供標準化的日期供資料庫查詢與 UI 顯示使用。
/// 所有日期皆標準化為 UTC 午夜，確保比較時的一致性。
class DateContext {
  DateContext._({required this.today, required this.historyStart});

  /// 以目前日期建立 DateContext，預設回溯 5 天歷史資料
  factory DateContext.now({int historyDays = 5}) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    return DateContext._(
      today: today,
      historyStart: today.subtract(Duration(days: historyDays)),
    );
  }

  /// 以指定日期建立 DateContext
  factory DateContext.forDate(DateTime date, {int historyDays = 5}) {
    final normalized = normalize(date);
    return DateContext._(
      today: normalized,
      historyStart: normalized.subtract(Duration(days: historyDays)),
    );
  }

  /// 以自訂回溯天數建立 DateContext
  factory DateContext.withLookback(int days) {
    return DateContext.now(historyDays: days);
  }

  /// 今日日期（標準化為 UTC 午夜）
  final DateTime today;

  /// 價格歷史查詢的起始日期
  final DateTime historyStart;

  /// 將任意 DateTime 標準化為 UTC 午夜，確保比較一致性
  static DateTime normalize(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// 檢查兩個日期是否為同一天（忽略時間）
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 取得兩日期中較早的日期（已標準化）
  ///
  /// 若兩者皆為 null 則回傳 null。
  static DateTime? earlierOf(DateTime? a, DateTime? b) {
    if (a == null && b == null) return null;
    if (a == null) return normalize(b!);
    if (b == null) return normalize(a);
    final normalA = normalize(a);
    final normalB = normalize(b);
    return normalA.isBefore(normalB) ? normalA : normalB;
  }

  /// 檢查日期 a 是否早於或等於日期 b（標準化比較）
  static bool isBeforeOrEqual(DateTime a, DateTime b) {
    final normalA = normalize(a);
    final normalB = normalize(b);
    return normalA.isBefore(normalB) || isSameDay(normalA, normalB);
  }
}
