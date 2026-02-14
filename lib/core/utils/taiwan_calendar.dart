import 'package:afterclose/core/utils/logger.dart';

/// 台灣股市交易日曆
///
/// 提供台灣證券交易所（TWSE）與櫃買中心（TPEx）的交易日驗證。
///
/// 資料來源：
/// - 台灣證券交易所官方休市公告
/// - https://www.twse.com.tw/
class TaiwanCalendar {
  TaiwanCalendar._();

  /// 是否已記錄過期警告（避免重複警告）
  static bool _hasLoggedExpiryWarning = false;

  /// 2024 年台股休市日
  static final Set<DateTime> _holidays2024 = {
    // 元旦
    DateTime.utc(2024, 1, 1),
    // 農曆春節 (2/8-2/14)
    DateTime.utc(2024, 2, 8),
    DateTime.utc(2024, 2, 9),
    DateTime.utc(2024, 2, 10),
    DateTime.utc(2024, 2, 11),
    DateTime.utc(2024, 2, 12),
    DateTime.utc(2024, 2, 13),
    DateTime.utc(2024, 2, 14),
    // 228 和平紀念日
    DateTime.utc(2024, 2, 28),
    // 兒童節/清明節 (4/4-4/5)
    DateTime.utc(2024, 4, 4),
    DateTime.utc(2024, 4, 5),
    // 勞動節
    DateTime.utc(2024, 5, 1),
    // 端午節 (6/10)
    DateTime.utc(2024, 6, 10),
    // 中秋節 (9/17)
    DateTime.utc(2024, 9, 17),
    // 國慶日
    DateTime.utc(2024, 10, 10),
  };

  /// 2025 年台股休市日
  static final Set<DateTime> _holidays2025 = {
    // 元旦
    DateTime.utc(2025, 1, 1),
    // 農曆春節 (1/27-2/4)
    DateTime.utc(2025, 1, 27),
    DateTime.utc(2025, 1, 28),
    DateTime.utc(2025, 1, 29),
    DateTime.utc(2025, 1, 30),
    DateTime.utc(2025, 1, 31),
    DateTime.utc(2025, 2, 1),
    DateTime.utc(2025, 2, 2),
    DateTime.utc(2025, 2, 3),
    DateTime.utc(2025, 2, 4),
    // 228 和平紀念日
    DateTime.utc(2025, 2, 28),
    // 兒童節/清明節 (4/3-4/4)
    DateTime.utc(2025, 4, 3),
    DateTime.utc(2025, 4, 4),
    // 勞動節
    DateTime.utc(2025, 5, 1),
    // 端午節 (5/30-6/2)
    DateTime.utc(2025, 5, 30),
    DateTime.utc(2025, 5, 31),
    DateTime.utc(2025, 6, 1),
    DateTime.utc(2025, 6, 2),
    // 中秋節 (10/6-10/7)
    DateTime.utc(2025, 10, 6),
    DateTime.utc(2025, 10, 7),
    // 國慶日
    DateTime.utc(2025, 10, 10),
  };

  /// 2026 年台股休市日（預估）
  static final Set<DateTime> _holidays2026 = {
    // 元旦
    DateTime.utc(2026, 1, 1),
    // 農曆春節 (封關日 2/11 週三，2/12-2/20 休市)
    DateTime.utc(2026, 2, 12),
    DateTime.utc(2026, 2, 13),
    DateTime.utc(2026, 2, 14),
    DateTime.utc(2026, 2, 15),
    DateTime.utc(2026, 2, 16),
    DateTime.utc(2026, 2, 17),
    DateTime.utc(2026, 2, 18),
    DateTime.utc(2026, 2, 19),
    DateTime.utc(2026, 2, 20),
    // 228 和平紀念日
    DateTime.utc(2026, 2, 28),
    // 兒童節/清明節 (4/3-4/6 estimated)
    DateTime.utc(2026, 4, 3),
    DateTime.utc(2026, 4, 4),
    DateTime.utc(2026, 4, 5),
    DateTime.utc(2026, 4, 6),
    // 勞動節
    DateTime.utc(2026, 5, 1),
    // 端午節 (6/19 estimated)
    DateTime.utc(2026, 6, 19),
    // 中秋節 (9/25 estimated)
    DateTime.utc(2026, 9, 25),
    // 國慶日
    DateTime.utc(2026, 10, 10),
  };

  /// 2027 年台股休市日（預估）
  ///
  /// 農曆日期根據萬年曆推算，實際日期以證交所公告為準
  static final Set<DateTime> _holidays2027 = {
    // 元旦
    DateTime.utc(2027, 1, 1),
    // 農曆春節 (2/5-2/11 estimated，農曆初一約 2/6)
    DateTime.utc(2027, 2, 5),
    DateTime.utc(2027, 2, 6),
    DateTime.utc(2027, 2, 7),
    DateTime.utc(2027, 2, 8),
    DateTime.utc(2027, 2, 9),
    DateTime.utc(2027, 2, 10),
    DateTime.utc(2027, 2, 11),
    // 228 和平紀念日（週日，補假週一）
    DateTime.utc(2027, 2, 28),
    DateTime.utc(2027, 3, 1),
    // 兒童節/清明節 (4/4-4/5 estimated)
    DateTime.utc(2027, 4, 4),
    DateTime.utc(2027, 4, 5),
    // 勞動節 (5/1 週六，不需列入，週末本來就休市)
    // 端午節 (6/9 estimated)
    DateTime.utc(2027, 6, 9),
    // 中秋節 (10/15 estimated)
    DateTime.utc(2027, 10, 15),
    // 國慶日（週日，補假週一）
    DateTime.utc(2027, 10, 10),
    DateTime.utc(2027, 10, 11),
  };

  /// 所有休市日彙總
  static final Set<DateTime> _allHolidays = {
    ..._holidays2024,
    ..._holidays2025,
    ..._holidays2026,
    ..._holidays2027,
  };

  /// 日曆資料涵蓋的最大年份
  static const int _maxYear = 2027;

  /// 檢查日期是否為台股交易日
  ///
  /// 符合以下條件回傳 true：
  /// - 非週末（週六、週日）
  /// - 非國定假日
  ///
  /// 若日期超出日曆資料範圍，會回落到週末判斷並記錄警告。
  static bool isTradingDay(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    // 檢查是否超出日曆資料範圍
    if (date.year > _maxYear) {
      _logExpiryWarningOnce(date.year);
      // 回落到週末判斷（假設平日都是交易日）
      return true;
    }

    final normalized = DateTime.utc(date.year, date.month, date.day);
    return !_allHolidays.contains(normalized);
  }

  /// 記錄過期警告（只記錄一次）
  static void _logExpiryWarningOnce(int year) {
    if (!_hasLoggedExpiryWarning) {
      _hasLoggedExpiryWarning = true;
      AppLogger.warning(
        'TaiwanCalendar',
        '日曆資料已過期：目前年份 $year 超出資料範圍 (最大 $_maxYear)，'
            '將回落到週末判斷。請更新日曆資料。',
      );
    }
  }

  /// 檢查日期是否為國定假日（不含週末）
  static bool isHoliday(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return _allHolidays.contains(normalized);
  }

  /// 取得下一個交易日
  ///
  /// 若給定日期為交易日則直接回傳，否則回傳下一個交易日。
  static DateTime getNextTradingDay(DateTime date) {
    var current = date;
    while (!isTradingDay(current)) {
      current = current.add(const Duration(days: 1));
    }
    return current;
  }

  /// 取得前一個交易日
  ///
  /// 若給定日期為交易日則直接回傳，否則回傳前一個交易日。
  static DateTime getPreviousTradingDay(DateTime date) {
    var current = date;
    while (!isTradingDay(current)) {
      current = current.subtract(const Duration(days: 1));
    }
    return current;
  }

  /// 計算兩日期間的交易日數量（含頭尾）
  static int getTradingDaysBetween(DateTime start, DateTime end) {
    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }

    var count = 0;
    var current = start;
    while (!current.isAfter(end)) {
      if (isTradingDay(current)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// 檢查指定年度是否有日曆資料
  static bool hasDataForYear(int year) {
    return year >= 2024 && year <= _maxYear;
  }

  /// 檢查日曆資料是否已過期
  ///
  /// 若當前年份超出資料範圍則回傳 true
  static bool isCalendarExpired() {
    return DateTime.now().year > _maxYear;
  }

  /// 取得日曆資料涵蓋的最大年份
  static int get maxYear => _maxYear;
}
