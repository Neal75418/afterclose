import 'package:flutter/foundation.dart';

/// Log levels for filtering output
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Structured logger for consistent logging across the app.
///
/// Usage:
/// ```dart
/// AppLogger.debug('PriceRepo', 'Fetching prices for 2330');
/// AppLogger.info('UpdateService', 'Update completed');
/// AppLogger.warning('StockDetail', 'No institutional data for $symbol');
/// AppLogger.error('Network', 'API request failed', e, stackTrace);
/// ```
abstract final class AppLogger {
  /// Minimum log level to output (only affects debug builds)
  static LogLevel minLevel = LogLevel.debug;

  /// Log a debug message
  static void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log an info message
  static void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log a warning message
  static void warning(String tag, String message, [Object? error]) {
    _log(LogLevel.warning, tag, message, error);
  }

  /// Log an error message with optional exception and stack trace
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

    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
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
