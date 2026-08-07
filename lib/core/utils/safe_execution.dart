import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/core/utils/logger.dart';

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

/// [awaitPairSettled] 的單邊結果(值/錯誤/stack 三選一組合)
class SettledResult<T> {
  const SettledResult(this.value, this.error, this.stackTrace);

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
}

/// 平行等待一對 Future——**永不拋錯、零無主 rejection 窗口**。
///
/// 「先啟動兩個 Future、再依序 await」的寫法在第一個 await rethrow
/// (RateLimit/Network)時,第二個 Future 失去 listener;若它同樣失敗
/// (斷網/雙市場同時限流是高相關性失敗),rejection 成為 zone 層
/// unhandled async error(2026-07-30 審查:五處同型)。本函式在啟動
/// 當下就為兩邊掛好 onError handler,錯誤被捕捉成 [SettledResult]。
///
/// 供「需要 per-source 成敗旗標」的呼叫端(如 warning_repository 的
/// failCount/attentionSynced);只要值的場景用 [safeAwaitPair]。
Future<(SettledResult<T1>, SettledResult<T2>)> awaitPairSettled<T1, T2>(
  Future<T1> first,
  Future<T2> second,
) async {
  final s1 = first.then<SettledResult<T1>>(
    (v) => SettledResult(v, null, null),
    onError: (Object e, StackTrace st) => SettledResult<T1>(null, e, st),
  );
  final s2 = second.then<SettledResult<T2>>(
    (v) => SettledResult(v, null, null),
    onError: (Object e, StackTrace st) => SettledResult<T2>(null, e, st),
  );
  return (await s1, await s2);
}

/// [safeAwait] 的成對版:平行等待、RateLimit/Network 優先 rethrow
/// (保留原 stack、RateLimit 優先),其餘失敗各自記 warning 後回
/// fallback。取代「兩個 safeAwait 先啟動再逐一 await」的舊 pattern。
Future<(T1, T2)> safeAwaitPair<T1, T2>(
  Future<T1> first,
  Future<T2> second, {
  required T1 firstDefault,
  required T2 secondDefault,
  required String tag,
  required String firstDescription,
  required String secondDescription,
}) async {
  final (r1, r2) = await awaitPairSettled(first, second);

  for (final r in [r1, r2]) {
    final e = r.error;
    if (e is RateLimitException) {
      Error.throwWithStackTrace(e, r.stackTrace ?? StackTrace.current);
    }
  }
  for (final r in [r1, r2]) {
    final e = r.error;
    if (e is NetworkException) {
      Error.throwWithStackTrace(e, r.stackTrace ?? StackTrace.current);
    }
  }

  final T1 v1;
  if (r1.error == null) {
    v1 = r1.value as T1;
  } else {
    AppLogger.warning(tag, firstDescription, r1.error);
    v1 = firstDefault;
  }
  final T2 v2;
  if (r2.error == null) {
    v2 = r2.value as T2;
  } else {
    AppLogger.warning(tag, secondDescription, r2.error);
    v2 = secondDefault;
  }
  return (v1, v2);
}
