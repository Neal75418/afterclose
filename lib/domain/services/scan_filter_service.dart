import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/models/scan_models.dart';

/// 掃描畫面的純業務邏輯服務
///
/// 負責篩選、排序、資料轉換等業務邏輯，
/// 不持有狀態，不依賴 Riverpod，可獨立測試。
class ScanFilterService {
  const ScanFilterService({AppClock clock = const SystemClock()})
    : _clock = clock;

  final AppClock _clock;

  // ==================================================
  // 日期回退邏輯
  // ==================================================

  /// 智慧回退邏輯：依序嘗試最近 3 天的資料，找到有資料的日期
  ///
  /// 處理以下情境：
  /// - 週末/假日：顯示最近交易日資料
  /// - 盤前：資料可能來自前一日
  /// - API 日期延遲：TWSE/TPEX 資料日期可能落後
  ///
  /// 回傳 (targetDate, analyses)，analyses 可能為空（若連備援都無資料）。
  Future<({DateTime targetDate, List<DailyAnalysisEntry> analyses})>
  findLatestAnalyses(AppDatabase db, {DateTime? now}) async {
    final effectiveNow = now ?? _clock.now();
    var targetDate = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    var analyses = <DailyAnalysisEntry>[];

    // 依序嘗試今天、昨天、前天的資料
    for (var daysAgo = 0; daysAgo <= 2; daysAgo++) {
      final date = effectiveNow.subtract(Duration(days: daysAgo));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      analyses = await db.getAnalysisForDate(normalizedDate);
      if (analyses.isNotEmpty) {
        targetDate = normalizedDate;
        return (targetDate: targetDate, analyses: analyses);
      }
    }

    // 若最近 3 天都無資料，嘗試前一交易日（處理連續假期）
    final prevTradingDay = TaiwanCalendar.getPreviousTradingDay(
      effectiveNow.subtract(const Duration(days: 3)),
    );
    // 正規化為午夜，與資料庫儲存格式一致（避免時間分量導致 .equals() 比對失敗）
    targetDate = DateTime(
      prevTradingDay.year,
      prevTradingDay.month,
      prevTradingDay.day,
    );
    AppLogger.info('ScanFilterService', '最近 3 天無資料，備援至前一交易日 $targetDate');
    analyses = await db.getAnalysisForDate(targetDate);

    return (targetDate: targetDate, analyses: analyses);
  }

  // ==================================================
  // 篩選邏輯
  // ==================================================

  /// 套用全域篩選：根據 [filter] 與 [industrySymbols] 過濾分析結果
  ///
  /// 純函數，不修改輸入資料。
  List<DailyAnalysisEntry> applyFilter({
    required List<DailyAnalysisEntry> allAnalyses,
    required ScanFilter filter,
    required Map<String, List<DailyReasonEntry>> allReasons,
    Set<String>? industrySymbols,
  }) {
    if (filter == ScanFilter.all && industrySymbols == null) {
      return List.from(allAnalyses);
    }

    return allAnalyses.where((analysis) {
      // 產業篩選
      if (industrySymbols != null &&
          !industrySymbols.contains(analysis.symbol)) {
        return false;
      }

      // 規則篩選
      if (filter == ScanFilter.all) return true;

      // Must have detailed reasons loaded
      final reasons = allReasons[analysis.symbol];
      if (reasons == null || reasons.isEmpty) return false;

      if (filter.reasonCode == null) return true;

      return reasons.any((r) => r.reasonType == filter.reasonCode);
    }).toList();
  }

  // ==================================================
  // 排序邏輯
  // ==================================================

  /// 套用全域排序：依 [sort] 對分析結果排序
  ///
  /// 就地排序（in-place），直接修改傳入的 list。
  void applySort(List<DailyAnalysisEntry> analyses, ScanSort sort) {
    if (sort == ScanSort.scoreAsc) {
      analyses.sort((a, b) => a.score.compareTo(b.score));
    } else {
      // Default: Score Desc
      analyses.sort((b, a) => a.score.compareTo(b.score));
    }
  }

  // ==================================================
  // 資料轉換邏輯
  // ==================================================

  /// 將分析結果批次轉換為 [ScanStockItem] 列表
  ///
  /// 從 [CachedDatabaseAccessor] 載入詳細資料並組裝為 UI 所需的物件。
  Future<List<ScanStockItem>> buildStockItems({
    required List<DailyAnalysisEntry> analyses,
    required DateContext dateCtx,
    required CachedDatabaseAccessor cachedDb,
    required Set<String> watchlistSymbols,
  }) async {
    if (analyses.isEmpty) return [];

    final symbols = analyses.map((a) => a.symbol).toList();

    // Type-safe batch load using Dart 3 Records
    final data = await cachedDb.loadScanData(
      symbols: symbols,
      analysisDate: dateCtx.today,
      historyStart: dateCtx.historyStart,
    );

    // Destructure Record fields
    final stocksMap = data.stocks;
    final latestPricesMap = data.latestPrices;
    final reasonsMap = data.reasons;
    final priceHistoriesMap = data.priceHistories;

    // Calculate price changes using utility
    final priceChanges = PriceCalculator.calculatePriceChangesBatch(
      priceHistoriesMap,
      latestPricesMap,
    );

    // Build stock items
    return analyses.map((analysis) {
      final latestPrice = latestPricesMap[analysis.symbol];
      final priceHistory = priceHistoriesMap[analysis.symbol];
      // 擷取最近 30 天收盤價供迷你走勢圖使用
      // priceHistory 按日期升序排列，需取最後 30 筆才是最近的資料
      List<double>? recentPrices;
      if (priceHistory != null && priceHistory.isNotEmpty) {
        final startIdx = priceHistory.length > 30
            ? priceHistory.length - 30
            : 0;
        recentPrices = priceHistory
            .sublist(startIdx)
            .map((p) => p.close)
            .whereType<double>()
            .toList();
      }
      return ScanStockItem(
        symbol: analysis.symbol,
        score: analysis.score,
        stockName: stocksMap[analysis.symbol]?.name,
        market: stocksMap[analysis.symbol]?.market,
        industry: stocksMap[analysis.symbol]?.industry,
        latestClose: latestPrice?.close,
        priceChange: priceChanges[analysis.symbol],
        volume: latestPrice?.volume,
        trendState: analysis.trendState,
        reasons: reasonsMap[analysis.symbol] ?? [],
        isInWatchlist: watchlistSymbols.contains(analysis.symbol),
        recentPrices: recentPrices,
      );
    }).toList();
  }
}
