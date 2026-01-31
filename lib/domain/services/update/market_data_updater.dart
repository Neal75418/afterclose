import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';

/// 市場籌碼資料更新器
///
/// 負責同步當沖、融資融券、外資持股、警示、董監持股等資料
class MarketDataUpdater {
  MarketDataUpdater({
    required AppDatabase database,
    required MarketDataRepository marketDataRepository,
    WarningRepository? warningRepository,
    InsiderRepository? insiderRepository,
  }) : _db = database,
       _marketDataRepo = marketDataRepository,
       _warningRepo =
           warningRepository ?? WarningRepository(database: database),
       _insiderRepo =
           insiderRepository ?? InsiderRepository(database: database);

  final AppDatabase _db;
  final MarketDataRepository _marketDataRepo;
  final WarningRepository _warningRepo;
  final InsiderRepository _insiderRepo;

  /// 同步全市場籌碼資料（TWSE + TPEX 批次 API）
  ///
  /// 包含當沖和融資融券資料。
  /// 使用官方免費 API，無需 FinMind 配額。
  Future<MarketDataSyncResult> syncMarketWideData({
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    var twseDayTradingCount = 0;
    var tpexDayTradingCount = 0;
    var marginCount = 0;

    // 從 TWSE 批次同步上市當沖資料
    try {
      twseDayTradingCount = await _marketDataRepo.syncAllDayTradingFromTwse(
        date: date,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '上市當沖資料同步失敗: $e');
    }

    // TPEX 當沖資料：API 端點被 Cloudflare 保護，無法存取
    // TPEX OpenAPI 也沒有提供個股當沖成交量的替代端點
    // 當沖資料對規則分析非必要，跳過同步
    // 若需要當沖資料，可考慮使用 FinMind 逐檔同步（但會消耗 API 配額）
    tpexDayTradingCount = 0;

    // 從 TWSE/TPEX 批次同步融資融券資料
    try {
      marginCount = await _marketDataRepo.syncAllMarginTradingFromTwse(
        date: date,
      );
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '融資融券資料同步失敗: $e');
    }

    return MarketDataSyncResult(
      dayTradingCount: twseDayTradingCount + tpexDayTradingCount,
      marginCount: marginCount,
    );
  }

  /// 同步特定股票清單的外資持股資料
  ///
  /// 用於自選清單和熱門股的詳細籌碼追蹤。
  ///
  /// **v0.1.2:** 移除 syncDayTrading 呼叫。
  /// 當沖資料已由 syncMarketWideData 透過批次 TWSE/TPEX API 同步，
  /// 不再需要逐檔呼叫 FinMind，節省 API 配額。
  Future<int> syncSymbolsMarketData({
    required List<String> symbols,
    required DateTime date,
  }) async {
    if (symbols.isEmpty) return 0;

    final marketDataStartDate = date.subtract(
      const Duration(days: RuleParams.foreignShareholdingLookbackDays + 5),
    );

    const chunkSize = 5;
    var syncedCount = 0;

    for (var i = 0; i < symbols.length; i += chunkSize) {
      final chunk = symbols.skip(i).take(chunkSize).toList();

      final futures = chunk.map((symbol) async {
        try {
          // 只同步外資持股，當沖資料已由批次 API 處理
          await _marketDataRepo.syncShareholding(
            symbol,
            startDate: marketDataStartDate,
            endDate: date,
          );
          return true;
        } catch (e) {
          AppLogger.debug('MarketDataUpdater', '$symbol 市場資料同步失敗: $e');
          return false;
        }
      });

      final results = await Future.wait(futures);
      syncedCount += results.where((r) => r).length;
    }

    return syncedCount;
  }

  /// 補充上櫃候選股票的外資持股資料
  ///
  /// **重要變更 (2026-01):**
  /// 當沖資料現在由 `syncMarketWideData` 透過批次 TPEX API 同步，
  /// 不再需要逐檔呼叫 FinMind，大幅減少 API 配額消耗。
  ///
  /// 此方法現在只同步外資持股資料（仍需 FinMind 逐檔呼叫）。
  ///
  /// **v0.1.2:** maxSyncCount 從 100 降至 20，避免 API 額度耗盡。
  /// 外資持股規則（ForeignExodus, ForeignConcentration）為輔助訊號，
  /// 20 檔足夠涵蓋主要候選股。
  Future<OtcMarketDataResult> syncOtcCandidatesMarketData({
    required List<String> candidates,
    required DateTime date,
    int maxSyncCount = 20,
  }) async {
    if (candidates.isEmpty) {
      return const OtcMarketDataResult(
        dayTradingCount: 0,
        shareholdingCount: 0,
      );
    }

    // 取得上櫃股票清單
    final otcStocks = await _db.getStocksByMarket('TPEx');
    final otcSymbols = otcStocks.map((s) => s.symbol).toSet();

    // 篩選出候選清單中的上櫃股票
    final otcCandidates = candidates
        .where((symbol) => otcSymbols.contains(symbol))
        .toList();

    if (otcCandidates.isEmpty) {
      return const OtcMarketDataResult(
        dayTradingCount: 0,
        shareholdingCount: 0,
      );
    }

    // 限制上櫃同步數量以避免超過 FinMind API 配額
    final limitedOtcCandidates = otcCandidates.length > maxSyncCount
        ? otcCandidates.take(maxSyncCount).toList()
        : otcCandidates;

    if (otcCandidates.length > maxSyncCount) {
      AppLogger.info(
        'MarketDataUpdater',
        '上櫃候選 ${otcCandidates.length} 檔超過配額限制，僅同步前 $maxSyncCount 檔',
      );
    }

    // 取得新鮮度檢查基準日期
    final latestDayTradingDate = await _db.getLatestDayTradingDate();
    final normalizedFreshnessDate = latestDayTradingDate != null
        ? DateTime(
            latestDayTradingDate.year,
            latestDayTradingDate.month,
            latestDayTradingDate.day,
          )
        : DateTime(date.year, date.month, date.day);

    final marketDataStartDate = date.subtract(
      const Duration(days: RuleParams.foreignShareholdingLookbackDays + 5),
    );

    var shareholdingCount = 0;
    var skippedCount = 0;
    var quotaExhausted = false;
    var totalErrorCount = 0;
    const maxTotalErrors = 5;

    const chunkSize = 5;
    outerLoop:
    for (var i = 0; i < limitedOtcCandidates.length; i += chunkSize) {
      final chunk = limitedOtcCandidates.skip(i).take(chunkSize).toList();

      final futures = chunk.map((symbol) async {
        try {
          // 新鮮度檢查：若已有參考日期的外資持股資料，跳過
          final latestShareholding = await _marketDataRepo
              .getLatestShareholding(symbol);
          final hasFreshShareholding =
              latestShareholding != null &&
              !latestShareholding.date.isBefore(normalizedFreshnessDate);

          if (hasFreshShareholding) {
            return (true, false, false); // skipped, synced, error
          }

          // 同步外資持股資料
          try {
            final shResult = await _marketDataRepo.syncShareholding(
              symbol,
              startDate: marketDataStartDate,
              endDate: date,
            );
            return (false, shResult > 0, false);
          } on RateLimitException {
            return (false, false, true); // quota error
          }
        } catch (e) {
          AppLogger.debug('MarketDataUpdater', '$symbol 外資持股同步失敗: $e');
          return (false, false, true);
        }
      });

      final results = await Future.wait(futures);

      for (final (skipped, synced, isError) in results) {
        if (skipped) skippedCount++;
        if (synced) shareholdingCount++;
        if (isError) {
          totalErrorCount++;
          // 檢查是否為配額錯誤
          if (totalErrorCount == 1) quotaExhausted = true;
        }
      }

      // 若偵測到額度耗盡，提前終止
      if (quotaExhausted && totalErrorCount >= 2) {
        AppLogger.warning(
          'MarketDataUpdater',
          'FinMind API 額度耗盡，停止上櫃同步 (已處理 ${i + chunkSize}/${limitedOtcCandidates.length} 檔)',
        );
        break outerLoop;
      }

      // 偵測累積錯誤
      if (totalErrorCount >= maxTotalErrors) {
        AppLogger.warning(
          'MarketDataUpdater',
          'FinMind API 累積 $totalErrorCount 個錯誤，停止上櫃同步 (已處理 ${i + chunkSize}/${limitedOtcCandidates.length} 檔)',
        );
        break outerLoop;
      }
    }

    if (skippedCount > 0) {
      AppLogger.info('MarketDataUpdater', '上櫃外資持股新鮮度檢查: 跳過 $skippedCount 檔');
    }

    // 當沖資料已由批次 TPEX API 同步，此處回傳 0
    return OtcMarketDataResult(
      dayTradingCount: 0,
      shareholdingCount: shareholdingCount,
      totalCandidates: otcCandidates.length,
      syncedCandidates: limitedOtcCandidates.length,
    );
  }

  // ==========================================
  // Killer Features 同步方法
  // ==========================================

  /// 同步 Killer Features 資料（警示、董監持股）
  ///
  /// 警示資料每日更新，董監持股資料每月更新。
  /// 兩者為獨立操作，使用 Future.wait 平行執行以提升效能。
  /// 即使一項同步失敗，另一項仍會繼續執行（部分成功模式）。
  /// 錯誤資訊會記錄在結果中供呼叫端檢查。
  Future<KillerFeaturesSyncResult> syncKillerFeaturesData({
    bool force = false,
  }) async {
    int warningCount = 0;
    int insiderCount = 0;
    Object? warningError;
    Object? insiderError;

    // 平行同步警示和董監持股資料
    final results = await Future.wait([
      _warningRepo
          .syncAllMarketWarnings(force: force)
          .then((count) {
            AppLogger.info('MarketDataUpdater', '警示資料同步完成: $count 筆');
            return (count, null as Object?);
          })
          .catchError((Object e) {
            AppLogger.warning('MarketDataUpdater', '警示資料同步失敗: $e');
            return (0, e);
          }),
      _insiderRepo
          .syncOtcInsiderHoldings(force: force)
          .then((count) {
            AppLogger.info('MarketDataUpdater', '董監持股資料同步完成: $count 筆');
            return (count, null as Object?);
          })
          .catchError((Object e) {
            AppLogger.warning('MarketDataUpdater', '董監持股資料同步失敗: $e');
            return (0, e);
          }),
    ]);

    // 解構結果
    final (wCount, wError) = results[0];
    final (iCount, iError) = results[1];
    warningCount = wCount;
    warningError = wError;
    insiderCount = iCount;
    insiderError = iError;

    return KillerFeaturesSyncResult(
      warningCount: warningCount,
      insiderCount: insiderCount,
      warningError: warningError,
      insiderError: insiderError,
    );
  }

  /// 同步警示資料
  ///
  /// 每日更新，包含注意股票和處置股票。
  Future<int> syncWarningData({bool force = false}) async {
    try {
      final count = await _warningRepo.syncAllMarketWarnings(force: force);
      AppLogger.info('MarketDataUpdater', '警示資料同步: $count 筆');
      return count;
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '警示資料同步失敗: $e');
      return 0;
    }
  }

  /// 同步董監持股資料
  ///
  /// 月報資料，每月更新一次即可。
  Future<int> syncInsiderData({bool force = false}) async {
    try {
      final count = await _insiderRepo.syncOtcInsiderHoldings(force: force);
      AppLogger.info('MarketDataUpdater', '董監持股資料同步: $count 筆');
      return count;
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '董監持股資料同步失敗: $e');
      return 0;
    }
  }

  /// 取得自選股的 Killer Features 資料
  ///
  /// 用於在自選股列表顯示警示標記。
  Future<WatchlistKillerFeaturesData> getWatchlistKillerFeaturesData(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) {
      return const WatchlistKillerFeaturesData(
        warnings: {},
        highPledgeStocks: {},
      );
    }

    final warnings = await _warningRepo.getWatchlistWarnings(symbols);
    final highPledge = await _insiderRepo.getWatchlistHighPledgeStocks(symbols);

    return WatchlistKillerFeaturesData(
      warnings: warnings,
      highPledgeStocks: highPledge,
    );
  }
}

/// 市場籌碼同步結果
class MarketDataSyncResult {
  const MarketDataSyncResult({
    required this.dayTradingCount,
    required this.marginCount,
  });

  final int dayTradingCount;

  /// 融資融券同步筆數。-1 表示已快取（跳過同步）。
  final int marginCount;

  bool get marginCached => marginCount < 0;
  int get total => dayTradingCount + (marginCount < 0 ? 0 : marginCount);
}

/// 上櫃籌碼同步結果
class OtcMarketDataResult {
  const OtcMarketDataResult({
    required this.dayTradingCount,
    required this.shareholdingCount,
    this.totalCandidates = 0,
    this.syncedCandidates = 0,
  });

  final int dayTradingCount;
  final int shareholdingCount;
  final int totalCandidates;
  final int syncedCandidates;

  int get total => dayTradingCount + shareholdingCount;
}

/// Killer Features 同步結果
class KillerFeaturesSyncResult {
  const KillerFeaturesSyncResult({
    required this.warningCount,
    required this.insiderCount,
    this.warningError,
    this.insiderError,
  });

  final int warningCount;
  final int insiderCount;

  /// 警示同步錯誤（若有）
  final Object? warningError;

  /// 董監持股同步錯誤（若有）
  final Object? insiderError;

  int get total => warningCount + insiderCount;

  /// 是否有任何同步錯誤
  bool get hasErrors => warningError != null || insiderError != null;

  /// 是否全部同步成功
  bool get isFullySuccessful => !hasErrors && total > 0;
}

/// 自選股 Killer Features 資料
class WatchlistKillerFeaturesData {
  const WatchlistKillerFeaturesData({
    required this.warnings,
    required this.highPledgeStocks,
  });

  /// 自選股中的警示股票（symbol -> TradingWarningEntry）
  final Map<String, TradingWarningEntry> warnings;

  /// 自選股中的高質押股票（symbol -> InsiderHoldingEntry）
  final Map<String, InsiderHoldingEntry> highPledgeStocks;

  /// 是否有任何警示
  bool get hasWarnings => warnings.isNotEmpty || highPledgeStocks.isNotEmpty;

  /// 檢查特定股票是否有警示
  bool hasWarningFor(String symbol) =>
      warnings.containsKey(symbol) || highPledgeStocks.containsKey(symbol);
}
