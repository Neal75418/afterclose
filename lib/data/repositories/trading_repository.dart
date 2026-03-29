import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/safe_execution.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/domain/repositories/trading_repository.dart';

/// 交易資料 Repository
///
/// 處理：當沖、融資融券
class TradingRepository implements ITradingRepository {
  TradingRepository({
    required AppDatabase database,
    TwseClient? twseClient,
    TpexClient? tpexClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _twseClient = twseClient ?? TwseClient(),
       _tpexClient = tpexClient ?? TpexClient(),
       _clock = clock;

  final AppDatabase _db;
  final TwseClient _twseClient;
  final TpexClient _tpexClient;
  final AppClock _clock;

  /// 判定批次資料為「最新」的最低筆數門檻
  /// 若該日期已有超過此數量的資料，則跳過 API 呼叫
  static const _batchFreshnessThreshold = DataFreshness.twseBatchThreshold;

  // ==================================================
  // 當沖
  // ==================================================

  /// 取得當沖歷史資料
  @override
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = _clock.now().subtract(
      Duration(days: days + DataFreshness.dayTradingBufferDays),
    );
    return _db.getDayTradingHistory(symbol, startDate: startDate);
  }

  /// 從 TWSE 同步全市場當沖資料（免費 API）
  ///
  /// 使用 TWSE 官方 API，無需 Token。
  /// 比透過 FinMind 逐檔同步快很多。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  @override
  Future<int> syncAllDayTradingFromTwse({
    DateTime? date,
    bool force = false,
  }) async {
    try {
      final targetDate = DateContext.normalize(date ?? _clock.now());

      // 新鮮度檢查：若已有目標日期資料則跳過
      if (!force) {
        final existingCount = await _db.getDayTradingCountForDate(targetDate);
        if (existingCount > _batchFreshnessThreshold) {
          return 0;
        }
      }

      // 1. 取得當沖資料（比例為 0，因為 API 不提供）
      final data = await _twseClient.getAllDayTradingData(date: targetDate);

      AppLogger.info(
        'TradingRepo',
        'TWSE 當沖原始筆數: ${data.length}，日期: $targetDate',
      );

      if (data.isEmpty) return 0;

      // 2. 取得同日期的價格資料以計算比例
      // 註：呼叫此方法前必須先同步價格資料
      var prices = await _db.getPricesForDate(targetDate);

      // 備援 1：若 UTC 日期無結果，嘗試本地日期
      // Database 可能以本地時間或正規化 UTC 儲存日期
      if (prices.isEmpty) {
        prices = await _db.getPricesForDate(targetDate.toLocal());
      }

      // 備援 2：嘗試範圍查詢（涵蓋 UTC 和本地時間）
      if (prices.isEmpty) {
        final year = targetDate.year;
        final month = targetDate.month;
        final day = targetDate.day;

        final start = DateTime(year, month, day); // 本地午夜
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));

        final result = await _db.getAllPricesInRange(
          startDate: start,
          endDate: end,
        );
        prices = result.values.expand((list) => list).toList();
      }

      AppLogger.info('TradingRepo', '用於計算的價格資料: ${prices.length} 筆');
      final volumeMap = <String, double>{};
      for (final p in prices) {
        if (p.volume != null) {
          volumeMap[p.symbol] = p.volume!.toDouble();
        }
      }

      final entries = <DayTradingCompanion>[];

      for (final item in data) {
        // 過濾無效股票代碼（權證、TDR 等）
        if (!StockPatterns.isValidCode(item.code)) continue;

        double ratio = 0;
        final totalVolumeFromPrice = volumeMap[item.code] ?? 0;

        // 優先使用價格表的總成交量，否則使用當沖成交量
        // 但計算比例需要總市場成交量
        if (totalVolumeFromPrice > 0) {
          ratio = (item.totalVolume / totalVolumeFromPrice) * 100;
        } else {
          // 若無價格資料則備援（需確認同步順序）
          ratio = 0;
        }

        // 驗證比例
        if (ratio > DataFreshness.dayTradingMaxValidRatio) {
          ratio = DataFreshness.dayTradingMaxValidRatio;
        }
        if (ratio < 0) ratio = 0;

        entries.add(
          DayTradingCompanion.insert(
            symbol: item.code,
            date: targetDate, // 使用標準化日期，確保與查詢一致
            buyVolume: Value(item.buyVolume),
            sellVolume: Value(item.sellVolume),
            dayTradingRatio: Value(ratio),
            tradeVolume: Value(item.totalVolume),
          ),
        );
      }

      // 刪除舊記錄（可能存在因 UTC/本地時間不一致導致的重複）
      // 刪除範圍：目標日期的前後各 12 小時（涵蓋 UTC 偏移）
      final deleteStart = targetDate.subtract(
        const Duration(hours: DataFreshness.dayTradingDeleteWindowBeforeHours),
      );
      final deleteEnd = targetDate.add(
        const Duration(hours: DataFreshness.dayTradingDeleteWindowAfterHours),
      );
      await _db.transaction(() async {
        await _db.deleteDayTradingForDateRange(deleteStart, deleteEnd);
        await _db.insertDayTradingData(entries);
      });

      // 統計當沖比例分佈
      final highRatioEntries = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null &&
            ratio >= DataFreshness.dayTradingHighDisplayRatio;
      }).toList();
      final extremeRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null &&
            ratio >= DataFreshness.dayTradingExtremeDisplayRatio;
      }).length;
      final zeroRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio == null || ratio == 0;
      }).length;

      AppLogger.info(
        'TradingRepo',
        '當沖資料寫入 ${entries.length} 筆 (上市, TWSE): '
            '高比例(>=60%)=${highRatioEntries.length}，極高(>=70%)=$extremeRatioCount，零比例=$zeroRatioCount',
      );

      if (highRatioEntries.isNotEmpty) {
        final highSymbols = highRatioEntries
            .map(
              (e) =>
                  '${e.symbol.value}(${e.dayTradingRatio.value?.toStringAsFixed(1)}%)',
            )
            .join(', ');
        AppLogger.info('TradingRepo', '高當沖股票: $highSymbols');
      }
      return entries.length;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading from TWSE', e);
    }
  }

  /// 從 TPEX 同步全市場上櫃當沖資料（免費 API）
  ///
  /// 使用 TPEX 官方 API，無需 Token。
  /// 比透過 FinMind 逐檔同步快很多，且不消耗 FinMind 配額。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  @override
  Future<int> syncAllDayTradingFromTpex({
    DateTime? date,
    bool force = false,
  }) async {
    try {
      final targetDate = DateContext.normalize(date ?? _clock.now());

      // 新鮮度檢查：若已有目標日期的上櫃當沖資料則跳過
      // 使用較低閾值（50），因為上櫃股票數量較少
      if (!force) {
        final existingCount = await _db.getDayTradingCountForDateAndMarket(
          targetDate,
          MarketCode.tpex,
        );
        if (existingCount > DataFreshness.tpexBatchThreshold) {
          return 0;
        }
      }

      // 取得上櫃當沖資料
      final data = await _tpexClient.getAllDayTradingData(date: targetDate);

      AppLogger.info(
        'TradingRepo',
        'TPEX 當沖原始筆數: ${data.length}，日期: $targetDate',
      );

      if (data.isEmpty) return 0;

      // 取得同日期的價格資料以計算比例
      var prices = await _db.getPricesForDate(targetDate);

      // 備援：嘗試範圍查詢
      if (prices.isEmpty) {
        final start = targetDate;
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));

        final result = await _db.getAllPricesInRange(
          startDate: start,
          endDate: end,
        );
        prices = result.values.expand((list) => list).toList();
      }

      AppLogger.info('TradingRepo', 'TPEX 用於計算的價格資料: ${prices.length} 筆');
      final volumeMap = <String, double>{};
      for (final p in prices) {
        if (p.volume != null) {
          volumeMap[p.symbol] = p.volume!.toDouble();
        }
      }

      final entries = <DayTradingCompanion>[];

      for (final item in data) {
        double ratio = 0;
        final totalVolumeFromPrice = volumeMap[item.code] ?? 0;

        // 計算當沖比例
        if (totalVolumeFromPrice > 0) {
          ratio = (item.totalVolume / totalVolumeFromPrice) * 100;
        }

        // 驗證比例
        if (ratio > DataFreshness.dayTradingMaxValidRatio) {
          ratio = DataFreshness.dayTradingMaxValidRatio;
        }
        if (ratio < 0) ratio = 0;

        entries.add(
          DayTradingCompanion.insert(
            symbol: item.code,
            date: targetDate,
            buyVolume: Value(item.buyVolume),
            sellVolume: Value(item.sellVolume),
            dayTradingRatio: Value(ratio),
            tradeVolume: Value(item.totalVolume),
          ),
        );
      }

      await _db.transaction(() async {
        await _db.insertDayTradingData(entries);
      });

      // 統計當沖比例分佈
      final highRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null &&
            ratio >= DataFreshness.dayTradingHighDisplayRatio;
      }).length;

      AppLogger.info(
        'TradingRepo',
        '當沖資料寫入 ${entries.length} 筆 (上櫃, TPEX): 高比例(>=60%)=$highRatioCount',
      );

      return entries.length;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading from TPEX', e);
    }
  }

  // ==================================================
  // 融資融券 - TWSE API
  // ==================================================

  /// 取得融資融券歷史資料
  @override
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = _clock.now().subtract(
      Duration(days: days + DataFreshness.marginTradingBufferDays),
    );
    return _db.getMarginTradingHistory(symbol, startDate: startDate);
  }

  /// 從 TWSE/TPEX 同步全市場融資融券資料（免費 API）
  ///
  /// 使用 TWSE + TPEX 官方 API，無需 Token。
  /// 並行取得上市與上櫃融資融券資料。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  @override
  Future<int?> syncAllMarginTradingFromTwse({
    DateTime? date,
    bool force = false,
  }) async {
    try {
      final targetDate = date ?? _clock.now();

      // 新鮮度檢查：若已有目標日期資料則跳過
      // 提高閾值至 1500 以涵蓋上市+上櫃股票
      if (!force) {
        final existingCount = await _db.getMarginTradingCountForDate(
          targetDate,
        );
        if (existingCount > DataFreshness.fullMarketThreshold) {
          AppLogger.debug('TradingRepo', '融資融券資料已快取 ($existingCount 筆)，跳過同步');
          return null;
        }
      }

      // 並行取得上市與上櫃融資融券資料（錯誤隔離，允許部分成功）
      // safeAwait 立即包裹原始 Future，避免 unhandled async error
      final twseFuture = safeAwait(
        _twseClient.getAllMarginTradingData(),
        <TwseMarginTrading>[],
        tag: 'TradingRepo',
        description: '上市融資融券取得失敗，繼續處理上櫃',
      );
      // TPEx 融資融券 API 有 T+1 延遲：傳入今日日期會回傳空資料。
      // 省略 d 參數時 API 自動回傳最新可用資料（與 TWSE 行為一致）。
      final tpexFuture = safeAwait(
        _tpexClient.getAllMarginTradingData(),
        <TpexMarginTrading>[],
        tag: 'TradingRepo',
        description: '上櫃融資融券取得失敗，繼續處理上市',
      );

      final twseData = await twseFuture;
      final tpexData = await tpexFuture;

      if (twseData.isEmpty && tpexData.isEmpty) return 0;

      // 取得已知股票代碼集合，過濾非 stocks 表中的代碼以避免 FK 違規
      final activeStocks = await _db.getAllActiveStocks();
      final validSymbols = activeStocks.map((s) => s.symbol).toSet();

      // 建立融資融券 entries（TWSE 和 TPEx 單位皆為張，無需轉換）
      MarginTradingCompanion buildEntry(
        String code,
        DateTime date,
        double marginBuy,
        double marginSell,
        double marginBalance,
        double shortBuy,
        double shortSell,
        double shortBalance,
      ) {
        return MarginTradingCompanion.insert(
          symbol: code,
          date: date,
          marginBuy: Value(marginBuy),
          marginSell: Value(marginSell),
          marginBalance: Value(marginBalance),
          shortBuy: Value(shortBuy),
          shortSell: Value(shortSell),
          shortBalance: Value(shortBalance),
        );
      }

      final twseEntries = twseData
          .where(
            (item) =>
                StockPatterns.isValidCode(item.code) &&
                validSymbols.contains(item.code),
          )
          .map(
            (item) => buildEntry(
              item.code,
              item.date,
              item.marginBuy,
              item.marginSell,
              item.marginBalance,
              item.shortBuy,
              item.shortSell,
              item.shortBalance,
            ),
          )
          .toList();

      final tpexEntries = tpexData
          .where(
            (item) =>
                StockPatterns.isValidCode(item.code) &&
                validSymbols.contains(item.code),
          )
          .map(
            (item) => buildEntry(
              item.code,
              item.date,
              item.marginBuy,
              item.marginSell,
              item.marginBalance,
              item.shortBuy,
              item.shortSell,
              item.shortBalance,
            ),
          )
          .toList();

      // 合併並寫入（transaction 保護避免部分寫入）
      final allEntries = [...twseEntries, ...tpexEntries];
      await _db.transaction(() async {
        await _db.insertMarginTradingData(allEntries);
      });

      AppLogger.info(
        'TradingRepo',
        '融資融券同步: ${allEntries.length} 筆 (上市 ${twseEntries.length}, 上櫃 ${tpexEntries.length})',
      );

      return allEntries.length;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync margin trading from TWSE/TPEX',
        e,
      );
    }
  }
}
