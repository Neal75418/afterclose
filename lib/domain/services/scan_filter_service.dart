import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/models/scan_models.dart';

/// 掃描畫面的純業務邏輯服務
///
/// 負責篩選、排序、資料轉換等業務邏輯，
/// 不持有狀態，不依賴 Riverpod，可獨立測試。
///
/// 注意：日期回退邏輯已移至 [IAnalysisRepository.findLatestAnalyses]，
/// 統一由 Repository 層處理日期正規化，避免重複實作與正規化遺漏。
class ScanFilterService {
  const ScanFilterService();

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

      // 須已載入詳細推薦理由
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
      // 預設：分數降冪
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

    // 解構 Record 欄位
    final stocksMap = data.stocks;
    final latestPricesMap = data.latestPrices;
    final reasonsMap = data.reasons;
    final priceHistoriesMap = data.priceHistories;

    // 使用工具計算漲跌幅
    final priceChanges = PriceCalculator.calculatePriceChangesBatch(
      priceHistoriesMap,
      latestPricesMap,
    );

    // 建構股票項目
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
