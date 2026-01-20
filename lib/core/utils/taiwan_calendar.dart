/// Taiwan Stock Market Calendar
///
/// Provides trading day verification for Taiwan Stock Exchange (TWSE)
/// and Taipei Exchange (TPEx).
///
/// Data sources:
/// - Taiwan Stock Exchange official holiday announcements
/// - https://www.twse.com.tw/
class TaiwanCalendar {
  TaiwanCalendar._();

  /// 2024 Taiwan stock market holidays
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

  /// 2025 Taiwan stock market holidays
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

  /// 2026 Taiwan stock market holidays (estimated)
  static final Set<DateTime> _holidays2026 = {
    // 元旦
    DateTime.utc(2026, 1, 1),
    // 農曆春節 (2/14-2/20 estimated)
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

  /// All holidays combined
  static final Set<DateTime> _allHolidays = {
    ..._holidays2024,
    ..._holidays2025,
    ..._holidays2026,
  };

  /// Check if a date is a Taiwan stock market trading day
  ///
  /// Returns true if:
  /// - Not a weekend (Saturday/Sunday)
  /// - Not a national holiday
  static bool isTradingDay(DateTime date) {
    // Check weekend
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    // Normalize to UTC for comparison
    final normalized = DateTime.utc(date.year, date.month, date.day);

    // Check holiday
    return !_allHolidays.contains(normalized);
  }

  /// Check if a date is a holiday (not including weekends)
  static bool isHoliday(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return _allHolidays.contains(normalized);
  }

  /// Get the next trading day from a given date
  ///
  /// If the given date is a trading day, returns it.
  /// Otherwise, returns the next trading day.
  static DateTime getNextTradingDay(DateTime date) {
    var current = date;
    while (!isTradingDay(current)) {
      current = current.add(const Duration(days: 1));
    }
    return current;
  }

  /// Get the previous trading day from a given date
  ///
  /// If the given date is a trading day, returns it.
  /// Otherwise, returns the previous trading day.
  static DateTime getPreviousTradingDay(DateTime date) {
    var current = date;
    while (!isTradingDay(current)) {
      current = current.subtract(const Duration(days: 1));
    }
    return current;
  }

  /// Get the number of trading days between two dates (inclusive)
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

  /// Check if calendar data is available for a given year
  static bool hasDataForYear(int year) {
    return year >= 2024 && year <= 2026;
  }
}
