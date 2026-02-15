import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';

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

  // ==================================================
  // 回應驗證與解析 Helper
  // ==================================================
  //
  // 錯誤處理慣例：
  // - 非 200 HTTP status → 呼叫端 throw ApiException
  // - stat != 'OK' / 空資料 → 回傳 null（非交易日正常情況）
  // - 個別 row 解析失敗 → 跳過，debug log

  /// 驗證 TWSE stat-based 回應。
  ///
  /// TWSE API 在 stat == 'OK' 且 data 存在時才是有效回應。
  /// 回傳 data 中的 rows，無資料時回傳 null。
  static List<dynamic>? validateTwseStat(
    Map<String, dynamic> data,
    String tag,
    String operation,
  ) {
    final stat = data['stat'];
    if (stat != 'OK' || data['data'] == null) {
      AppLogger.warning(tag, '$operation: 無資料 (stat=$stat)');
      return null;
    }
    return data['data'] as List<dynamic>;
  }

  /// 提取 TPEX tables 格式回應中的資料。
  ///
  /// TPEX API 回傳 `{ tables: [{ date: "...", data: [...] }] }` 格式。
  /// 回傳 (actualDate, rows) record，無資料時回傳 null。
  static ({DateTime date, List<dynamic> rows})? extractTpexTable(
    Map<String, dynamic> data,
    DateTime fallbackDate,
    String tag,
    String operation,
  ) {
    final tables = data['tables'] as List<dynamic>?;
    if (tables == null || tables.isEmpty) {
      AppLogger.warning(tag, '$operation: 無 tables');
      return null;
    }

    final firstTable = tables[0] as Map<String, dynamic>?;
    if (firstTable == null) {
      AppLogger.warning(tag, '$operation: 無資料表');
      return null;
    }

    final dateStr = firstTable['date'] as String?;
    final actualDate =
        (dateStr != null ? TwParseUtils.parseSlashRocDate(dateStr) : null) ??
        fallbackDate;

    final rows = firstTable['data'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) {
      AppLogger.warning(tag, '$operation: 無資料');
      return null;
    }

    return (date: actualDate, rows: rows);
  }

  /// 統一解析資料 rows 並記錄結果日誌。
  ///
  /// 逐 row 套用 [parser]，跳過回傳 null 的 row。
  /// 結束後輸出 info log 含成功筆數、日期、略過筆數。
  static List<T> parseRows<T>({
    required List<dynamic> rows,
    required T? Function(List<dynamic> row) parser,
    required String tag,
    required String operation,
    required DateTime date,
  }) {
    var failedCount = 0;
    final results = <T>[];

    for (final row in rows) {
      final parsed = parser(row as List<dynamic>);
      if (parsed != null) {
        results.add(parsed);
      } else {
        failedCount++;
      }
    }

    final dateFormatted = TwParseUtils.formatDateYmd(date);
    if (failedCount > 0) {
      AppLogger.info(
        tag,
        '$operation: ${results.length} 筆 ($dateFormatted, 略過 $failedCount 筆)',
      );
    } else {
      AppLogger.info(tag, '$operation: ${results.length} 筆 ($dateFormatted)');
    }

    return results;
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
