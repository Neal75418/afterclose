import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/models/extensions/dto_extensions.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 大盤指數歷史同步器
///
/// 從 TWSE MI_INDEX API 取得指數資料，篩選 Dashboard 重點指數後寫入 MarketIndex 表。
/// 供大盤總覽走勢圖使用。
///
/// - [sync] 同步當日資料，資料不足時自動觸發 [backfill]。
/// - [backfill] 回補近 45 天歷史，確保走勢圖至少有 ~20 個交易日的資料點。
class MarketIndexSyncer {
  const MarketIndexSyncer({
    required AppDatabase database,
    required TwseClient twseClient,
    TpexClient? tpexClient,
    FinMindClient? finMindClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _twse = twseClient,
       _tpex = tpexClient,
       _finMind = finMindClient,
       _clock = clock;

  final AppDatabase _db;
  final TwseClient _twse;
  final TpexClient? _tpex;
  final FinMindClient? _finMind;
  final AppClock _clock;

  /// DB 中指數筆數低於此值時，自動觸發回補
  static const _backfillThreshold = 20;

  /// 回補天數（日曆天，包含非交易日，確保涵蓋 ~30 個交易日）
  static const _backfillCalendarDays = 45;

  /// 查詢 DB 時額外加入的緩衝天數，確保不遺漏邊界資料
  static const _queryBufferDays = 10;

  /// 觸發回補判斷時查詢的歷史天數
  static const _historyCheckDays = 30;

  /// API 請求間隔，避免 TWSE rate limit
  static const _requestDelay = Duration(
    milliseconds: ApiConfig.syncerBatchDelayMs,
  );

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
          AppLogger.info('MarketIndexSyncer', 'TWSE 指數同步完成: $synced 筆');
        }
      } else {
        AppLogger.debug('MarketIndexSyncer', '無 TWSE 指數資料可同步（非交易日或盤中）');
      }
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('MarketIndexSyncer', 'TWSE 指數同步失敗', e);
    }

    // 同步 TPEx 櫃買指數（OpenAPI 回傳近月歷史，一次寫入）
    if (_tpex != null) {
      try {
        final tpexIndices = await _tpex.getTpexIndex();
        if (tpexIndices.isNotEmpty) {
          final companions = tpexIndices
              .map((idx) => idx.toDatabaseCompanion())
              .toList();
          await _db.upsertMarketIndices(companions);
          synced += companions.length;
          AppLogger.info(
            'MarketIndexSyncer',
            'TPEx 指數同步完成: ${companions.length} 筆',
          );
        }
      } on RateLimitException {
        rethrow;
      } on NetworkException {
        rethrow;
      } catch (e) {
        AppLogger.warning('MarketIndexSyncer', 'TPEx 指數同步失敗', e);
      }
    }

    // 同步 FinMind 含息報酬指數
    if (_finMind != null) {
      try {
        final triData = await _finMind.getTotalReturnIndex();
        if (triData.length >= 2) {
          final companions = _convertTotalReturnIndex(triData);
          if (companions.isNotEmpty) {
            await _db.upsertMarketIndices(companions);
            synced += companions.length;
            AppLogger.info(
              'MarketIndexSyncer',
              '含息報酬指數同步完成: ${companions.length} 筆',
            );
          }
        }
      } on RateLimitException {
        rethrow;
      } on NetworkException {
        rethrow;
      } catch (e) {
        AppLogger.warning('MarketIndexSyncer', '含息報酬指數同步失敗', e);
      }
    }

    // 無論今日同步是否成功，都檢查是否需要歷史回補
    await _backfillIfNeeded();

    return synced;
  }

  /// 回補近 [_backfillCalendarDays] 天的歷史指數資料
  ///
  /// 先查詢 DB 已有的日期以跳過重複呼叫，遇到 API 限流時提早中止。
  /// 回傳總寫入筆數。
  Future<int> backfill() async {
    final now = _clock.now();
    var totalInserted = 0;
    var apiCalls = 0;

    // 查詢 DB 已有的指數日期，避免重複呼叫 API
    final existingHistory = await _db.getIndexHistoryBatch(
      MarketIndexNames.dashboardIndices,
      days: _backfillCalendarDays + _queryBufferDays,
      now: now,
    );
    final existingDates = <String>{};
    for (final entries in existingHistory.values) {
      for (final entry in entries) {
        existingDates.add(
          '${entry.date.year}-${entry.date.month}-${entry.date.day}',
        );
      }
    }

    // 計算需要回補的交易日
    final datesToFetch = <DateTime>[];
    for (var i = 1; i <= _backfillCalendarDays; i++) {
      final date = now.subtract(Duration(days: i));
      if (!TaiwanCalendar.isTradingDay(date)) continue;
      final key = '${date.year}-${date.month}-${date.day}';
      if (existingDates.contains(key)) continue;
      datesToFetch.add(date);
    }

    if (datesToFetch.isEmpty) {
      AppLogger.info('MarketIndexSyncer', '歷史回補: DB 已有所有交易日資料，跳過');
      return 0;
    }

    AppLogger.info(
      'MarketIndexSyncer',
      '開始歷史回補: ${datesToFetch.length} 個交易日需補（已有 ${existingDates.length} 日）',
    );

    for (final date in datesToFetch) {
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
      } on RateLimitException {
        AppLogger.warning(
          'MarketIndexSyncer',
          'API 限流，中止歷史回補 (已完成 $apiCalls 次呼叫)',
        );
        break;
      } on NetworkException {
        rethrow;
      } catch (e) {
        // 單日失敗不中斷整個回補
        AppLogger.debug(
          'MarketIndexSyncer',
          '回補 ${DateContext.formatYmd(date)} 失敗: $e',
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
      days: _historyCheckDays,
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

  /// 將含息報酬指數轉換為 DB companion
  ///
  /// FinMind 只回傳 date + price，需自行計算 change/changePct（前後日比較）
  List<MarketIndexCompanion> _convertTotalReturnIndex(
    List<FinMindTotalReturnIndex> data,
  ) {
    // 按日期升序排列
    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));
    final companions = <MarketIndexCompanion>[];

    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final prevPrice = i > 0 ? sorted[i - 1].price : item.price;
      final change = item.price - prevPrice;
      final changePct = prevPrice != 0 ? (change / prevPrice) * 100 : 0.0;

      companions.add(
        MarketIndexCompanion(
          date: Value(item.date),
          name: const Value(MarketIndexNames.totalReturnIndex),
          close: Value(item.price),
          change: Value(i > 0 ? change : 0),
          changePercent: Value(i > 0 ? changePct : 0),
        ),
      );
    }

    return companions;
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

    return filtered.map((idx) => idx.toDatabaseCompanion()).toList();
  }
}
