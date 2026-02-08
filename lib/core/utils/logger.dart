import 'package:flutter/foundation.dart';

/// 日誌等級，用於過濾輸出
enum LogLevel { debug, info, warning, error }

/// 結構化日誌工具，確保應用程式日誌格式一致
///
/// 使用範例：
/// ```dart
/// AppLogger.debug('PriceRepo', 'Fetching prices for 2330');
/// AppLogger.info('UpdateService', 'Update completed');
/// AppLogger.warning('StockDetail', 'No institutional data for $symbol');
/// AppLogger.error('Network', 'API request failed', e, stackTrace);
/// ```
abstract final class AppLogger {
  /// 最低輸出等級（僅在 debug 模式生效）
  static LogLevel minLevel = LogLevel.debug;

  /// 記錄 debug 訊息
  static void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// 記錄 info 訊息
  static void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// 記錄 warning 訊息，可附帶例外與堆疊追蹤
  static void warning(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.warning, tag, message, error, stackTrace);
  }

  /// 記錄 error 訊息，可附帶例外與堆疊追蹤
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Skip logs below minimum level
    if (level.index < minLevel.index) return;

    // Only log in debug mode
    if (!kDebugMode) return;

    final prefix = switch (level) {
      LogLevel.debug => '[D]',
      LogLevel.info => '[I]',
      LogLevel.warning => '[W]',
      LogLevel.error => '[E]',
    };

    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final logMessage = '$timestamp $prefix [$tag] $message';

    debugPrint(logMessage);

    if (error != null) {
      debugPrint('$timestamp $prefix [$tag] Error: $error');
    }

    if (stackTrace != null) {
      debugPrint('$timestamp $prefix [$tag] StackTrace:\n$stackTrace');
    }
  }
}
