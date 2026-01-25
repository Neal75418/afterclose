import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';

/// 市場籌碼資料更新器
///
/// 負責同步當沖、融資融券、外資持股等籌碼資料
class MarketDataUpdater {
  const MarketDataUpdater({
    required AppDatabase database,
    required MarketDataRepository marketDataRepository,
  }) : _db = database,
       _marketDataRepo = marketDataRepository;

  final AppDatabase _db;
  final MarketDataRepository _marketDataRepo;

  /// 同步全市場籌碼資料（TWSE 批次 API）
  ///
  /// 包含當沖和融資融券資料
  Future<MarketDataSyncResult> syncMarketWideData({
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    var dayTradingCount = 0;
    var marginCount = 0;

    // 從 TWSE 批次同步當沖資料
    try {
      dayTradingCount = await _marketDataRepo.syncAllDayTradingFromTwse(
        date: date,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '當沖資料同步失敗: $e');
    }

    // 從 TWSE 批次同步融資融券資料
    try {
      marginCount = await _marketDataRepo.syncAllMarginTradingFromTwse(
        date: date,
      );
    } catch (e) {
      AppLogger.warning('MarketDataUpdater', '融資融券資料同步失敗: $e');
    }

    return MarketDataSyncResult(
      dayTradingCount: dayTradingCount,
      marginCount: marginCount,
    );
  }

  /// 同步特定股票清單的籌碼資料
  ///
  /// 用於自選清單和熱門股的詳細籌碼追蹤
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
          await Future.wait([
            _marketDataRepo.syncShareholding(
              symbol,
              startDate: marketDataStartDate,
              endDate: date,
            ),
            _marketDataRepo.syncDayTrading(
              symbol,
              startDate: marketDataStartDate,
              endDate: date,
            ),
          ]);
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

  /// 補充上櫃候選股票的籌碼資料
  ///
  /// 上櫃股票沒有 TWSE 批次 API，需使用 FinMind 逐檔補充
  Future<OtcMarketDataResult> syncOtcCandidatesMarketData({
    required List<String> candidates,
    required DateTime date,
    int maxSyncCount = 100,
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

    final marketDataStartDate = date.subtract(
      const Duration(days: RuleParams.foreignShareholdingLookbackDays + 5),
    );

    var dayTradingCount = 0;
    var shareholdingCount = 0;

    const chunkSize = 5;
    for (var i = 0; i < limitedOtcCandidates.length; i += chunkSize) {
      final chunk = limitedOtcCandidates.skip(i).take(chunkSize).toList();

      final futures = chunk.map((symbol) async {
        try {
          final results = await Future.wait([
            _marketDataRepo.syncDayTrading(
              symbol,
              startDate: marketDataStartDate,
              endDate: date,
            ),
            _marketDataRepo.syncShareholding(
              symbol,
              startDate: marketDataStartDate,
              endDate: date,
            ),
          ]);
          return (results[0] > 0, results[1] > 0);
        } catch (e) {
          AppLogger.debug('MarketDataUpdater', '$symbol 上櫃市場資料同步失敗: $e');
          return (false, false);
        }
      });

      final results = await Future.wait(futures);
      for (final (dt, sh) in results) {
        if (dt) dayTradingCount++;
        if (sh) shareholdingCount++;
      }
    }

    return OtcMarketDataResult(
      dayTradingCount: dayTradingCount,
      shareholdingCount: shareholdingCount,
      totalCandidates: otcCandidates.length,
      syncedCandidates: limitedOtcCandidates.length,
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
  final int marginCount;

  int get total => dayTradingCount + marginCount;
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
