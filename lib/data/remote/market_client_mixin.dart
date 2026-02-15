import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// TWSE / TPEX client 的共用工具。
///
/// 提供統一的 Dio 建立方式、JSON 解碼、以及錯誤處理，
/// 避免兩個 market client 之間的程式碼重複。
abstract final class MarketClientMixin {
  static const _maxRetries = 2;
  static const _baseDelayMs = 1000;
  static final _random = Random();

  /// 建立市場 API 用的 [Dio] 實例。
  ///
  /// 兩個市場共用相同的超時、Header 與回應類型設定。
  static Dio createDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(
          seconds: ApiConfig.twseConnectTimeoutSec,
        ),
        receiveTimeout: const Duration(
          seconds: ApiConfig.twseReceiveTimeoutSec,
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
        responseType: ResponseType.json,
      ),
    );
  }

  /// 將 response.data 統一解碼為 [Map]。
  ///
  /// iOS 平台上 Dio 偶爾會回傳 JSON String 而非已解析的 Map，
  /// 此方法統一處理兩種情況。回傳 `null` 代表解碼失敗。
  static Map<String, dynamic>? decodeResponseData(
    Object? data,
    String tag,
    String operation,
  ) {
    var decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (e) {
        AppLogger.warning(tag, '$operation: JSON 解析失敗: $e');
        return null;
      }
    }
    if (decoded is! Map<String, dynamic>) {
      AppLogger.warning(tag, '$operation: 非預期資料型別');
      return null;
    }
    return decoded;
  }

  /// 統一的 API 請求錯誤處理（含自動重試）。
  ///
  /// 包裝 [fn] 的執行，將 [DioException] 轉換為 [NetworkException]，
  /// 並記錄錯誤日誌。[tag] 為日誌標籤（如 'TWSE'），[operation] 為操作描述。
  ///
  /// 可重試的錯誤（逾時、連線失敗、5xx）會自動重試最多 [_maxRetries] 次，
  /// 使用指數退避 + 抖動。不可重試的錯誤（4xx、解析錯誤）立即拋出。
  static Future<T> executeRequest<T>(
    String tag,
    String operation,
    Future<T> Function() fn,
  ) async {
    int attempt = 0;

    while (attempt <= _maxRetries) {
      try {
        return await fn();
      } on DioException catch (e, stack) {
        // 不可重試的錯誤：立即拋出
        if (!_isRetryable(e)) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            AppLogger.warning(tag, '$operation: 連線逾時', e, stack);
            throw NetworkException('$tag connection timeout', e);
          }
          AppLogger.warning(
            tag,
            '$operation: ${e.message ?? "網路錯誤"}',
            e,
            stack,
          );
          throw NetworkException(e.message ?? '$tag network error', e);
        }

        // 可重試的錯誤：嘗試重試
        attempt++;
        if (attempt <= _maxRetries) {
          AppLogger.info(
            tag,
            '$operation: 重試 $attempt/$_maxRetries (${e.type.name})',
          );
          await _delay(attempt);
          continue;
        }

        // 重試耗盡
        AppLogger.warning(tag, '$operation: 重試 $_maxRetries 次後仍失敗', e, stack);
        throw NetworkException(
          '$tag request failed after $_maxRetries retries',
          e,
        );
      } on AppException {
        rethrow;
      } catch (e, stack) {
        AppLogger.error(tag, '$operation: 非預期錯誤', e, stack);
        rethrow;
      }
    }

    // 理論上不會到達（while 迴圈內的每條路徑都會 return/throw/continue）
    throw NetworkException('$tag request failed unexpectedly');
  }

  /// 判斷 [DioException] 是否可重試。
  ///
  /// 逾時、連線錯誤、5xx 可重試；4xx 等客戶端錯誤不重試。
  static bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        return statusCode != null && statusCode >= 500;
      default:
        return false;
    }
  }

  /// 指數退避延遲（含 ±25% 抖動）。
  static Future<void> _delay(int attempt) async {
    final exponentialDelay = _baseDelayMs * (1 << (attempt - 1));
    final jitter = (_random.nextDouble() - 0.5) * 0.5 * exponentialDelay;
    await Future.delayed(
      Duration(milliseconds: (exponentialDelay + jitter).round()),
    );
  }
}
