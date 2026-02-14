import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 日誌等級，用於過濾輸出
enum LogLevel { debug, info, warning, error }

/// 結構化日誌工具，確保應用程式日誌格式一致
///
/// 使用範例：
/// ```dart
/// AppLogger.debug('PriceRepo', '取得 2330 價格資料');
/// AppLogger.info('UpdateService', '更新完成');
/// AppLogger.warning('StockDetail', '無 $symbol 的法人資料');
/// AppLogger.error('Network', 'API 請求失敗', e, stackTrace);
/// ```
///
/// 整合 Sentry：
/// - `error()` 自動上報至 Sentry（`Sentry.captureException`）
/// - `warning()` 加入 Sentry breadcrumb 供後續錯誤追蹤參考
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
  ///
  /// 同時加入 Sentry breadcrumb，供後續錯誤上報時提供上下文。
  static void warning(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.warning, tag, message, error, stackTrace);

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: '[$tag] $message',
        category: tag,
        level: SentryLevel.warning,
        data: error != null ? {'error': error.toString()} : null,
      ),
    );
  }

  /// 記錄 error 訊息，可附帶例外與堆疊追蹤
  ///
  /// 同時上報至 Sentry（若已初始化）。
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, tag, message, error, stackTrace);

    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('logger.tag', tag);
          scope.setContexts('logger', {'message': message, 'tag': tag});
        },
      );
    }
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // 低於最低等級的日誌不輸出
    if (level.index < minLevel.index) return;

    // 僅在 debug 模式輸出日誌
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
