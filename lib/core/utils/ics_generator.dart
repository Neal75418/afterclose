import 'package:afterclose/data/database/app_database.dart';

/// iCalendar (.ics) 檔案產生器
///
/// 遵循 RFC 5545 規範，產生可被 Apple Calendar / Google Calendar 等
/// 系統行事曆 app 匯入的 .ics 格式。
abstract final class IcsGenerator {
  static const _crlf = '\r\n';

  /// 產生包含多個事件的 VCALENDAR 字串
  static String generateCalendar(List<StockEventEntry> events) {
    final buffer = StringBuffer()
      .._w('BEGIN:VCALENDAR')
      .._w('VERSION:2.0')
      .._w('PRODID:-//AfterClose//EventCalendar//ZH')
      .._w('CALSCALE:GREGORIAN')
      .._w('METHOD:PUBLISH');

    for (final event in events) {
      _writeEvent(buffer, event);
    }

    buffer._w('END:VCALENDAR');
    return buffer.toString();
  }

  /// 產生單一事件的 VCALENDAR 字串
  static String generateSingleEvent(StockEventEntry event) {
    return generateCalendar([event]);
  }

  static void _writeEvent(StringBuffer buffer, StockEventEntry event) {
    final startDate = _formatDate(event.eventDate);
    // RFC 5545: VALUE=DATE 的 DTEND 是 exclusive，全天事件需 +1 天
    final endDate = _formatDate(event.eventDate.add(const Duration(days: 1)));
    // DTSTAMP: RFC 5545 REQUIRED，使用事件建立時間
    final stamp = _formatDateTime(event.createdAt);

    buffer
      .._w('BEGIN:VEVENT')
      .._w('DTSTART;VALUE=DATE:$startDate')
      .._w('DTEND;VALUE=DATE:$endDate')
      .._w('DTSTAMP:$stamp')
      .._w('SUMMARY:${_escape(event.title)}')
      .._w('UID:afterclose-event-${event.id}@afterclose.app');

    if (event.description != null && event.description!.isNotEmpty) {
      buffer._w('DESCRIPTION:${_escape(event.description!)}');
    }

    buffer._w('END:VEVENT');
  }

  /// 格式化日期為 iCalendar VALUE=DATE 格式 (YYYYMMDD)
  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// 格式化為 iCalendar DTSTAMP 格式 (YYYYMMDDTHHMMSSZ)
  static String _formatDateTime(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y$mo${d}T$h$mi${s}Z';
  }

  /// RFC 5545 文字 escaping
  static String _escape(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\r\n', '\\n')
        .replaceAll('\r', '\\n')
        .replaceAll('\n', '\\n');
  }
}

/// StringBuffer extension for CRLF line writes
extension on StringBuffer {
  void _w(String line) {
    write(line);
    write(IcsGenerator._crlf);
  }
}
