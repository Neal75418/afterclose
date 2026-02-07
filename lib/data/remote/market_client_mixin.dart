import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// TWSE / TPEX client 的共用工具。
///
/// 提供統一的 Dio 建立方式、JSON 解碼、以及錯誤處理，
/// 避免兩個 market client 之間的程式碼重複。
abstract final class MarketClientMixin {
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
      } catch (_) {
        AppLogger.warning(tag, '$operation: JSON 解析失敗');
        return null;
      }
    }
    if (decoded is! Map<String, dynamic>) {
      AppLogger.warning(tag, '$operation: 非預期資料型別');
      return null;
    }
    return decoded;
  }

  /// 統一的 API 請求錯誤處理。
  ///
  /// 包裝 [fn] 的執行，將 [DioException] 轉換為 [NetworkException]，
  /// 並記錄錯誤日誌。[tag] 為日誌標籤（如 'TWSE'），[operation] 為操作描述。
  static Future<T> executeRequest<T>(
    String tag,
    String operation,
    Future<T> Function() fn,
  ) async {
    try {
      return await fn();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.warning(tag, '$operation: 連線逾時');
        throw NetworkException('$tag connection timeout', e);
      }
      AppLogger.warning(tag, '$operation: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? '$tag network error', e);
    } on AppException {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(tag, '$operation: 非預期錯誤', e, stack);
      rethrow;
    }
  }
}
