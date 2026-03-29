import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';

/// 基本面資料同步器
///
/// 負責同步營收、PE、PBR、殖利率等基本面資料
class FundamentalSyncer {
  const FundamentalSyncer({
    required AppDatabase database,
    required FundamentalRepository fundamentalRepository,
    MarketDataRepository? marketDataRepository,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _fundamentalRepo = fundamentalRepository,
       _marketDataRepo = marketDataRepository,
       _clock = clock;

  final AppDatabase _db;
  final FundamentalRepository _fundamentalRepo;
  final MarketDataRepository? _marketDataRepo;
  final AppClock _clock;

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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '估值資料同步失敗', e);
    }

    try {
      revenueCount = await _fundamentalRepo.syncAllMarketRevenue(date);
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '營收資料同步失敗', e);
    }

    final revenueLabel = revenueCount < 0 ? '已快取' : '$revenueCount';
    AppLogger.info(
      'FundamentalSyncer',
      '全市場基本面: 估值=$valuationCount, 營收=$revenueLabel',
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
    final otcStocks = await _db.getStocksByMarket(MarketCode.tpex);
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃自選估值同步失敗', e);
    }

    try {
      revenueCount = await _fundamentalRepo.syncOtcRevenue(
        otcWatchlistSymbols,
        date: date,
      );
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃自選營收同步失敗', e);
    }

    AppLogger.info(
      'FundamentalSyncer',
      '上櫃自選 ${otcWatchlistSymbols.length} 檔: 估值=$valuationCount, 營收=$revenueCount',
    );

    return FundamentalSyncResult(
      valuationCount: valuationCount,
      revenueCount: revenueCount,
    );
  }

  /// 補充上櫃候選股票的基本面資料
  ///
  /// 用於分析前補充候選清單中上櫃股票的基本面
  Future<FundamentalSyncResult> syncOtcCandidatesFundamentals({
    required List<String> candidates,
    required DateTime date,
    int maxSyncCount = ApiConfig.otcFundamentalsSyncMaxCount,
  }) async {
    if (candidates.isEmpty) {
      return const FundamentalSyncResult(valuationCount: 0, revenueCount: 0);
    }

    // 取得上櫃股票清單
    final otcStocks = await _db.getStocksByMarket(MarketCode.tpex);
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃候選估值同步失敗', e);
    }

    try {
      revenueCount = await _fundamentalRepo.syncOtcRevenue(
        limitedOtcCandidates,
        date: date,
      );
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('FundamentalSyncer', '上櫃候選營收同步失敗', e);
    }

    return FundamentalSyncResult(
      valuationCount: valuationCount,
      revenueCount: revenueCount,
    );
  }

  /// 同步指定股票清單的損益表資料（含 EPS）
  ///
  /// 每批 10 檔並行，批間延遲 500ms 避免超過 FinMind 配額。
  /// 每檔股票內部有 90 天新鮮度檢查。
  /// ETF（代碼以 00 開頭）無財報資料，自動過濾以避免無效 API 呼叫。
  Future<int> syncFinancialStatements({required List<String> symbols}) async {
    // 過濾 ETF：00 開頭的代碼（0050、00636、006205 等）沒有財報資料
    final stockSymbols = symbols.where((s) => !s.startsWith('00')).toList();
    if (stockSymbols.isEmpty) return 0;

    if (stockSymbols.length < symbols.length) {
      AppLogger.debug(
        'FundamentalSyncer',
        '財報同步: 跳過 ${symbols.length - stockSymbols.length} 檔 ETF，'
            '實際同步 ${stockSymbols.length} 檔',
      );
    }

    final now = _clock.now();
    final start = now.subtract(
      const Duration(days: ApiConfig.financialSyncLookbackDays),
    );
    final end = now;
    var count = 0;

    const chunkSize = ApiConfig.syncerBatchSize;
    for (var i = 0; i < stockSymbols.length; i += chunkSize) {
      final chunk = stockSymbols.skip(i).take(chunkSize).toList();
      final results = await Future.wait(
        chunk.map(
          (s) => _fundamentalRepo.syncFinancialStatements(
            symbol: s,
            startDate: start,
            endDate: end,
          ),
        ),
      );
      count += results.fold(0, (sum, n) => sum + n);

      if (i + chunkSize < stockSymbols.length) {
        await Future.delayed(
          const Duration(milliseconds: ApiConfig.syncerBatchDelayMs),
        );
      }
    }

    if (count > 0) {
      AppLogger.info(
        'FundamentalSyncer',
        '財報同步: $count 筆 (${stockSymbols.length} 檔)',
      );
    }
    return count;
  }

  /// 同步指定股票清單的資產負債表資料
  ///
  /// 每批 10 檔並行，批間延遲 500ms 避免超過 FinMind 配額。
  /// 需要 MarketDataRepository 才能使用。
  /// ETF（代碼以 00 開頭）無財報資料，自動過濾以避免無效 API 呼叫。
  Future<int> syncBalanceSheets({required List<String> symbols}) async {
    final marketDataRepo = _marketDataRepo;
    // 過濾 ETF：00 開頭的代碼（0050、00636、006205 等）沒有資產負債表資料
    final stockSymbols = symbols.where((s) => !s.startsWith('00')).toList();
    if (marketDataRepo == null || stockSymbols.isEmpty) return 0;

    if (stockSymbols.length < symbols.length) {
      AppLogger.debug(
        'FundamentalSyncer',
        '資產負債表同步: 跳過 ${symbols.length - stockSymbols.length} 檔 ETF，'
            '實際同步 ${stockSymbols.length} 檔',
      );
    }

    final now = _clock.now();
    final start = now.subtract(
      const Duration(days: ApiConfig.financialSyncLookbackDays),
    );
    final end = now;
    var count = 0;

    const chunkSize = ApiConfig.syncerBatchSize;
    for (var i = 0; i < stockSymbols.length; i += chunkSize) {
      final chunk = stockSymbols.skip(i).take(chunkSize).toList();
      final results = await Future.wait(
        chunk.map((s) async {
          try {
            return await marketDataRepo.syncBalanceSheet(
              s,
              startDate: start,
              endDate: end,
            );
          } on RateLimitException {
            rethrow;
          } catch (e) {
            AppLogger.warning('FundamentalSyncer', '$s: 資產負債表同步失敗', e);
            return 0;
          }
        }),
      );
      count += results.fold(0, (sum, n) => sum + n);

      if (i + chunkSize < stockSymbols.length) {
        await Future.delayed(
          const Duration(milliseconds: ApiConfig.syncerBatchDelayMs),
        );
      }
    }

    if (count > 0) {
      AppLogger.info(
        'FundamentalSyncer',
        '資產負債表同步: $count 筆 (${stockSymbols.length} 檔)',
      );
      return count;
    } else {
      AppLogger.debug(
        'FundamentalSyncer',
        '資產負債表: ${stockSymbols.length} 檔皆已快取，無需同步',
      );
      return -1;
    }
  }
}

/// 基本面同步結果
class FundamentalSyncResult {
  const FundamentalSyncResult({
    required this.valuationCount,
    required this.revenueCount,
  });

  final int valuationCount;

  /// 營收同步筆數。-1 表示已快取（跳過同步）。
  final int revenueCount;

  bool get revenueCached => revenueCount < 0;
  int get total => valuationCount + (revenueCount < 0 ? 0 : revenueCount);
}
