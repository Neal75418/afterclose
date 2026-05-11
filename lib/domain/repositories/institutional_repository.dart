import 'package:afterclose/data/database/app_database.dart';

/// 三大法人買賣超資料儲存庫介面
///
/// 提供法人資料的查詢、同步與分析功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IInstitutionalRepository {
  /// 取得法人資料歷史供分析使用
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    int? days,
  });

  /// 同步單檔股票的法人資料
  Future<int> syncInstitutionalData(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 同步指定日期的全市場法人資料
  Future<int> syncAllMarketInstitutional(DateTime date, {bool force = false});

  /// 用 TWSE + TPEx batch endpoint 回補單一交易日**指定股票**的法人資料
  ///
  /// 用於 backfill：相較於 `syncInstitutionalData(symbol, startDate, endDate)`
  /// 對每檔股票分別呼叫 FinMind（per-symbol，2 年 backfill 數千 calls 必然
  /// 吃光免費額度），本方法走 TWSE T86 + TPEx OpenAPI 的 daily batch，
  /// **一次 call 拿該日全市場法人資料**。完整 2 年 backfill 從約 8000×N
  /// 降到約 500×2 (TWSE + TPEx) ≈ 1000 次，且兩個 endpoint 都免費沒額度。
  ///
  /// 與 [syncAllMarketInstitutional] 的差別：本方法用 [targetSymbols] 作為
  /// 寫入白名單（對齊 backfill CLI 的 symbol 範圍語意），且不做 freshness
  /// skip check（resumability 由 idempotent upsert 保證）。
  ///
  /// 回傳實際寫入的 row 數。
  ///
  /// 例外政策：[RateLimitException] / [NetworkException] rethrow；其他例外
  /// 包成 [DatabaseException]。TWSE / TPEx 兩個 source 任一失敗會 fall back
  /// 到只用另一個 source（與 [syncAllMarketInstitutional] 的容錯一致）。
  Future<int> backfillInstitutionalByDate({
    required DateTime date,
    required Set<String> targetSymbols,
  });

  /// 清除所有法人資料
  Future<int> clearAllData();
}
