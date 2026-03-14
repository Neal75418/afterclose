import 'dart:async';
import 'dart:io';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// 將例外轉換為使用者友善的錯誤訊息
///
/// 避免直接在 UI 顯示 `e.toString()` 暴露技術細節。
/// 所有 provider catch 區塊應使用此函式：
/// ```dart
/// catch (e) {
///   state = state.copyWith(error: ErrorDisplay.message(e));
/// }
/// ```
abstract final class ErrorDisplay {
  /// 將例外物件轉換為使用者可讀的訊息
  static String message(Object error) {
    // AppException 子類別已包含中文訊息
    if (error is AppException) {
      return error.message;
    }

    // 標準例外類型
    if (error is SocketException) {
      return '網路連線失敗，請檢查網路設定';
    }
    if (error is TimeoutException) {
      return error.message ?? '連線逾時，請稍後再試';
    }
    if (error is HttpException) {
      return '伺服器回應異常，請稍後再試';
    }
    if (error is FormatException) {
      return '資料格式錯誤，請稍後再試';
    }

    // 未預期的例外：記錄完整錯誤以便除錯
    AppLogger.warning('ErrorDisplay', '未分類的例外類型: ${error.runtimeType}', error);
    return '發生未預期的錯誤，請稍後再試';
  }
}
