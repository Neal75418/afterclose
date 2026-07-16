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
/// 供大盤總覽走勢圖與大盤位階（MA20/MA60 乖離）使用。
///
/// - [sync] 同步當日資料，資料不足時自動觸發 [backfill]；同步後一律嘗試
///   [backfillDeepHistory]（fail-safe，見其 doc）。
/// - [backfill] 回補近 45 天歷史，確保走勢圖至少有 ~20 個交易日的資料點。
/// - [backfillDeepHistory] 分批回補至 ~370 天（~250 交易日）深度，解鎖
///   大盤位階所需的 MA60（60 交易日）長窗——DB 清空後只剩近期 API 回應窗
///   （~42 天），不足 MA60，且僅靠每日累積需近一年才能自然補齊。
class MarketIndexSyncer {
  const MarketIndexSyncer({
    required AppDatabase database,
    required TwseClient twseClient,
    TpexClient? tpexClient,
    FinMindClient? finMindClient,
    AppClock clock = const SystemClock(),
    Duration requestDelay = const Duration(
      milliseconds: ApiConfig.syncerBatchDelayMs,
    ),
  }) : _db = database,
       _twse = twseClient,
       _tpex = tpexClient,
       _finMind = finMindClient,
       _clock = clock,
       _requestDelay = requestDelay;

  final AppDatabase _db;
  final TwseClient _twse;
  final TpexClient? _tpex;
  final FinMindClient? _finMind;
  final AppClock _clock;

  /// DB 中指數筆數低於此值時，自動觸發回補
  ///
  /// 只需 ~20 個交易日供 Dashboard 走勢圖。曾為「相對強度 RS」拉到 200（~1 年深度），
  /// 但 RS 已驗證無 edge 取消，且 200 會在 force re-sync 觸發 365 天逐日 TWSE 回補
  /// burst → 撞 TWSE 反爬限流（redirect loop）→ 中止同步。已回退。
  static const _backfillThreshold = 20;

  /// 回補天數（日曆天，包含非交易日）。45 ≈ ~20 個交易日，足夠走勢圖。
  /// 逐日查 TWSE MI_INDEX（免費、含加權與各產業類指數），不耗 FinMind 配額。
  static const _backfillCalendarDays = 45;

  /// 查詢 DB 時額外加入的緩衝天數，確保不遺漏邊界資料
  static const _queryBufferDays = 10;

  /// 觸發回補判斷時查詢的歷史天數
  static const _historyCheckDays = 30;

  /// API 請求間隔，避免 TWSE rate limit（可由建構子覆寫，測試用 [Duration.zero]）
  final Duration _requestDelay;

  /// 同步當日大盤指數至 DB
  ///
  /// 僅同步 Dashboard 需要的 4 個重點指數，回傳寫入筆數。
  /// 同步後若 DB 資料不足 [_backfillThreshold] 筆，自動觸發歷史回補。
  Future<int> sync() async {
    var synced = 0;

    try {
      final indices = await _twse.getMarketIndices();

      if (indices.isNotEmpty) {
        final companions = _filterAndConvert(indices, _clock.now());
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

    // 深度回補（解鎖大盤位階 MA60 長窗深度）：完全 fail-safe，任何例外
    // （含 RateLimitException / NetworkException）皆不影響當日同步結果，
    // 也不設 ctx.rateLimitedAbort（見 backfillDeepHistory doc）。
    try {
      await backfillDeepHistory();
    } catch (e) {
      AppLogger.warning('MarketIndexSyncer', '指數深度回補失敗，不影響當日同步', e);
    }

    return synced;
  }

  /// 回補近 [_backfillCalendarDays] 天的歷史指數資料
  ///
  /// 先查詢 DB 已有的日期以跳過重複呼叫，遇到 API 限流時提早中止。
  /// 回傳總寫入筆數。
  Future<int> backfill() async {
    final now = _clock.now();

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

    final (totalInserted, apiCalls) = await _fetchAndUpsertDates(
      datesToFetch,
      '回補',
    );

    AppLogger.info(
      'MarketIndexSyncer',
      '歷史回補完成: $totalInserted 筆 ($apiCalls 次 API 呼叫)',
    );
    return totalInserted;
  }

  /// 深度回補指數歷史，解鎖大盤位階（MA60）所需的長窗深度
  ///
  /// 從 DB 目前最早的 [MarketIndexNames.taiex] 資料往前一天開始往回走，
  /// 逐日呼叫 TWSE MI_INDEX（含 date 參數），跳過非交易日與已覆蓋日期，
  /// 直到達成 [ApiConfig.indexBackfillTargetCalendarDays] 目標深度或用完
  /// 本次上限 [ApiConfig.indexBackfillMaxDaysPerRun]。
  ///
  /// 所有 dashboardIndices 皆由同一次 TWSE 回應寫入，日期集合與加權指數
  /// 一致，故以它為代表判斷回補起點與既有覆蓋，無需逐指數查詢。
  ///
  /// **僅 TWSE**：TPEx 櫃買指數 OpenAPI（[TpexClient.getTpexIndex]）不支援
  /// date 參數、只回傳近月資料，無法逐日回補歷史（見 class doc 與
  /// `.superpowers/sdd/index-backfill-report.md` 的端點調查記錄）。櫃買指數
  /// 的位階深度僅能靠每日同步逐步自然累積。
  ///
  /// Idempotent：與 [backfill] 共用 (date, name) UNIQUE upsert，重複執行
  /// 安全。呼叫端（[sync]）以 try/catch 完整包裹本方法，任何例外（含
  /// [RateLimitException] / [NetworkException]）皆 fail-soft、不影響當日
  /// 同步結果——這與 [backfill] 內部「NetworkException 仍 rethrow」的
  /// 既有慣例刻意不同：深度回補是「錦上添花」的背景步驟，其例外不應
  /// 讓 `_syncAuxiliaryData` 誤判為限流而連帶中止 TDCC/股利/內部人轉讓等
  /// 其餘同步器。
  ///
  /// 回傳本次寫入筆數。
  Future<int> backfillDeepHistory() async {
    final now = _clock.now();

    final existingHistory = await _db.getIndexHistoryBatch(
      [MarketIndexNames.taiex],
      days: ApiConfig.indexBackfillTargetCalendarDays + _queryBufferDays,
      now: now,
    );
    final existingRows = existingHistory[MarketIndexNames.taiex] ?? const [];

    if (existingRows.isEmpty) {
      AppLogger.debug('MarketIndexSyncer', '指數深度回補: 尚無既有資料，待每日同步或近期回補建立起點後再回補');
      return 0;
    }

    // getIndexHistoryBatch 已依日期升冪排序，first 即最早日期
    final earliestDay = DateContext.normalize(existingRows.first.date);
    final targetDay = DateContext.normalize(
      now.subtract(
        const Duration(days: ApiConfig.indexBackfillTargetCalendarDays),
      ),
    );

    if (!earliestDay.isAfter(targetDay)) {
      AppLogger.debug(
        'MarketIndexSyncer',
        '指數深度回補: 已達目標深度 '
            '(${ApiConfig.indexBackfillTargetCalendarDays} 天)，略過',
      );
      return 0;
    }

    final existingDates = <String>{
      for (final row in existingRows)
        '${row.date.year}-${row.date.month}-${row.date.day}',
    };

    // 從既有最早日期前一天開始往回走，跳過非交易日與已覆蓋日期（後者為
    // 防禦性檢查——正常情況下不會命中，因 earliestDay 本身即既有資料的
    // 最小值，但可防護未來若資料來源改變導致的不連續缺口）。
    // 上限 ApiConfig.indexBackfillMaxDaysPerRun 個交易日／次。
    final datesToFetch = <DateTime>[];
    var remainingTradingDays = 0;
    for (
      var day = earliestDay.subtract(const Duration(days: 1));
      !day.isBefore(targetDay);
      day = day.subtract(const Duration(days: 1))
    ) {
      if (!TaiwanCalendar.isTradingDay(day)) continue;
      final key = '${day.year}-${day.month}-${day.day}';
      if (existingDates.contains(key)) continue;

      if (datesToFetch.length < ApiConfig.indexBackfillMaxDaysPerRun) {
        datesToFetch.add(day);
      } else {
        remainingTradingDays++;
      }
    }

    if (datesToFetch.isEmpty) {
      AppLogger.debug('MarketIndexSyncer', '指數深度回補: 目標窗內已無缺漏交易日，略過');
      return 0;
    }

    final (inserted, apiCalls) = await _fetchAndUpsertDates(
      datesToFetch,
      '深度回補',
    );

    // apiCalls 可能因中途限流而少於 datesToFetch.length（見
    // _fetchAndUpsertDates 的 RateLimitException 處理）；未實際嘗試的
    // 排隊日期仍算「剩餘」，否則限流中止的那次會低估剩餘量、誤導下次
    // 進度預期（2026-07-16 活體驗證：60 天排隊、50 次呼叫後撞限流中止）。
    final notAttempted = datesToFetch.length - apiCalls;
    AppLogger.info(
      'MarketIndexSyncer',
      '指數回補 $apiCalls 天（剩餘 ~${remainingTradingDays + notAttempted}）',
    );

    return inserted;
  }

  /// 逐日回補共用執行邏輯：依序呼叫 TWSE 取得指定日期指數並 upsert，
  /// 呼叫間依 [_requestDelay] 節流。
  ///
  /// - [RateLimitException]：中止迴圈但不 rethrow（best-effort 提前結束，
  ///   見 [backfill] 內原有的不對稱設計說明）。
  /// - [NetworkException]：rethrow，交由呼叫端決定是否吸收（[backfill]
  ///   任其向上傳、[backfillDeepHistory] 由 [sync] 的 try/catch 吸收）。
  /// - 其餘例外：單日略過，不中斷整體回補。
  ///
  /// 回傳 (寫入筆數, 實際 API 呼叫數)。
  Future<(int inserted, int apiCalls)> _fetchAndUpsertDates(
    List<DateTime> dates,
    String logLabel,
  ) async {
    var totalInserted = 0;
    var apiCalls = 0;

    for (final date in dates) {
      try {
        if (apiCalls > 0) {
          await Future.delayed(_requestDelay);
        }

        final indices = await _twse.getMarketIndices(date: date);
        apiCalls++;

        if (indices.isEmpty) continue;

        final companions = _filterAndConvert(indices, date);
        if (companions.isEmpty) continue;

        await _db.upsertMarketIndices(companions);
        totalInserted += companions.length;
      } on RateLimitException {
        AppLogger.warning(
          'MarketIndexSyncer',
          '指數$logLabel API 限流，中止 (已完成 $apiCalls 次呼叫)',
        );
        break;
      } on NetworkException {
        rethrow;
      } catch (e) {
        // 單日失敗不中斷整個回補
        AppLogger.debug(
          'MarketIndexSyncer',
          '指數$logLabel ${DateContext.formatYmd(date)} 失敗: $e',
        );
      }
    }

    return (totalInserted, apiCalls);
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
  ///
  /// [expectedDate] 為本次請求對應的交易日，用於日期合理性防護：
  /// 解析出的日期若與 [expectedDate] 相差超過
  /// [ApiConfig.marketIndexDateDriftToleranceDays] 天，或年份早於
  /// [ApiConfig.minSaneAdYear] / 晚於明年，視為髒資料並跳過，避免再次寫入
  /// 像 `0000-12-18` / `2026-12-18` 這類污染走勢圖與均線的列。
  List<MarketIndexCompanion> _filterAndConvert(
    List<TwseMarketIndex> indices,
    DateTime expectedDate,
  ) {
    final targetNames = MarketIndexNames.dashboardIndices.toSet();
    final filtered = indices
        .where((idx) => targetNames.contains(idx.name))
        .where((idx) => _isPlausibleDate(idx.date, expectedDate))
        .toList();

    if (filtered.isEmpty) {
      AppLogger.debug('MarketIndexSyncer', '無匹配的重點指數');
      return [];
    }

    return filtered.map((idx) => idx.toDatabaseCompanion()).toList();
  }

  /// 寫入前日期合理性防護
  ///
  /// 拒絕年份越界（< [ApiConfig.minSaneAdYear] 或 > 明年）或與 [expectedDate]
  /// 偏移過大的日期，並記錄 warning。
  bool _isPlausibleDate(DateTime date, DateTime expectedDate) {
    final maxYear = _clock.now().year + 1;
    if (date.year < ApiConfig.minSaneAdYear || date.year > maxYear) {
      AppLogger.warning(
        'MarketIndexSyncer',
        '跳過年份越界的指數日期: ${DateContext.formatYmd(date)}'
            '（合理範圍 ${ApiConfig.minSaneAdYear}~$maxYear）',
      );
      return false;
    }

    final driftDays = date.difference(expectedDate).inDays.abs();
    if (driftDays > ApiConfig.marketIndexDateDriftToleranceDays) {
      AppLogger.warning(
        'MarketIndexSyncer',
        '跳過與請求日期偏移過大的指數日期: ${DateContext.formatYmd(date)}'
            '（請求 ${DateContext.formatYmd(expectedDate)}、偏移 $driftDays 天）',
      );
      return false;
    }

    return true;
  }
}
