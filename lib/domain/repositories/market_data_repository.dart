/// 市場資料儲存庫介面
///
/// 提供財報同步功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IMarketDataRepository {
  /// 同步資產負債表
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });
}
