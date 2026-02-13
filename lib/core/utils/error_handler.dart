import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// 細化的錯誤處理 Wrapper
///
/// 針對不同類型的錯誤採取不同的處理策略：
/// - RateLimitException: 必須向上傳播（rethrow）
/// - NetworkException: 記錄警告並返回 fallback 值
/// - ParseException: 記錄錯誤並返回 fallback 值
/// - 其他錯誤: 記錄錯誤和堆疊資訊並返回 fallback 值
///
/// 範例：
/// ```dart
/// final revenue = await withRateLimitRethrow(
///   () => _finMind.getMonthlyRevenue(symbol),
///   0,
///   'FundamentalRepo',
///   '同步月營收',
/// );
/// ```
Future<T> withRateLimitRethrow<T>(
  Future<T> Function() operation,
  T fallbackValue,
  String tag,
  String description,
) async {
  try {
    return await operation();
  } on RateLimitException {
    // Rate Limit 必須向上傳播，讓呼叫方決定是否重試
    AppLogger.warning(tag, '$description: API 速率限制觸發');
    rethrow;
  } on NetworkException catch (e) {
    // 網路錯誤：稍後可能恢復，記錄警告
    AppLogger.warning(tag, '$description: 網路錯誤，返回 fallback', e);
    return fallbackValue;
  } on ParseException catch (e) {
    // 解析錯誤：資料格式問題，記錄錯誤
    AppLogger.error(tag, '$description: 資料解析錯誤', e);
    return fallbackValue;
  } on DatabaseException catch (e) {
    // 資料庫錯誤：可能是資料損壞或查詢錯誤
    AppLogger.error(tag, '$description: 資料庫錯誤', e);
    return fallbackValue;
  } catch (e, stack) {
    // 未預期的錯誤：記錄完整堆疊資訊
    AppLogger.error(tag, '$description: 未預期錯誤', e, stack);
    return fallbackValue;
  }
}

/// 細化的錯誤處理 Wrapper（無 fallback 版本）
///
/// 適用於不需要 fallback 值的情境，所有錯誤都會被 rethrow，
/// 但會先記錄日誌以便追蹤。
///
/// 範例：
/// ```dart
/// await withErrorLogging(
///   () => _db.insertAnalysis(analysis),
///   'AnalysisRepo',
///   '儲存分析結果',
/// );
/// ```
Future<T> withErrorLogging<T>(
  Future<T> Function() operation,
  String tag,
  String description,
) async {
  try {
    return await operation();
  } on RateLimitException catch (e) {
    AppLogger.warning(tag, '$description: API 速率限制觸發', e);
    rethrow;
  } on NetworkException catch (e) {
    AppLogger.warning(tag, '$description: 網路錯誤', e);
    rethrow;
  } on ParseException catch (e) {
    AppLogger.error(tag, '$description: 資料解析錯誤', e);
    rethrow;
  } on DatabaseException catch (e) {
    AppLogger.error(tag, '$description: 資料庫錯誤', e);
    rethrow;
  } catch (e, stack) {
    AppLogger.error(tag, '$description: 未預期錯誤', e, stack);
    rethrow;
  }
}

/// 同步版本的錯誤處理 Wrapper
///
/// 適用於同步操作。
T withRateLimitRethrowSync<T>(
  T Function() operation,
  T fallbackValue,
  String tag,
  String description,
) {
  try {
    return operation();
  } on RateLimitException {
    AppLogger.warning(tag, '$description: API 速率限制觸發');
    rethrow;
  } on NetworkException catch (e) {
    AppLogger.warning(tag, '$description: 網路錯誤，返回 fallback', e);
    return fallbackValue;
  } on ParseException catch (e) {
    AppLogger.error(tag, '$description: 資料解析錯誤', e);
    return fallbackValue;
  } on DatabaseException catch (e) {
    AppLogger.error(tag, '$description: 資料庫錯誤', e);
    return fallbackValue;
  } catch (e, stack) {
    AppLogger.error(tag, '$description: 未預期錯誤', e, stack);
    return fallbackValue;
  }
}
