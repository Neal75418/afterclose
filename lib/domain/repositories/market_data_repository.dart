import 'package:afterclose/data/database/app_database.dart';

/// 市場資料儲存庫介面
///
/// 提供財報指標、還原價、週線、52 週高低點的查詢與同步功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IMarketDataRepository {
  /// 同步資產負債表
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 取得財務指標
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    int quarters = 8,
  });

  /// 取得還原價歷史
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    int days = 120,
  });

  /// 取得週線歷史
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    int weeks = 52,
  });
}
