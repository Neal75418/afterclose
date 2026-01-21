import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/settings_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/services/update_service.dart';

// ==================================================
// Core Infrastructure
// ==================================================

/// App database singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Batch query cache manager (30-second TTL for update cycle optimization)
final batchCacheProvider = Provider<BatchQueryCacheManager>((ref) {
  return BatchQueryCacheManager(
    maxSize: 50,
    ttl: const Duration(seconds: 30),
  );
});

/// Cached database accessor for optimized batch queries
final cachedDbProvider = Provider<CachedDatabaseAccessor>((ref) {
  return CachedDatabaseAccessor(
    db: ref.watch(databaseProvider),
    cache: ref.watch(batchCacheProvider),
  );
});

/// FinMind API client (for historical data)
final finMindClientProvider = Provider<FinMindClient>((ref) {
  return FinMindClient();
});

/// TWSE Open Data client (for daily all-market prices)
final twseClientProvider = Provider<TwseClient>((ref) {
  return TwseClient();
});

/// RSS parser
final rssParserProvider = Provider<RssParser>((ref) {
  return RssParser();
});

// ==================================================
// Repositories
// ==================================================

/// Stock repository provider
final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
  );
});

/// Price repository provider
/// Uses TWSE for daily prices, FinMind for historical data
final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
    twseClient: ref.watch(twseClientProvider),
  );
});

/// News repository provider
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(
    database: ref.watch(databaseProvider),
    rssParser: ref.watch(rssParserProvider),
  );
});

/// Analysis repository provider
final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository(database: ref.watch(databaseProvider));
});

/// Institutional repository provider
final institutionalRepositoryProvider = Provider<InstitutionalRepository>((
  ref,
) {
  return InstitutionalRepository(
    database: ref.watch(databaseProvider),
    finMindClient: ref.watch(finMindClientProvider),
  );
});

/// Settings repository provider (with secure storage for sensitive data)
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(database: ref.watch(databaseProvider));
});

// ==================================================
// Services
// ==================================================

/// Update service provider
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    database: ref.watch(databaseProvider),
    stockRepository: ref.watch(stockRepositoryProvider),
    priceRepository: ref.watch(priceRepositoryProvider),
    newsRepository: ref.watch(newsRepositoryProvider),
    analysisRepository: ref.watch(analysisRepositoryProvider),
    institutionalRepository: ref.watch(institutionalRepositoryProvider),
  );
});
