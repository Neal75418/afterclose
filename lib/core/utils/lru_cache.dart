import 'dart:collection';

/// 支援 TTL（存活時間）的 LRU（最近最少使用）快取
///
/// 功能特點：
/// - 泛型鍵值儲存
/// - 可設定最大容量
/// - 可設定 TTL（預設 5 分鐘）
/// - 自動清除過期及最久未使用的項目
///
/// 使用範例：
/// ```dart
/// final cache = LruCache<String, List<Price>>(maxSize: 100);
/// cache.put('2330', prices);
/// final cached = cache.get('2330');
/// ```
class LruCache<K, V> {
  LruCache({this.maxSize = 100, this.ttl = const Duration(minutes: 5)});

  /// 快取最大項目數
  final int maxSize;

  /// 快取項目存活時間
  final Duration ttl;

  /// 使用 LinkedHashMap 維護 LRU 順序
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();

  /// 命中次數統計
  int _hits = 0;

  /// 未命中次數統計
  int _misses = 0;

  /// 從快取取得值
  ///
  /// 若鍵不存在或已過期則回傳 null。
  /// 存取後該鍵會移至最後（最近使用）。
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    // 檢查是否已過期
    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    // 移至尾端（最近使用）
    _cache.remove(key);
    _cache[key] = entry;

    _hits++;
    return entry.value;
  }

  /// 將值存入快取
  ///
  /// 若快取已滿，會移除最久未使用的項目。
  void put(K key, V value) {
    // 若已存在先移除，以更新位置
    _cache.remove(key);

    // 容量已滿時淘汰最久未使用的項目
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // 新增項目
    _cache[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
  }

  /// 檢查鍵是否存在且未過期
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// 從快取移除指定鍵
  void remove(K key) {
    _cache.remove(key);
  }

  /// 清除所有快取項目
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// 移除所有已過期的項目
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

  /// 取得目前快取項目數量
  int get length => _cache.length;

  /// 檢查快取是否為空
  bool get isEmpty => _cache.isEmpty;

  /// 取得快取統計資訊（供除錯用）
  CacheStats get stats => CacheStats(
    size: _cache.length,
    maxSize: maxSize,
    ttlSeconds: ttl.inSeconds,
    hits: _hits,
    misses: _misses,
  );
}

/// 快取項目（含過期時間）
class _CacheEntry<V> {
  _CacheEntry({required this.value, required this.expiresAt});

  final V value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 快取統計資訊（供除錯與監控用）
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

  /// 快取使用率（size / maxSize）
  double get usagePercent => maxSize > 0 ? (size / maxSize) * 100 : 0;

  /// 命中率（hits / 總請求數）
  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0;

  /// 總查詢次數
  int get totalRequests => hits + misses;

  @override
  String toString() =>
      'CacheStats(size: $size/$maxSize, ttl: ${ttlSeconds}s, '
      'usage: ${usagePercent.toStringAsFixed(1)}%, '
      'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
      'hits: $hits, misses: $misses)';
}

/// 批次查詢快取管理器（自動產生快取鍵）
///
/// 使用範例：
/// ```dart
/// final manager = BatchQueryCacheManager();
///
/// // 快取價格歷史
/// final cached = manager.getPriceHistory(symbols, startDate, endDate);
/// if (cached != null) return cached;
///
/// final result = await _db.getPriceHistoryBatch(...);
/// manager.cachePriceHistory(symbols, startDate, endDate, result);
/// ```
class BatchQueryCacheManager {
  BatchQueryCacheManager({
    int maxSize = 50,
    Duration ttl = const Duration(minutes: 5),
  }) : _latestPricesCache = LruCache(maxSize: maxSize, ttl: ttl),
       _priceHistoryCache = LruCache(maxSize: maxSize, ttl: ttl),
       _analysesCache = LruCache(maxSize: maxSize, ttl: ttl),
       _reasonsCache = LruCache(maxSize: maxSize, ttl: ttl);

  final LruCache<String, Map<String, dynamic>> _latestPricesCache;
  final LruCache<String, Map<String, List<dynamic>>> _priceHistoryCache;
  final LruCache<String, Map<String, dynamic>> _analysesCache;
  final LruCache<String, Map<String, List<dynamic>>> _reasonsCache;

  // ==================================================
  // 最新價格快取
  // ==================================================

  /// 取得快取的最新價格
  Map<String, T>? getLatestPrices<T>(List<String> symbols) {
    final key = _makeKey('latest', symbols);
    final cached = _latestPricesCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v as T));
  }

  /// 快取最新價格
  void cacheLatestPrices<T>(List<String> symbols, Map<String, T> data) {
    final key = _makeKey('latest', symbols);
    _latestPricesCache.put(key, data.map((k, v) => MapEntry(k, v as dynamic)));
  }

  // ==================================================
  // 價格歷史快取
  // ==================================================

  /// 取得快取的價格歷史
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

  /// 快取價格歷史
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
  // 分析結果快取
  // ==================================================

  /// 取得快取的分析結果
  Map<String, T>? getAnalyses<T>(List<String> symbols, DateTime date) {
    final key = _makeDateKey('analyses', symbols, date);
    final cached = _analysesCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v as T));
  }

  /// 快取分析結果
  void cacheAnalyses<T>(
    List<String> symbols,
    DateTime date,
    Map<String, T> data,
  ) {
    final key = _makeDateKey('analyses', symbols, date);
    _analysesCache.put(key, data.map((k, v) => MapEntry(k, v as dynamic)));
  }

  // ==================================================
  // 推薦理由快取
  // ==================================================

  /// 取得快取的推薦理由
  Map<String, List<T>>? getReasons<T>(List<String> symbols, DateTime date) {
    final key = _makeDateKey('reasons', symbols, date);
    final cached = _reasonsCache.get(key);
    if (cached == null) return null;
    return cached.map((k, v) => MapEntry(k, v.cast<T>()));
  }

  /// 快取推薦理由
  void cacheReasons<T>(
    List<String> symbols,
    DateTime date,
    Map<String, List<T>> data,
  ) {
    final key = _makeDateKey('reasons', symbols, date);
    _reasonsCache.put(key, data.map((k, v) => MapEntry(k, v.cast<dynamic>())));
  }

  // ==================================================
  // 快取管理
  // ==================================================

  /// 清除所有快取
  void clearAll() {
    _latestPricesCache.clear();
    _priceHistoryCache.clear();
    _analysesCache.clear();
    _reasonsCache.clear();
  }

  /// 僅清除價格相關快取（最新價格 + 價格歷史）
  void clearPrices() {
    _latestPricesCache.clear();
    _priceHistoryCache.clear();
  }

  /// 僅清除分析結果快取
  void clearAnalyses() {
    _analysesCache.clear();
  }

  /// 僅清除推薦理由快取
  void clearReasons() {
    _reasonsCache.clear();
  }

  /// 清除所有快取中的過期項目
  void evictExpired() {
    _latestPricesCache.evictExpired();
    _priceHistoryCache.evictExpired();
    _analysesCache.evictExpired();
    _reasonsCache.evictExpired();
  }

  // ==================================================
  // 快取鍵產生
  // ==================================================

  /// 為股票代號列表產生簡單鍵
  String _makeKey(String prefix, List<String> symbols) {
    final sorted = List<String>.from(symbols)..sort();
    return '$prefix:${sorted.join(",")}';
  }

  /// 產生含日期的鍵
  String _makeDateKey(String prefix, List<String> symbols, DateTime date) {
    final sorted = List<String>.from(symbols)..sort();
    final dateStr = _formatDate(date);
    return '$prefix:$dateStr:${sorted.join(",")}';
  }

  /// 產生日期區間的鍵
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

  /// 格式化日期為 ISO 格式（YYYY-MM-DD）以確保快取鍵一致
  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
