import 'dart:collection';

/// A simple LRU (Least Recently Used) cache with TTL (Time To Live) support.
///
/// Features:
/// - Generic key-value storage
/// - Configurable maximum capacity
/// - Configurable TTL (default 30 seconds)
/// - Automatic eviction of expired and least recently used entries
///
/// Usage:
/// ```dart
/// final cache = LruCache<String, List<Price>>(maxSize: 100);
/// cache.put('2330', prices);
/// final cached = cache.get('2330');
/// ```
class LruCache<K, V> {
  LruCache({
    this.maxSize = 100,
    this.ttl = const Duration(seconds: 30),
  });

  /// Maximum number of entries in the cache
  final int maxSize;

  /// Time-to-live for cache entries
  final Duration ttl;

  /// Internal storage using LinkedHashMap for LRU ordering
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();

  /// Cache hit counter for statistics
  int _hits = 0;

  /// Cache miss counter for statistics
  int _misses = 0;

  /// Get a value from the cache.
  ///
  /// Returns null if the key doesn't exist or if the entry has expired.
  /// Accessing a key moves it to the end (most recently used).
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    // Check if entry has expired
    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = entry;

    _hits++;
    return entry.value;
  }

  /// Put a value in the cache.
  ///
  /// If the cache is at capacity, removes the least recently used entry.
  void put(K key, V value) {
    // Remove if exists to update position
    _cache.remove(key);

    // Evict oldest if at capacity
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // Add new entry
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Check if a key exists and is not expired.
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Remove a specific key from the cache.
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clear all entries from the cache.
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Remove all expired entries from the cache.
  void evictExpired() {
    final expiredKeys = <K>[];
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  /// Get the current number of entries in the cache.
  int get length => _cache.length;

  /// Check if the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Get cache statistics for debugging.
  CacheStats get stats => CacheStats(
        size: _cache.length,
        maxSize: maxSize,
        ttlSeconds: ttl.inSeconds,
        hits: _hits,
        misses: _misses,
      );
}

/// Internal cache entry with expiration time.
class _CacheEntry<V> {
  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final V value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache statistics for debugging and monitoring.
class CacheStats {
  const CacheStats({
    required this.size,
    required this.maxSize,
    required this.ttlSeconds,
    this.hits = 0,
    this.misses = 0,
  });

  final int size;
  final int maxSize;
  final int ttlSeconds;
  final int hits;
  final int misses;

  /// Cache usage percentage (size / maxSize).
  double get usagePercent => maxSize > 0 ? (size / maxSize) * 100 : 0;

  /// Cache hit rate (hits / total requests).
  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0;

  /// Total number of cache lookups.
  int get totalRequests => hits + misses;

  @override
  String toString() =>
      'CacheStats(size: $size/$maxSize, ttl: ${ttlSeconds}s, '
      'usage: ${usagePercent.toStringAsFixed(1)}%, '
      'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
      'hits: $hits, misses: $misses)';
}

/// A cache manager for batch queries with automatic key generation.
///
/// Usage:
/// ```dart
/// final manager = BatchQueryCacheManager();
///
/// // Cache price history for symbols
/// final cached = manager.getPriceHistory(symbols, startDate, endDate);
/// if (cached != null) return cached;
///
/// final result = await _db.getPriceHistoryBatch(...);
/// manager.cachePriceHistory(symbols, startDate, endDate, result);
/// ```
class BatchQueryCacheManager {
  BatchQueryCacheManager({
    int maxSize = 50,
    Duration ttl = const Duration(seconds: 30),
  })  : _latestPricesCache = LruCache(maxSize: maxSize, ttl: ttl),
        _priceHistoryCache = LruCache(maxSize: maxSize, ttl: ttl),
        _analysesCache = LruCache(maxSize: maxSize, ttl: ttl),
        _reasonsCache = LruCache(maxSize: maxSize, ttl: ttl);

  final LruCache<String, Map<String, dynamic>> _latestPricesCache;
  final LruCache<String, Map<String, List<dynamic>>> _priceHistoryCache;
  final LruCache<String, Map<String, dynamic>> _analysesCache;
  final LruCache<String, Map<String, List<dynamic>>> _reasonsCache;

  // ==================================================
  // Latest Prices Cache
  // ==================================================

  /// Get cached latest prices for symbols.
  Map<String, T>? getLatestPrices<T>(List<String> symbols) {
    final key = _makeKey('latest', symbols);
    final cached = _latestPricesCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v as T));
  }

  /// Cache latest prices for symbols.
  void cacheLatestPrices<T>(List<String> symbols, Map<String, T> data) {
    final key = _makeKey('latest', symbols);
    _latestPricesCache.put(key, data.map((k, v) => MapEntry(k, v as dynamic)));
  }

  // ==================================================
  // Price History Cache
  // ==================================================

  /// Get cached price history for symbols.
  Map<String, List<T>>? getPriceHistory<T>(
    List<String> symbols,
    DateTime startDate,
    DateTime? endDate,
  ) {
    final key = _makeHistoryKey('history', symbols, startDate, endDate);
    final cached = _priceHistoryCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v.cast<T>()));
  }

  /// Cache price history for symbols.
  void cachePriceHistory<T>(
    List<String> symbols,
    DateTime startDate,
    DateTime? endDate,
    Map<String, List<T>> data,
  ) {
    final key = _makeHistoryKey('history', symbols, startDate, endDate);
    _priceHistoryCache.put(
      key,
      data.map((k, v) => MapEntry(k, v.cast<dynamic>())),
    );
  }

  // ==================================================
  // Analyses Cache
  // ==================================================

  /// Get cached analyses for symbols on a date.
  Map<String, T>? getAnalyses<T>(List<String> symbols, DateTime date) {
    final key = _makeDateKey('analyses', symbols, date);
    final cached = _analysesCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v as T));
  }

  /// Cache analyses for symbols on a date.
  void cacheAnalyses<T>(
    List<String> symbols,
    DateTime date,
    Map<String, T> data,
  ) {
    final key = _makeDateKey('analyses', symbols, date);
    _analysesCache.put(key, data.map((k, v) => MapEntry(k, v as dynamic)));
  }

  // ==================================================
  // Reasons Cache
  // ==================================================

  /// Get cached reasons for symbols on a date.
  Map<String, List<T>>? getReasons<T>(List<String> symbols, DateTime date) {
    final key = _makeDateKey('reasons', symbols, date);
    final cached = _reasonsCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v.cast<T>()));
  }

  /// Cache reasons for symbols on a date.
  void cacheReasons<T>(
    List<String> symbols,
    DateTime date,
    Map<String, List<T>> data,
  ) {
    final key = _makeDateKey('reasons', symbols, date);
    _reasonsCache.put(
      key,
      data.map((k, v) => MapEntry(k, v.cast<dynamic>())),
    );
  }

  // ==================================================
  // Cache Management
  // ==================================================

  /// Clear all caches.
  void clearAll() {
    _latestPricesCache.clear();
    _priceHistoryCache.clear();
    _analysesCache.clear();
    _reasonsCache.clear();
  }

  /// Evict expired entries from all caches.
  void evictExpired() {
    _latestPricesCache.evictExpired();
    _priceHistoryCache.evictExpired();
    _analysesCache.evictExpired();
    _reasonsCache.evictExpired();
  }

  // ==================================================
  // Key Generation
  // ==================================================

  /// Generate a simple key for symbol lists.
  String _makeKey(String prefix, List<String> symbols) {
    final sorted = List<String>.from(symbols)..sort();
    return '$prefix:${sorted.join(",")}';
  }

  /// Generate a key with date.
  String _makeDateKey(String prefix, List<String> symbols, DateTime date) {
    final sorted = List<String>.from(symbols)..sort();
    final dateStr = _formatDate(date);
    return '$prefix:$dateStr:${sorted.join(",")}';
  }

  /// Generate a key for date ranges.
  String _makeHistoryKey(
    String prefix,
    List<String> symbols,
    DateTime startDate,
    DateTime? endDate,
  ) {
    final sorted = List<String>.from(symbols)..sort();
    final startStr = _formatDate(startDate);
    final endStr = endDate != null ? _formatDate(endDate) : 'now';
    return '$prefix:$startStr:$endStr:${sorted.join(",")}';
  }

  /// Format date as ISO-like string (YYYY-MM-DD) for consistent cache keys.
  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
