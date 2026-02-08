import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/core/constants/market_index_names.dart';

/// 大盤指數歷史同步器
///
/// 從 TWSE MI_INDEX API 取得指數資料，篩選 Dashboard 重點指數後寫入 MarketIndex 表。
/// 供大盤總覽走勢圖使用。
///
/// - [sync] 同步當日資料，資料不足時自動觸發 [backfill]。
/// - [backfill] 回補近 45 天歷史，確保走勢圖至少有 ~20 個交易日的資料點。
class MarketIndexSyncer {
  MarketIndexSyncer({
    required AppDatabase database,
    required TwseClient twseClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _twse = twseClient,
       _clock = clock;

  final AppDatabase _db;
  final TwseClient _twse;
  final AppClock _clock;

  /// DB 中指數筆數低於此值時，自動觸發回補
  static const _backfillThreshold = 20;

  /// 回補天數（日曆天，包含非交易日，確保涵蓋 ~30 個交易日）
  static const _backfillCalendarDays = 45;

  /// API 請求間隔，避免 TWSE rate limit
  static const _requestDelay = Duration(milliseconds: 500);

  /// 同步當日大盤指數至 DB
  ///
  /// 僅同步 Dashboard 需要的 4 個重點指數，回傳寫入筆數。
  /// 同步後若 DB 資料不足 [_backfillThreshold] 筆，自動觸發歷史回補。
  Future<int> sync() async {
    var synced = 0;

    try {
      final indices = await _twse.getMarketIndices();

      if (indices.isNotEmpty) {
        final companions = _filterAndConvert(indices);
        if (companions.isNotEmpty) {
          await _db.upsertMarketIndices(companions);
          synced = companions.length;
          AppLogger.info('MarketIndexSyncer', '指數同步完成: $synced 筆');
        }
      } else {
        AppLogger.debug('MarketIndexSyncer', '無指數資料可同步（非交易日或盤中）');
      }
    } catch (e) {
      AppLogger.warning('MarketIndexSyncer', '指數同步失敗: $e');
    }

    // 無論今日同步是否成功，都檢查是否需要歷史回補
    await _backfillIfNeeded();

    return synced;
  }

  /// 回補近 [_backfillCalendarDays] 天的歷史指數資料
  ///
  /// 逐日呼叫 TWSE API（僅交易日），每次間隔 [_requestDelay]。
  /// 回傳總寫入筆數。
  Future<int> backfill() async {
    final now = _clock.now();
    var totalInserted = 0;
    var apiCalls = 0;

    AppLogger.info('MarketIndexSyncer', '開始歷史回補（過去 $_backfillCalendarDays 天）');

    for (var i = 1; i <= _backfillCalendarDays; i++) {
      final date = now.subtract(Duration(days: i));

      if (!TaiwanCalendar.isTradingDay(date)) continue;

      try {
        if (apiCalls > 0) {
          await Future.delayed(_requestDelay);
        }

        final indices = await _twse.getMarketIndices(date: date);
        apiCalls++;

        if (indices.isEmpty) continue;

        final companions = _filterAndConvert(indices);
        if (companions.isEmpty) continue;

        await _db.upsertMarketIndices(companions);
        totalInserted += companions.length;
      } catch (e) {
        // 單日失敗不中斷整個回補
        AppLogger.debug(
          'MarketIndexSyncer',
          '回補 ${date.toString().substring(0, 10)} 失敗: $e',
        );
      }
    }

    AppLogger.info(
      'MarketIndexSyncer',
      '歷史回補完成: $totalInserted 筆 ($apiCalls 次 API 呼叫)',
    );
    return totalInserted;
  }

  /// 檢查 DB 資料是否不足，不足則觸發回補
  Future<void> _backfillIfNeeded() async {
    final history = await _db.getIndexHistoryBatch(
      MarketIndexNames.dashboardIndices,
      days: 30,
    );

    // 取任一指數的筆數作為判斷依據
    final sampleCount = history.values.isEmpty
        ? 0
        : history.values.first.length;

    if (sampleCount < _backfillThreshold) {
      AppLogger.info(
        'MarketIndexSyncer',
        '指數歷史不足 ($sampleCount < $_backfillThreshold)，開始回補',
      );
      await backfill();
    }
  }

  /// 篩選 Dashboard 重點指數並轉換為 DB companion
  List<MarketIndexCompanion> _filterAndConvert(List<TwseMarketIndex> indices) {
    final targetNames = MarketIndexNames.dashboardIndices.toSet();
    final filtered = indices
        .where((idx) => targetNames.contains(idx.name))
        .toList();

    if (filtered.isEmpty) {
      AppLogger.debug('MarketIndexSyncer', '無匹配的重點指數');
      return [];
    }

    return filtered
        .map(
          (idx) => MarketIndexCompanion(
            date: Value(idx.date),
            name: Value(idx.name),
            close: Value(idx.close),
            change: Value(idx.change),
            changePercent: Value(idx.changePercent),
          ),
        )
        .toList();
  }
}
