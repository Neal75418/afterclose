import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/settings_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/event_repository.dart';
import 'package:afterclose/data/repositories/portfolio_repository.dart';
import 'package:afterclose/domain/services/api_connection_service.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';

// ==================================================
// 核心基礎設施
// ==================================================

/// 應用程式資料庫單例
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 批次查詢快取管理器（30 秒 TTL，優化更新週期）
final batchCacheProvider = Provider<BatchQueryCacheManager>((ref) {
  return BatchQueryCacheManager(maxSize: 50, ttl: const Duration(seconds: 30));
});

/// 快取資料庫存取器，用於優化批次查詢
final cachedDbProvider = Provider<CachedDatabaseAccessor>((ref) {
  return CachedDatabaseAccessor(
    db: ref.watch(databaseProvider),
    cache: ref.watch(batchCacheProvider),
  );
});

/// FinMind API 客戶端（用於取得歷史資料）
///
/// 當使用者變更快取時間設定時，此 provider 會被 invalidate 並重建。
final finMindClientProvider = Provider<FinMindClient>((ref) {
  final cacheDuration = ref.watch(cacheDurationProvider);
  return FinMindClient(cacheTtl: Duration(minutes: cacheDuration));
});

/// TWSE 開放資料客戶端（用於取得每日全市場上市價格）
final twseClientProvider = Provider<TwseClient>((ref) {
  return TwseClient();
});

/// TPEX 開放資料客戶端（用於取得每日全市場上櫃價格）
final tpexClientProvider = Provider<TpexClient>((ref) {
  return TpexClient();
});

/// RSS 解析器
final rssParserProvider = Provider<RssParser>((ref) {
  return RssParser();
});

// ==================================================
// 資料儲存庫
// ==================================================

/// 股票資料儲存庫 Provider
final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
  );
});

/// 價格資料儲存庫 Provider
/// 使用 TWSE/TPEX 取得每日價格，使用 FinMind 取得歷史資料
final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
    twseClient: ref.watch(twseClientProvider),
    tpexClient: ref.watch(tpexClientProvider),
  );
});

/// 新聞資料儲存庫 Provider
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(
    database: ref.watch(databaseProvider),
    rssParser: ref.watch(rssParserProvider),
  );
});

/// 分析資料儲存庫 Provider
final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository(database: ref.watch(databaseProvider));
});

/// 法人資料儲存庫 Provider
final institutionalRepositoryProvider = Provider<InstitutionalRepository>((
  ref,
) {
  return InstitutionalRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
    twseClient: ref.watch(twseClientProvider),
    tpexClient: ref.watch(tpexClientProvider),
  );
});

/// 設定資料儲存庫 Provider（使用安全儲存空間存放敏感資料）
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(database: ref.watch(databaseProvider));
});

/// 市場資料儲存庫 Provider（第一階段：擴展市場資料）
final marketDataRepositoryProvider = Provider<MarketDataRepository>((ref) {
  return MarketDataRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
    tpexClient: ref.watch(tpexClientProvider),
  );
});

/// 基本面資料儲存庫 Provider（第六階段：營收、本益比、股價淨值比、殖利率）
final fundamentalRepositoryProvider = Provider<FundamentalRepository>((ref) {
  return FundamentalRepository(
    db: ref.watch(databaseProvider),
    finMind: ref.watch(finMindClientProvider),
  );
});

/// 警示資料儲存庫 Provider（Killer Features：注意股票/處置股票）
final warningRepositoryProvider = Provider<WarningRepository>((ref) {
  return WarningRepository(
    database: ref.watch(databaseProvider),
    tpexClient: ref.watch(tpexClientProvider),
    twseClient: ref.watch(twseClientProvider),
  );
});

/// 董監持股資料儲存庫 Provider（Killer Features：內部人持股變化）
final insiderRepositoryProvider = Provider<InsiderRepository>((ref) {
  return InsiderRepository(
    database: ref.watch(databaseProvider),
    tpexClient: ref.watch(tpexClientProvider),
  );
});

/// 投資組合儲存庫 Provider（Phase 4.4）
final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(database: ref.watch(databaseProvider));
});

/// 事件日曆儲存庫 Provider（Phase 4.3）
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(database: ref.watch(databaseProvider));
});

// ==================================================
// 服務
// ==================================================

/// 資料同步服務 Provider（確保價格與法人資料日期一致）
final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return const DataSyncService();
});

/// API 連線測試服務 Provider
final apiConnectionServiceProvider = Provider<ApiConnectionService>((ref) {
  return const ApiConnectionService();
});

/// 更新服務 Provider
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    database: ref.watch(databaseProvider),
    stockRepository: ref.watch(stockRepositoryProvider),
    priceRepository: ref.watch(priceRepositoryProvider),
    newsRepository: ref.watch(newsRepositoryProvider),
    analysisRepository: ref.watch(analysisRepositoryProvider),
    institutionalRepository: ref.watch(institutionalRepositoryProvider),
    marketDataRepository: ref.watch(marketDataRepositoryProvider),
    fundamentalRepository: ref.watch(fundamentalRepositoryProvider),
    twseClient: ref.watch(twseClientProvider),
  );
});
