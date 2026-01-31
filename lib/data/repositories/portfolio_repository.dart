import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.dart';

/// 投資組合 Repository
///
/// 管理持倉與交易紀錄，使用 FIFO 方法計算損益。
class PortfolioRepository {
  PortfolioRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  /// 台灣券商手續費率（0.1425%）
  static const double brokerageFeeRate = 0.001425;

  /// 台灣證交稅率（0.3%）
  static const double transactionTaxRate = 0.003;

  // ==========================================
  // 持倉查詢
  // ==========================================

  Future<List<PortfolioPositionEntry>> getPositions() =>
      _db.getPortfolioPositions();

  Future<PortfolioPositionEntry?> getPosition(String symbol) =>
      _db.getPortfolioPosition(symbol);

  Future<List<PortfolioTransactionEntry>> getTransactions(String symbol) =>
      _db.getTransactionsForSymbol(symbol);

  // ==========================================
  // 交易操作
  // ==========================================

  /// 計算建議手續費
  static double calculateFee(double quantity, double price) {
    final fee = quantity * price * brokerageFeeRate;
    // 台灣券商最低手續費 20 元
    return fee < 20 ? 20 : fee;
  }

  /// 計算建議交易稅（僅賣出）
  static double calculateTax(double quantity, double price) {
    return quantity * price * transactionTaxRate;
  }

  /// 新增買進交易
  Future<void> addBuyTransaction({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    String? note,
  }) async {
    if (quantity <= 0) throw ArgumentError('Quantity must be positive');
    if (price <= 0) throw ArgumentError('Price must be positive');

    final actualFee = fee ?? calculateFee(quantity, price);

    await _db.insertTransaction(
      PortfolioTransactionCompanion.insert(
        symbol: symbol,
        txType: 'BUY',
        date: date,
        quantity: quantity,
        price: price,
        fee: Value(actualFee),
        note: Value(note),
      ),
    );

    await _recalculatePosition(symbol);
  }

  /// 新增賣出交易
  ///
  /// 若賣出數量超過持有數量，會拋出 [StateError]。
  Future<void> addSellTransaction({
    required String symbol,
    required DateTime date,
    required double quantity,
    required double price,
    double? fee,
    double? tax,
    String? note,
  }) async {
    if (quantity <= 0) throw ArgumentError('Quantity must be positive');
    if (price <= 0) throw ArgumentError('Price must be positive');

    // 驗證賣出數量不超過持有量
    final position = await _db.getPortfolioPosition(symbol);
    final currentQty = position?.quantity ?? 0;
    if (quantity > currentQty) {
      throw StateError('portfolio.sellExceedsHolding');
    }

    final actualFee = fee ?? calculateFee(quantity, price);
    final actualTax = tax ?? calculateTax(quantity, price);

    await _db.insertTransaction(
      PortfolioTransactionCompanion.insert(
        symbol: symbol,
        txType: 'SELL',
        date: date,
        quantity: quantity,
        price: price,
        fee: Value(actualFee),
        tax: Value(actualTax),
        note: Value(note),
      ),
    );

    await _recalculatePosition(symbol);
  }

  /// 新增股利交易
  Future<void> addDividendTransaction({
    required String symbol,
    required DateTime date,
    required double amount,
    required bool isCash,
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');

    await _db.insertTransaction(
      PortfolioTransactionCompanion.insert(
        symbol: symbol,
        txType: isCash ? 'DIVIDEND_CASH' : 'DIVIDEND_STOCK',
        date: date,
        quantity: amount, // 股利金額或股數
        price: 0,
        note: Value(note),
      ),
    );

    await _recalculatePosition(symbol);
  }

  /// 刪除交易紀錄並重新計算
  Future<void> deleteTransaction(int txId, String symbol) async {
    await _db.deleteTransaction(txId);
    await _recalculatePosition(symbol);
  }

  // ==========================================
  // FIFO 損益計算
  // ==========================================

  /// 從所有交易紀錄重新計算某 symbol 的持倉
  ///
  /// 包在 DB transaction 中確保讀取交易與寫入 position 的一致性
  Future<void> _recalculatePosition(String symbol) async {
    await _db.transaction(() async {
      final transactions = await _db.getTransactionsForSymbol(symbol);

      if (transactions.isEmpty) {
        // 如果沒有交易紀錄，刪除 position
        final existing = await _db.getPortfolioPosition(symbol);
        if (existing != null) {
          await _db.deletePortfolioPosition(existing.id);
        }
        return;
      }

      // FIFO lot queue: 買入手續費分攤至每股成本，賣出費用直接扣除
      final List<_FifoLot> lots = [];
      double realizedPnl = 0;
      double totalDividend = 0;

      for (final tx in transactions) {
        switch (tx.txType) {
          case 'BUY':
            // 將買入手續費分攤至每股成本
            final feePerShare = tx.quantity > 0 ? tx.fee / tx.quantity : 0.0;
            lots.add(
              _FifoLot(
                quantity: tx.quantity,
                costPerShare: tx.price + feePerShare,
              ),
            );
          case 'SELL':
            double remainingToSell = tx.quantity;
            final sellPrice = tx.price;

            while (remainingToSell > 0 && lots.isNotEmpty) {
              final lot = lots.first;

              if (lot.quantity <= remainingToSell) {
                // 整批售出
                realizedPnl += (sellPrice - lot.costPerShare) * lot.quantity;
                remainingToSell -= lot.quantity;
                lots.removeAt(0);
              } else {
                // 部分售出
                realizedPnl += (sellPrice - lot.costPerShare) * remainingToSell;
                lot.quantity -= remainingToSell;
                remainingToSell = 0;
              }
            }
            // 賣出手續費與交易稅直接從已實現損益扣除
            realizedPnl -= tx.fee + tx.tax;
          case 'DIVIDEND_CASH':
            totalDividend += tx.quantity;
          case 'DIVIDEND_STOCK':
            // 股票股利：增加持股，成本為 0
            if (tx.quantity > 0) {
              lots.add(_FifoLot(quantity: tx.quantity, costPerShare: 0));
            }
        }
      }

      // 計算剩餘持倉的加權平均成本
      double totalQuantity = 0;
      double totalCost = 0;
      for (final lot in lots) {
        totalQuantity += lot.quantity;
        totalCost += lot.quantity * lot.costPerShare;
      }
      final avgCost = totalQuantity > 0 ? totalCost / totalQuantity : 0.0;

      // 更新或建立 position
      final existing = await _db.getPortfolioPosition(symbol);
      if (existing != null) {
        await _db.updatePortfolioPosition(
          id: existing.id,
          quantity: totalQuantity,
          avgCost: avgCost,
          realizedPnl: realizedPnl,
          totalDividendReceived: totalDividend,
        );
      } else {
        await _db.upsertPortfolioPosition(
          PortfolioPositionCompanion.insert(
            symbol: symbol,
            quantity: Value(totalQuantity),
            avgCost: Value(avgCost),
            realizedPnl: Value(realizedPnl),
            totalDividendReceived: Value(totalDividend),
          ),
        );
      }
    });
  }
}

/// FIFO lot（先進先出批次）
class _FifoLot {
  _FifoLot({required this.quantity, required this.costPerShare});

  double quantity;
  final double costPerShare;
}
