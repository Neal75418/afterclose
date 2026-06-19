import 'package:afterclose/data/database/app_database.dart';

/// 市場資料儲存庫介面
///
/// 提供財報同步 + 市場 / 同步狀態查詢。
abstract class IMarketDataRepository {
  /// 同步資產負債表
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 最新有 daily_price 資料的交易日（用來判斷需不需要 sync 與顯示資料日）
  Future<DateTime?> getLatestDataDate();

  /// 最新有 daily_institutional 資料的交易日
  Future<DateTime?> getLatestInstitutionalDate();

  /// 最近一次完成的 daily update 紀錄（時間與狀態，用於 UI 顯示「最後更新時間」）
  Future<UpdateRunEntry?> getLatestUpdateRun();

  /// 最近 N 筆 update_run 歷史紀錄（UI 顯示「更新紀錄」list 用）
  ///
  /// 依 id DESC 排（最新在前）。包含 SUCCESS / PARTIAL / FAILED 各種狀態。
  Future<List<UpdateRunEntry>> getRecentUpdateRuns({int limit = 30});
}
