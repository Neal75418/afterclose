import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/safe_execution.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/core/constants/data_freshness.dart';

/// 交易資料 Repository
///
/// 處理：當沖、融資融券
class TradingRepository {
  TradingRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
    TpexClient? tpexClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient ?? TwseClient(),
       _tpexClient = tpexClient ?? TpexClient();

  final AppDatabase _db;
  final FinMindClient _client;
  final TwseClient _twseClient;
  final TpexClient _tpexClient;

  /// 判定批次資料為「最新」的最低筆數門檻
  /// 若該日期已有超過此數量的資料，則跳過 API 呼叫
  static const _batchFreshnessThreshold = DataFreshness.twseBatchThreshold;

  // ============================================
  // 當沖
  // ============================================

  /// 取得當沖歷史資料
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(
      Duration(days: days + DataFreshness.dayTradingBufferDays),
    );
    return _db.getDayTradingHistory(symbol, startDate: startDate);
  }

  /// 取得最新當沖資料
  Future<DayTradingEntry?> getLatestDayTrading(String symbol) {
    return _db.getLatestDayTrading(symbol);
  }

  /// 從 FinMind 同步當沖資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若 [endDate]（或今日）的資料已存在則跳過。
  ///
  /// 註：建議使用 [syncAllDayTradingFromTwse] 進行批次同步（免費、無配額限制）。
  @Deprecated('Use syncAllDayTradingFromTwse instead')
  Future<int> syncDayTrading(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有目標日期資料則跳過
      final targetDate = endDate ?? DateTime.now();
      final latest = await getLatestDayTrading(symbol);
      if (latest != null && _isSameDay(latest.date, targetDate)) {
        return 0;
      }

      final data = await _client.getDayTrading(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return DayTradingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          buyVolume: Value(item.buyDayTradingVolume),
          sellVolume: Value(item.sellDayTradingVolume),
          dayTradingRatio: Value(item.dayTradingRatio),
          tradeVolume: Value(item.tradeVolume),
        );
      }).toList();

      await _db.insertDayTradingData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading for $symbol', e);
    }
  }

  /// 檢查是否為高當沖股（當沖比 > 30%）
  Future<bool> isHighDayTradingStock(String symbol) async {
    final latest = await getLatestDayTrading(symbol);
    if (latest == null) return false;
    return (latest.dayTradingRatio ?? 0) > DataFreshness.dayTradingHighRatio;
  }

  /// 取得平均當沖比例
  Future<double?> getAverageDayTradingRatio(
    String symbol, {
    int days = 5,
  }) async {
    final history = await getDayTradingHistory(symbol, days: days + 5);
    if (history.isEmpty) return null;

    final recent = history.reversed.take(days).toList();
    if (recent.isEmpty) return null;

    double sum = 0;
    int count = 0;
    for (final entry in recent) {
      if (entry.dayTradingRatio != null) {
        sum += entry.dayTradingRatio!;
        count++;
      }
    }

    return count > 0 ? sum / count : null;
  }

  /// 從 TWSE 同步全市場當沖資料（免費 API）
  ///
  /// 使用 TWSE 官方 API，無需 Token。
  /// 比透過 FinMind 逐檔同步快很多。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [forceRefresh] 為 true 可略過新鮮度檢查。
  Future<int> syncAllDayTradingFromTwse({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    try {
      // 統一使用本地時間午夜，確保與 DateContext.normalize 一致
      final rawDate = date ?? DateTime.now();
      final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

      // 新鮮度檢查：若已有目標日期資料則跳過
      if (!forceRefresh) {
        final existingCount = await _db.getDayTradingCountForDate(targetDate);
        if (existingCount > _batchFreshnessThreshold) {
          return 0;
        }
      }

      // 1. 取得當沖資料（比例為 0，因為 API 不提供）
      final data = await _twseClient.getAllDayTradingData(date: targetDate);

      AppLogger.info(
        'MarketData',
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

      AppLogger.info('MarketData', '用於計算的價格資料: ${prices.length} 筆');
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
      final deleteStart = targetDate.subtract(const Duration(hours: 12));
      final deleteEnd = targetDate.add(const Duration(hours: 36));
      await _db.deleteDayTradingForDateRange(deleteStart, deleteEnd);

      await _db.insertDayTradingData(entries);

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
        'MarketData',
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
        AppLogger.info('MarketData', '高當沖股票: $highSymbols');
      }
      return entries.length;
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
  /// 設定 [forceRefresh] 為 true 可略過新鮮度檢查。
  Future<int> syncAllDayTradingFromTpex({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    try {
      // 統一使用本地時間午夜，確保與 DateContext.normalize 一致
      final rawDate = date ?? DateTime.now();
      final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

      // 新鮮度檢查：若已有目標日期的上櫃當沖資料則跳過
      // 使用較低閾值（50），因為上櫃股票數量較少
      if (!forceRefresh) {
        final existingCount = await _db.getDayTradingCountForDateAndMarket(
          targetDate,
          'TPEx',
        );
        if (existingCount > DataFreshness.tpexBatchThreshold) {
          return 0;
        }
      }

      // 取得上櫃當沖資料
      final data = await _tpexClient.getAllDayTradingData(date: targetDate);

      AppLogger.info(
        'MarketData',
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

      AppLogger.info('MarketData', 'TPEX 用於計算的價格資料: ${prices.length} 筆');
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

      await _db.insertDayTradingData(entries);

      // 統計當沖比例分佈
      final highRatioCount = entries.where((e) {
        final ratio = e.dayTradingRatio.value;
        return ratio != null &&
            ratio >= DataFreshness.dayTradingHighDisplayRatio;
      }).length;

      AppLogger.info(
        'MarketData',
        '當沖資料寫入 ${entries.length} 筆 (上櫃, TPEX): 高比例(>=60%)=$highRatioCount',
      );

      return entries.length;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading from TPEX', e);
    }
  }

  // ============================================
  // 融資融券 - TWSE API
  // ============================================

  /// 取得融資融券歷史資料
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(
      Duration(days: days + DataFreshness.marginTradingBufferDays),
    );
    return _db.getMarginTradingHistory(symbol, startDate: startDate);
  }

  /// 取得最新融資融券資料
  Future<MarginTradingEntry?> getLatestMarginTrading(String symbol) {
    return _db.getLatestMarginTrading(symbol);
  }

  /// 從 TWSE/TPEX 同步全市場融資融券資料（免費 API）
  ///
  /// 使用 TWSE + TPEX 官方 API，無需 Token。
  /// 並行取得上市與上櫃融資融券資料。
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 設定 [forceRefresh] 為 true 可略過新鮮度檢查。
  Future<int> syncAllMarginTradingFromTwse({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();

      // 新鮮度檢查：若已有目標日期資料則跳過
      // 提高閾值至 1500 以涵蓋上市+上櫃股票
      if (!forceRefresh) {
        final existingCount = await _db.getMarginTradingCountForDate(
          targetDate,
        );
        if (existingCount > DataFreshness.fullMarketThreshold) {
          AppLogger.debug('MarketData', '融資融券資料已快取 ($existingCount 筆)，跳過同步');
          return -1;
        }
      }

      // 並行取得上市與上櫃融資融券資料（錯誤隔離，允許部分成功）
      final twseFuture = _twseClient.getAllMarginTradingData();
      final tpexFuture = _tpexClient.getAllMarginTradingData(date: targetDate);

      final twseData = await safeAwait(
        twseFuture,
        <TwseMarginTrading>[],
        tag: 'MarketData',
        description: '上市融資融券取得失敗，繼續處理上櫃',
      );
      final tpexData = await safeAwait(
        tpexFuture,
        <TpexMarginTrading>[],
        tag: 'MarketData',
        description: '上櫃融資融券取得失敗，繼續處理上市',
      );

      if (twseData.isEmpty && tpexData.isEmpty) return 0;

      // 建立上市融資融券 entries（過濾無效代碼）
      final twseEntries = twseData
          .where((item) => StockPatterns.isValidCode(item.code))
          .map((item) {
            return MarginTradingCompanion.insert(
              symbol: item.code,
              date: item.date,
              marginBuy: Value(item.marginBuy),
              marginSell: Value(item.marginSell),
              marginBalance: Value(item.marginBalance),
              shortBuy: Value(item.shortBuy),
              shortSell: Value(item.shortSell),
              shortBalance: Value(item.shortBalance),
            );
          })
          .toList();

      // 建立上櫃融資融券 entries（過濾無效代碼）
      final tpexEntries = tpexData
          .where((item) => StockPatterns.isValidCode(item.code))
          .map((item) {
            return MarginTradingCompanion.insert(
              symbol: item.code,
              date: item.date,
              marginBuy: Value(item.marginBuy),
              marginSell: Value(item.marginSell),
              marginBalance: Value(item.marginBalance),
              shortBuy: Value(item.shortBuy),
              shortSell: Value(item.shortSell),
              shortBalance: Value(item.shortBalance),
            );
          })
          .toList();

      // 合併並寫入
      final allEntries = [...twseEntries, ...tpexEntries];
      await _db.insertMarginTradingData(allEntries);

      AppLogger.info(
        'MarketData',
        '融資融券同步: ${allEntries.length} 筆 (上市 ${twseEntries.length}, 上櫃 ${tpexEntries.length})',
      );

      return allEntries.length;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync margin trading from TWSE/TPEX',
        e,
      );
    }
  }

  /// 計算券資比
  ///
  /// 較高的券資比（> 30%）表示潛在軋空機會
  Future<double?> getShortMarginRatio(String symbol) async {
    final latest = await getLatestMarginTrading(symbol);
    if (latest == null) return null;

    final marginBalance = latest.marginBalance ?? 0;
    final shortBalance = latest.shortBalance ?? 0;

    if (marginBalance <= 0) return null;
    return (shortBalance / marginBalance) * 100;
  }

  /// 檢查融資餘額是否增加中（散戶追多）
  Future<bool> isMarginIncreasing(String symbol, {int days = 5}) async {
    final history = await getMarginTradingHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.marginBalance ?? 0;
    final last = recent.first.marginBalance ?? 0;

    return last > first;
  }

  /// 檢查融券餘額是否增加中（空單增加）
  Future<bool> isShortIncreasing(String symbol, {int days = 5}) async {
    final history = await getMarginTradingHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.shortBalance ?? 0;
    final last = recent.first.shortBalance ?? 0;

    return last > first;
  }

  // ============================================
  // 內部輔助方法
  // ============================================

  /// 檢查兩個日期是否為同一天（忽略時間）
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
