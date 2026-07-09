import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// 平行執行的錯誤隔離工具
///
/// 提供安全的非同步執行 helper，讓個別失敗不影響整體流程。
/// 主要用於 TWSE/TPEX 雙市場平行取得資料的場景。

/// 安全地 await 一個 Future，失敗時回傳預設值並記錄 warning。
///
/// 用於平行取得多個資料來源時，個別失敗不應中斷整體流程的場景。
///
/// ```dart
/// final twseData = await safeAwait(
///   twseFuture, <TwseDailyPrice>[],
///   tag: 'PriceRepo',
///   description: '上市價格取得失敗',
/// );
/// ```
Future<T> safeAwait<T>(
  Future<T> future,
  T defaultValue, {
  required String tag,
  required String description,
}) async {
  try {
    return await future;
  } on RateLimitException {
    rethrow;
  } on NetworkException {
    rethrow;
  } catch (e) {
    AppLogger.warning(tag, description, e);
    return defaultValue;
  }
}

/// Syncer 版 rethrow-guard：把 CLAUDE.md 的錯誤處理慣例封成型別保證。
///
/// [RateLimitException] / [NetworkException] 一律 rethrow（安全不變量，
/// 不再靠手抄 try/catch 樣板維持）；其餘失敗記 warning、可選收集到
/// [errors]（供 UpdateResult partial 警告顯示）後回傳 [fallback]。
///
/// - [label]：log 訊息主體（自動加「失敗」後綴）
/// - [errorLabel]：收集進 [errors] 的前綴；null 或 [errors] 為 null 時
///   僅 log 不收集（對應「刻意 best-effort」的呼叫點）
Future<T> guardSync<T>({
  required String tag,
  required String label,
  required T fallback,
  List<String>? errors,
  String? errorLabel,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } on RateLimitException {
    rethrow;
  } on NetworkException {
    rethrow;
  } catch (e) {
    AppLogger.warning(tag, '$label失敗', e);
    if (errors != null && errorLabel != null) {
      errors.add('$errorLabel: $e');
    }
    return fallback;
  }
}
