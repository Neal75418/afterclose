import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 大盤指數歷史同步器
///
/// 從 TWSE MI_INDEX API 取得當日指數資料，寫入 MarketIndex 表。
/// 供大盤總覽走勢圖使用。
class MarketIndexSyncer {
  MarketIndexSyncer({
    required AppDatabase database,
    required TwseClient twseClient,
  })  : _db = database,
        _twse = twseClient;

  final AppDatabase _db;
  final TwseClient _twse;

  /// 同步當日大盤指數至 DB
  ///
  /// 回傳寫入筆數。
  Future<int> sync() async {
    try {
      final indices = await _twse.getMarketIndices();

      if (indices.isEmpty) {
        AppLogger.debug('MarketIndexSyncer', '無指數資料可同步（非交易日或盤中）');
        return 0;
      }

      final companions = indices.map((idx) {
        return MarketIndexCompanion(
          date: Value(idx.date),
          name: Value(idx.name),
          close: Value(idx.close),
          change: Value(idx.change),
          changePercent: Value(idx.changePercent),
        );
      }).toList();

      await _db.upsertMarketIndices(companions);

      AppLogger.info(
        'MarketIndexSyncer',
        '指數同步完成: ${companions.length} 筆 (${indices.first.date.toString().substring(0, 10)})',
      );
      return companions.length;
    } catch (e) {
      AppLogger.warning('MarketIndexSyncer', '指數同步失敗: $e');
      return 0;
    }
  }
}
