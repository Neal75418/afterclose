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
  } catch (e) {
    AppLogger.warning(tag, '$description: $e');
    return defaultValue;
  }
}
