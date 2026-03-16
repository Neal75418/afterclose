import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';

/// 內部人股權轉讓同步器
///
/// 從 TPEX OpenAPI (ap12_O) 取得董監事/經理人/大股東的
/// 股權轉讓申報記錄，寫入 InsiderTransfer 表。
///
/// - 資料來源為「最新」全市場轉讓申報（非歷史）
/// - 使用 InsertOrReplace 避免重複
/// - 僅寫入 StockMaster 中存在的股票（FK constraint）
class InsiderTransferSyncer {
  InsiderTransferSyncer({
    required AppDatabase database,
    required TpexClient tpexClient,
  }) : _db = database,
       _tpex = tpexClient;

  final AppDatabase _db;
  final TpexClient _tpex;

  /// 同步內部人轉讓資料
  ///
  /// 回傳寫入的筆數。
  Future<int> sync() async {
    try {
      final transfers = await _tpex.getInsiderTransfers();
      if (transfers.isEmpty) {
        AppLogger.debug('InsiderTransferSyncer', 'API 回傳空資料');
        return 0;
      }

      // 取得 DB 中所有已知股票（FK constraint）
      final knownStocks = await _db.getAllActiveStocks();
      final knownSymbols = knownStocks.map((s) => s.symbol).toSet();

      final companions = <InsiderTransferCompanion>[];
      for (final t in transfers) {
        if (!knownSymbols.contains(t.symbol)) continue;

        companions.add(
          InsiderTransferCompanion(
            symbol: Value(t.symbol),
            reportDate: Value(t.reportDate),
            identity: Value(t.identity),
            name: Value(t.name),
            transferMethod: Value(t.transferMethod),
            transferShares: Value(t.transferShares),
            currentHolding: Value(t.currentHolding),
            validPeriodStart: Value(t.validPeriodStart),
            validPeriodEnd: Value(t.validPeriodEnd),
          ),
        );
      }

      if (companions.isEmpty) {
        AppLogger.debug('InsiderTransferSyncer', '無可寫入的轉讓資料');
        return 0;
      }

      await _db.insertInsiderTransfers(companions);

      AppLogger.info(
        'InsiderTransferSyncer',
        '同步完成: ${companions.length} 筆轉讓申報',
      );
      return companions.length;
    } catch (e) {
      AppLogger.warning('InsiderTransferSyncer', '同步失敗: $e');
      rethrow;
    }
  }
}
