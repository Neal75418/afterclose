part of 'package:afterclose/data/database/app_database.dart';

/// 投資組合相關資料存取：持倉與交易紀錄
mixin _PortfolioDaoMixin on _$AppDatabase {
  // ==========================================
  // 投資組合操作（Phase 4.4）
  // ==========================================

  /// 取得所有有持倉的 position
  Future<List<PortfolioPositionEntry>> getPortfolioPositions() {
    return (select(portfolioPosition)
          ..where((t) => t.quantity.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 取得所有 position（含已清倉）
  Future<List<PortfolioPositionEntry>> getAllPortfolioPositions() {
    return (select(
      portfolioPosition,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  /// 取得單一 position by symbol
  Future<PortfolioPositionEntry?> getPortfolioPosition(String symbol) {
    return (select(
      portfolioPosition,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  /// 新增或更新 position
  Future<void> upsertPortfolioPosition(PortfolioPositionCompanion entry) {
    return into(portfolioPosition).insertOnConflictUpdate(entry);
  }

  /// 更新 position 的聚合欄位
  Future<void> updatePortfolioPosition({
    required int id,
    required double quantity,
    required double avgCost,
    required double realizedPnl,
    required double totalDividendReceived,
  }) {
    return (update(portfolioPosition)..where((t) => t.id.equals(id))).write(
      PortfolioPositionCompanion(
        quantity: Value(quantity),
        avgCost: Value(avgCost),
        realizedPnl: Value(realizedPnl),
        totalDividendReceived: Value(totalDividendReceived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 刪除 position
  Future<void> deletePortfolioPosition(int id) {
    return (delete(portfolioPosition)..where((t) => t.id.equals(id))).go();
  }

  /// 新增交易紀錄
  Future<int> insertTransaction(PortfolioTransactionCompanion entry) {
    return into(portfolioTransaction).insert(entry);
  }

  /// 取得某 symbol 的所有交易紀錄（依日期排序）
  Future<List<PortfolioTransactionEntry>> getTransactionsForSymbol(
    String symbol,
  ) {
    return (select(portfolioTransaction)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// 刪除交易紀錄
  Future<void> deleteTransaction(int id) {
    return (delete(portfolioTransaction)..where((t) => t.id.equals(id))).go();
  }

  /// 取得某 symbol 的所有 BUY 交易（用於 FIFO 計算）
  Future<List<PortfolioTransactionEntry>> getBuyTransactions(String symbol) {
    return (select(portfolioTransaction)
          ..where((t) => t.symbol.equals(symbol) & t.txType.equals('BUY'))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }
}
