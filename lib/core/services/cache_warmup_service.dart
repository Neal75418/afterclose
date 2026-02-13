import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';

/// 快取預熱服務
///
/// 在 App 啟動時預熱常用資料，提升冷啟動後的首次操作速度。
///
/// 預熱策略：
/// 1. 預載自選股清單
/// 2. 預載 Top 20 推薦
/// 3. 批次載入這些股票的分析資料和歷史價格
///
/// 使用範例：
/// ```dart
/// final service = CacheWarmupService(
///   cachedDb: cachedDbAccessor,
///   db: database,
/// );
/// await service.warmup();
/// ```
class CacheWarmupService {
  CacheWarmupService({
    required CachedDatabaseAccessor cachedDb,
    required AppDatabase db,
  }) : _cachedDb = cachedDb,
       _db = db;

  final CachedDatabaseAccessor _cachedDb;
  final AppDatabase _db;

  /// 執行快取預熱
  ///
  /// 此方法非阻塞，即使失敗也不影響 App 啟動。
  Future<void> warmup() async {
    final stopwatch = Stopwatch()..start();

    try {
      final dateCtx = DateContext.now();

      // 1. 預載自選股清單
      final watchlist = await _db.getWatchlist();
      final watchlistSymbols = watchlist.map((e) => e.symbol).toList();

      AppLogger.info('CacheWarmup', '自選股數量: ${watchlistSymbols.length}');

      // 2. 預載 Top 20 推薦
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : dateCtx.today;

      final recommendations = await _db.getRecommendations(analysisDate);
      final recSymbols = recommendations.take(20).map((e) => e.symbol).toList();

      AppLogger.info('CacheWarmup', '今日推薦數量: ${recSymbols.length}');

      // 3. 合併符號清單（去重）
      final allSymbols = {...watchlistSymbols, ...recSymbols}.toList();

      if (allSymbols.isEmpty) {
        AppLogger.info('CacheWarmup', '無資料需預熱');
        stopwatch.stop();
        return;
      }

      // 4. 批次預熱快取
      await _cachedDb.loadStockListData(
        symbols: allSymbols,
        analysisDate: analysisDate,
        historyStart: dateCtx.historyStart,
      );

      stopwatch.stop();
      AppLogger.info(
        'CacheWarmup',
        '預熱完成: ${allSymbols.length} 檔股票 (${stopwatch.elapsedMilliseconds}ms)',
      );
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.error('CacheWarmup', '預熱失敗', e, stack);
    }
  }
}
