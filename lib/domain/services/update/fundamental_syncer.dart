import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';

/// 基本面資料同步器
///
/// 負責同步營收、PE、PBR、殖利率等基本面資料
class FundamentalSyncer {
  const FundamentalSyncer({
    required AppDatabase database,
    required FundamentalRepository fundamentalRepository,
  }) : _db = database,
       _fundamentalRepo = fundamentalRepository;

  final AppDatabase _db;
  final FundamentalRepository _fundamentalRepo;

  /// 同步全市場基本面資料（TWSE 批次 API）
  ///
  /// 包含估值（PE、PBR、殖利率）和營收資料
  Future<FundamentalSyncResult> syncMarketWideFundamentals({
    required DateTime date,
    bool force = false,
  }) async {
    var valuationCount = 0;
    var revenueCount = 0;

    try {
      valuationCount = await _fundamentalRepo.syncAllMarketValuation(
        date,
        force: force,
      );
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '估值資料同步失敗: $e');
    }

    try {
      revenueCount = await _fundamentalRepo.syncAllMarketRevenue(date);
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '營收資料同步失敗: $e');
    }

    AppLogger.info(
      'FundamentalSyncer',
      '全市場基本面: 估值=$valuationCount, 營收=$revenueCount',
    );

    return FundamentalSyncResult(
      valuationCount: valuationCount,
      revenueCount: revenueCount,
    );
  }

  /// 補充上櫃自選股的基本面資料
  ///
  /// TWSE 批次 API 僅涵蓋上市股票，上櫃自選股需逐檔補充
  Future<FundamentalSyncResult> syncOtcWatchlistFundamentals({
    required DateTime date,
  }) async {
    final watchlist = await _db.getWatchlist();
    final otcStocks = await _db.getStocksByMarket('TPEx');
    final otcSymbolSet = otcStocks.map((s) => s.symbol).toSet();

    final otcWatchlistSymbols = watchlist
        .map((w) => w.symbol)
        .where((symbol) => otcSymbolSet.contains(symbol))
        .toList();

    if (otcWatchlistSymbols.isEmpty) {
      return const FundamentalSyncResult(valuationCount: 0, revenueCount: 0);
    }

    var valuationCount = 0;
    var revenueCount = 0;

    try {
      valuationCount = await _fundamentalRepo.syncOtcValuation(
        otcWatchlistSymbols,
        date: date,
      );
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃自選估值同步失敗: $e');
    }

    try {
      revenueCount = await _fundamentalRepo.syncOtcRevenue(
        otcWatchlistSymbols,
        date: date,
      );
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃自選營收同步失敗: $e');
    }

    AppLogger.info(
      'FundamentalSyncer',
      '上櫃自選 ${otcWatchlistSymbols.length} 檔: 估值=$valuationCount, 營收=$revenueCount',
    );

    return FundamentalSyncResult(
      valuationCount: valuationCount,
      revenueCount: revenueCount,
      symbolCount: otcWatchlistSymbols.length,
    );
  }

  /// 補充上櫃候選股票的基本面資料
  ///
  /// 用於分析前補充候選清單中上櫃股票的基本面
  Future<FundamentalSyncResult> syncOtcCandidatesFundamentals({
    required List<String> candidates,
    required DateTime date,
    int maxSyncCount = 100,
  }) async {
    if (candidates.isEmpty) {
      return const FundamentalSyncResult(valuationCount: 0, revenueCount: 0);
    }

    // 取得上櫃股票清單
    final otcStocks = await _db.getStocksByMarket('TPEx');
    final otcSymbols = otcStocks.map((s) => s.symbol).toSet();

    // 篩選出候選清單中的上櫃股票
    final otcCandidates = candidates
        .where((symbol) => otcSymbols.contains(symbol))
        .toList();

    if (otcCandidates.isEmpty) {
      return const FundamentalSyncResult(valuationCount: 0, revenueCount: 0);
    }

    // 限制同步數量以避免超過 API 配額
    final limitedOtcCandidates = otcCandidates.length > maxSyncCount
        ? otcCandidates.take(maxSyncCount).toList()
        : otcCandidates;

    var valuationCount = 0;
    var revenueCount = 0;

    try {
      valuationCount = await _fundamentalRepo.syncOtcValuation(
        limitedOtcCandidates,
        date: date,
      );
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃候選估值同步失敗: $e');
    }

    try {
      revenueCount = await _fundamentalRepo.syncOtcRevenue(
        limitedOtcCandidates,
        date: date,
      );
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃候選營收同步失敗: $e');
    }

    return FundamentalSyncResult(
      valuationCount: valuationCount,
      revenueCount: revenueCount,
      symbolCount: otcCandidates.length,
      syncedCount: limitedOtcCandidates.length,
    );
  }
}

/// 基本面同步結果
class FundamentalSyncResult {
  const FundamentalSyncResult({
    required this.valuationCount,
    required this.revenueCount,
    this.symbolCount = 0,
    this.syncedCount = 0,
  });

  final int valuationCount;
  final int revenueCount;
  final int symbolCount;
  final int syncedCount;

  int get total => valuationCount + revenueCount;
}
