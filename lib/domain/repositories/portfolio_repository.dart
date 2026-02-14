import 'package:afterclose/data/database/app_database.dart';

/// 投資組合儲存庫介面
///
/// 管理持倉與交易紀錄的 CRUD 操作。
/// 支援測試時的 Mock 及不同實作。
abstract class IPortfolioRepository {
  /// 取得所有有持倉的 position
  Future<List<PortfolioPositionEntry>> getPositions();

  /// 取得單一 position by symbol
  Future<PortfolioPositionEntry?> getPosition(String symbol);

  /// 取得某 symbol 的所有交易紀錄
  Future<List<PortfolioTransactionEntry>> getTransactions(String symbol);

  /// 新增買入交易
  Future<void> addBuyTransaction({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    String? note,
  });

  /// 新增賣出交易
  Future<void> addSellTransaction({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    double? tax,
    String? note,
  });

  /// 新增股利交易
  Future<void> addDividendTransaction({
    required String symbol,
    required DateTime date,
    required double amount,
    required bool isCash,
    String? note,
  });

  /// 刪除交易紀錄
  Future<void> deleteTransaction(int txId, String symbol);
}
