import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';

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
  /// 將例外物件轉換為使用者可讀的本地化訊息
  static String message(Object error) {
    // ValidationException 走 i18n 翻譯（messageKey 是 translation key）。
    // 必須在通用 AppException 分支之前，否則會早回傳未翻譯的 key。
    if (error is ValidationException) {
      return error.messageKey.tr();
    }

    // AppException 子類別已包含中文訊息
    if (error is AppException) {
      return error.message;
    }

    // 標準例外類型 — 使用 i18n key
    if (error is SocketException) {
      return 'error.network'.tr();
    }
    if (error is TimeoutException) {
      return 'error.timeout'.tr();
    }
    if (error is HttpException) {
      return 'error.server'.tr();
    }
    if (error is FormatException) {
      return 'error.format'.tr();
    }

    // 未預期的例外：記錄完整錯誤以便除錯
    AppLogger.warning('ErrorDisplay', '未分類的例外類型', error);
    return 'error.unknown'.tr();
  }

  /// 判斷錯誤訊息是否為網路相關（用於 UI 選擇空狀態樣式）
  ///
  /// 比對中英文關鍵字以支援雙語系
  static bool isNetworkError(String errorMessage) {
    return errorMessage.contains('網路') ||
        errorMessage.contains('連線') ||
        errorMessage.contains('Network') ||
        errorMessage.contains('network') ||
        errorMessage.contains('timed out');
  }
}
