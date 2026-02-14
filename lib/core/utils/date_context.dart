import 'package:afterclose/core/utils/logger.dart';

/// 日期處理工具類別，確保應用程式中日期處理的一致性
///
/// 提供標準化的日期供資料庫查詢與 UI 顯示使用。
/// 所有日期皆標準化為本地時間午夜，以匹配資料庫中的日期格式。
class DateContext {
  DateContext._({required this.today, required this.historyStart});

  /// 以目前日期建立 DateContext，預設回溯 5 天歷史資料
  factory DateContext.now({int historyDays = 5}) {
    final now = DateTime.now();
    // 使用本地時間午夜，以匹配資料庫中儲存的日期格式
    final today = DateTime(now.year, now.month, now.day);
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

  /// 今日日期（標準化為本地時間午夜）
  final DateTime today;

  /// 價格歷史查詢的起始日期
  final DateTime historyStart;

  /// 將任意 DateTime 標準化為本地時間午夜，確保比較一致性
  ///
  /// 使用本地時間以匹配資料庫中儲存的日期格式（Drift 預設以本地時間存取）
  static DateTime normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 檢查兩個日期是否為同一天（忽略時間）
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 檢查兩個日期是否在同一週（週一至週日，忽略時間）
  static bool isSameWeek(DateTime a, DateTime b) {
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return isSameDay(aWeekStart, bWeekStart);
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

  // ==================================================
  // 日期格式化與解析
  // ==================================================

  /// 將 DateTime 格式化為 'YYYY-MM-DD' 字串
  ///
  /// 此方法比 `toIso8601String().substring(0, 10)` 更具可讀性
  static String formatYmd(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 安全地解析 'YYYY-MM-DD' 格式字串為 DateTime
  ///
  /// 解析失敗時回傳 null，而非拋出例外
  static DateTime? tryParseYmd(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      AppLogger.debug('DateContext', '解析日期失敗: $dateStr ($e)');
      return null;
    }
  }

  /// 解析 'YYYY-MM-DD' 格式字串，失敗時回傳預設值
  static DateTime parseYmdOr(String? dateStr, DateTime defaultValue) {
    return tryParseYmd(dateStr) ?? defaultValue;
  }

  /// 解析季度日期字串（如 "2024-Q1" → DateTime(2024, 1, 1)）
  ///
  /// 若非季度格式則視為標準日期字串解析。
  static DateTime parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
  }
}
