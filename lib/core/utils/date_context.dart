/// Utility class for consistent date handling across the app.
///
/// Provides normalized dates for database queries and UI display.
/// All dates are normalized to UTC midnight to ensure consistent comparison.
class DateContext {
  DateContext._({required this.today, required this.historyStart});

  /// Create a DateContext for current date with standard 5-day history lookback.
  factory DateContext.now({int historyDays = 5}) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    return DateContext._(
      today: today,
      historyStart: today.subtract(Duration(days: historyDays)),
    );
  }

  /// Create a DateContext with custom history lookback period.
  factory DateContext.withLookback(int days) {
    return DateContext.now(historyDays: days);
  }

  /// Today's date normalized to UTC midnight.
  final DateTime today;

  /// Start date for price history queries.
  final DateTime historyStart;

  /// Normalize any DateTime to UTC midnight for consistent comparison.
  static DateTime normalize(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day (ignoring time).
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get the earlier of two dates (normalized).
  /// Returns null if both dates are null.
  static DateTime? earlierOf(DateTime? a, DateTime? b) {
    if (a == null && b == null) return null;
    if (a == null) return normalize(b!);
    if (b == null) return normalize(a);
    final normalA = normalize(a);
    final normalB = normalize(b);
    return normalA.isBefore(normalB) ? normalA : normalB;
  }

  /// Check if date a is before or same as date b (normalized comparison).
  static bool isBeforeOrEqual(DateTime a, DateTime b) {
    final normalA = normalize(a);
    final normalB = normalize(b);
    return normalA.isBefore(normalB) || isSameDay(normalA, normalB);
  }
}
