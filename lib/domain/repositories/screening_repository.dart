import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/screening_condition.dart';

/// 自訂選股的資料存取介面
///
/// 將 SQL 查詢邏輯從 ScreeningService 抽離，
/// 使 domain 層不直接依賴資料庫實作。
abstract class IScreeningRepository {
  /// 執行 SQL 預篩，回傳符合條件的股票代碼與掃描總數
  Future<({List<String> symbols, int totalScanned})> executeSqlFilter(
    List<ScreeningCondition> conditions,
    DateTime targetDate,
  );

  /// 批次載入價格歷史（記憶體後篩用）
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// 批次載入觸發原因（記憶體後篩用）
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  );

  // ==================================================
  // 自訂選股策略 CRUD
  //
  // 介面接受純值（name / conditionsJson / id），Drift Companion 構造留在
  // data 層實作 — 避免 presentation 直接 import Drift 寫入 primitive。
  // ==================================================

  /// 取得所有已儲存策略（依 updatedAt DESC）
  Future<List<ScreeningStrategyEntry>> loadStrategies();

  /// 新增策略，回傳自動產生的 ID
  Future<int> saveStrategy({
    required String name,
    required String conditionsJson,
  });

  /// 重新命名策略
  Future<void> renameStrategy(int id, String newName);

  /// 刪除策略
  Future<void> deleteStrategy(int id);
}
