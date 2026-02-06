import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 批次 Database 查詢的快取存取器
///
/// 為 [AppDatabase] 批次方法包裝 5 分鐘 TTL 快取，
/// 以減少更新週期中的重複查詢。
///
/// 使用範例:
/// ```dart
/// final accessor = CachedDatabaseAccessor(db: _db, cache: _cache);
/// final prices = await accessor.getLatestPricesBatch(symbols);
/// ```
class CachedDatabaseAccessor {
  CachedDatabaseAccessor({
    required AppDatabase db,
    required BatchQueryCacheManager cache,
  }) : _db = db,
       _cache = cache;

  final AppDatabase _db;
  final BatchQueryCacheManager _cache;

  /// 批次取得多檔股票的最新價格（含快取）
  Future<Map<String, DailyPriceEntry>> getLatestPricesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // 先檢查快取
    final cached = _cache.getLatestPrices<DailyPriceEntry>(symbols);
    if (cached != null) {
      return cached;
    }

    // 從 Database 擷取
    final result = await _db.getLatestPricesBatch(symbols);

    // 快取結果
    _cache.cacheLatestPrices(symbols, result);

    return result;
  }

  /// 批次取得多檔股票的價格歷史（含快取）
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    // 先檢查快取
    final cached = _cache.getPriceHistory<DailyPriceEntry>(
      symbols,
      startDate,
      endDate,
    );
    if (cached != null) {
      return cached;
    }

    // 從 Database 擷取
    final result = await _db.getPriceHistoryBatch(
      symbols,
      startDate: startDate,
      endDate: endDate,
    );

    // 快取結果
    _cache.cachePriceHistory(symbols, startDate, endDate, result);

    return result;
  }

  /// 批次取得多檔股票的分析結果（含快取）
  Future<Map<String, DailyAnalysisEntry>> getAnalysesBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    // 先檢查快取
    final cached = _cache.getAnalyses<DailyAnalysisEntry>(symbols, date);
    if (cached != null) {
      return cached;
    }

    // 從 Database 擷取
    final result = await _db.getAnalysesBatch(symbols, date);

    // 快取結果
    _cache.cacheAnalyses(symbols, date, result);

    return result;
  }

  /// 批次取得多檔股票的推薦理由（含快取）
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    // 先檢查快取
    final cached = _cache.getReasons<DailyReasonEntry>(symbols, date);
    if (cached != null) {
      return cached;
    }

    // 從 Database 擷取
    final result = await _db.getReasonsBatch(symbols, date);

    // 快取結果
    _cache.cacheReasons(symbols, date, result);

    return result;
  }

  /// 批次取得股票主檔（不快取，因股票資料甚少變動）
  Future<Map<String, StockMasterEntry>> getStocksBatch(List<String> symbols) {
    return _db.getStocksBatch(symbols);
  }

  /// 清除所有快取資料
  ///
  /// 在資料異動後呼叫（例如更新完成後）
  void invalidateCache() {
    _cache.clearAll();
  }

  /// 僅清除價格相關快取
  void invalidatePrices() {
    _cache.clearPrices();
  }

  /// 僅清除分析結果快取
  void invalidateAnalyses() {
    _cache.clearAnalyses();
  }

  /// 僅清除推薦理由快取
  void invalidateReasons() {
    _cache.clearReasons();
  }

  // ==================================================
  // 型別安全批次載入（Dart 3 Records）
  // ==================================================

  /// 以單次型別安全呼叫載入股票清單畫面所需的所有資料
  ///
  /// 回傳具有具名欄位的 Record 以確保編譯期型別安全，
  /// 無需手動轉型如 `results[0] as Map<...>`。
  ///
  /// 使用範例:
  /// ```dart
  /// final data = await _cachedDb.loadStockListData(
  ///   symbols: allSymbols,
  ///   analysisDate: dateCtx.today,
  ///   historyStart: dateCtx.historyStart,
  /// );
  /// // 型別安全存取，無需轉型！
  /// final stockName = data.stocks[symbol]?.name;
  /// final latestPrice = data.latestPrices[symbol]?.close;
  /// ```
  Future<StockListBatchData> loadStockListData({
    required List<String> symbols,
    required DateTime analysisDate,
    required DateTime historyStart,
    DateTime? historyEnd,
  }) async {
    if (symbols.isEmpty) {
      return (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        analyses: <String, DailyAnalysisEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      );
    }

    final effectiveHistoryEnd = historyEnd ?? analysisDate;

    // 並行擷取所有資料（含快取）
    final results = await Future.wait([
      getStocksBatch(symbols),
      getLatestPricesBatch(symbols),
      getAnalysesBatch(symbols, analysisDate),
      getReasonsBatch(symbols, analysisDate),
      getPriceHistoryBatch(
        symbols,
        startDate: historyStart,
        endDate: effectiveHistoryEnd,
      ),
    ]);

    // 回傳型別化 Record，呼叫端無需轉型！
    return (
      stocks: results[0] as Map<String, StockMasterEntry>,
      latestPrices: results[1] as Map<String, DailyPriceEntry>,
      analyses: results[2] as Map<String, DailyAnalysisEntry>,
      reasons: results[3] as Map<String, List<DailyReasonEntry>>,
      priceHistories: results[4] as Map<String, List<DailyPriceEntry>>,
    );
  }

  /// 載入掃描畫面所需資料（分析結果另行擷取，不含在批次載入中）
  ///
  /// 掃描畫面從 getAnalysisForDate() 取得分析結果，故此處排除。
  Future<ScanBatchData> loadScanData({
    required List<String> symbols,
    required DateTime analysisDate,
    required DateTime historyStart,
    DateTime? historyEnd,
  }) async {
    if (symbols.isEmpty) {
      return (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      );
    }

    final effectiveHistoryEnd = historyEnd ?? analysisDate;

    final results = await Future.wait([
      getStocksBatch(symbols),
      getLatestPricesBatch(symbols),
      getReasonsBatch(symbols, analysisDate),
      getPriceHistoryBatch(
        symbols,
        startDate: historyStart,
        endDate: effectiveHistoryEnd,
      ),
    ]);

    return (
      stocks: results[0] as Map<String, StockMasterEntry>,
      latestPrices: results[1] as Map<String, DailyPriceEntry>,
      reasons: results[2] as Map<String, List<DailyReasonEntry>>,
      priceHistories: results[3] as Map<String, List<DailyPriceEntry>>,
    );
  }
}

/// 股票清單畫面（今日推薦、自選股）的型別安全批次資料
///
/// 使用 Dart 3 Record 語法確保編譯期型別安全
typedef StockListBatchData = ({
  Map<String, StockMasterEntry> stocks,
  Map<String, DailyPriceEntry> latestPrices,
  Map<String, DailyAnalysisEntry> analyses,
  Map<String, List<DailyReasonEntry>> reasons,
  Map<String, List<DailyPriceEntry>> priceHistories,
});

/// 掃描畫面的型別安全批次資料
typedef ScanBatchData = ({
  Map<String, StockMasterEntry> stocks,
  Map<String, DailyPriceEntry> latestPrices,
  Map<String, List<DailyReasonEntry>> reasons,
  Map<String, List<DailyPriceEntry>> priceHistories,
});
