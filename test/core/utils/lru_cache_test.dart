import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================
  // LruCache
  // ==========================================
  group('LruCache', () {
    test('put and get return cached value', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      expect(cache.get('a'), equals(1));
    });

    test('get returns null for missing key', () {
      final cache = LruCache<String, int>(maxSize: 10);
      expect(cache.get('missing'), isNull);
    });

    test('evicts least recently used when full', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      // Cache is full [a, b, c], adding 'd' should evict 'a'
      cache.put('d', 4);

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), equals(2));
      expect(cache.get('d'), equals(4));
      expect(cache.length, equals(3));
    });

    test('accessing a key moves it to most recently used', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      // Access 'a' → now [b, c, a]
      cache.get('a');
      // Add 'd' → evicts 'b' (LRU)
      cache.put('d', 4);

      expect(cache.get('a'), equals(1)); // Still present
      expect(cache.get('b'), isNull); // Evicted
    });

    test('TTL expiry removes stale entries on get', () async {
      final cache = LruCache<String, int>(
        maxSize: 10,
        ttl: const Duration(milliseconds: 50),
      );
      cache.put('a', 1);
      expect(cache.get('a'), equals(1));

      // Wait for TTL to expire
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cache.get('a'), isNull);
    });

    test('containsKey returns false for expired entry', () async {
      final cache = LruCache<String, int>(
        maxSize: 10,
        ttl: const Duration(milliseconds: 50),
      );
      cache.put('a', 1);
      expect(cache.containsKey('a'), isTrue);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(cache.containsKey('a'), isFalse);
    });

    test('remove deletes specific key', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.remove('a');

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), equals(2));
      expect(cache.length, equals(1));
    });

    test('clear removes all entries and resets stats', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.get('a'); // hit
      cache.get('c'); // miss

      cache.clear();

      expect(cache.isEmpty, isTrue);
      expect(cache.length, equals(0));
      expect(cache.stats.hits, equals(0));
      expect(cache.stats.misses, equals(0));
    });

    test('evictExpired removes only expired entries', () async {
      final cache = LruCache<String, int>(
        maxSize: 10,
        ttl: const Duration(milliseconds: 50),
      );
      cache.put('old', 1);

      await Future.delayed(const Duration(milliseconds: 100));

      // Add fresh entry after delay
      cache.put('fresh', 2);
      cache.evictExpired();

      expect(cache.containsKey('old'), isFalse);
      expect(cache.get('fresh'), equals(2));
      expect(cache.length, equals(1));
    });

    test('stats track hits and misses correctly', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      cache.get('a'); // hit
      cache.get('a'); // hit
      cache.get('b'); // miss

      final stats = cache.stats;
      expect(stats.hits, equals(2));
      expect(stats.misses, equals(1));
      expect(stats.totalRequests, equals(3));
      expect(stats.hitRate, closeTo(2 / 3, 0.01));
      expect(stats.size, equals(1));
      expect(stats.maxSize, equals(10));
    });

    test('put overwrites existing key', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      cache.put('a', 99);

      expect(cache.get('a'), equals(99));
      expect(cache.length, equals(1));
    });
  });

  // ==========================================
  // BatchQueryCacheManager
  // ==========================================
  group('BatchQueryCacheManager', () {
    test('caches and retrieves latest prices', () {
      final manager = BatchQueryCacheManager();
      final symbols = ['2330', '2317'];
      final data = {'2330': 580.0, '2317': 120.0};

      manager.cacheLatestPrices(symbols, data);
      final cached = manager.getLatestPrices<double>(symbols);

      expect(cached, isNotNull);
      expect(cached!['2330'], equals(580.0));
      expect(cached['2317'], equals(120.0));
    });

    test('returns null for uncached data', () {
      final manager = BatchQueryCacheManager();
      final result = manager.getLatestPrices<double>(['9999']);

      expect(result, isNull);
    });

    test('caches and retrieves price history', () {
      final manager = BatchQueryCacheManager();
      final symbols = ['2330'];
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 15);
      final data = {
        '2330': [100.0, 101.0, 102.0],
      };

      manager.cachePriceHistory(symbols, start, end, data);
      final cached = manager.getPriceHistory<double>(symbols, start, end);

      expect(cached, isNotNull);
      expect(cached!['2330'], equals([100.0, 101.0, 102.0]));
    });

    test('clearAll removes all cache types', () {
      final manager = BatchQueryCacheManager();
      manager.cacheLatestPrices(['A'], {'A': 100.0});
      manager.cacheAnalyses(['A'], DateTime(2025, 1, 1), {'A': 'analysis'});

      manager.clearAll();

      expect(manager.getLatestPrices<double>(['A']), isNull);
      expect(manager.getAnalyses<String>(['A'], DateTime(2025, 1, 1)), isNull);
    });

    test('cache key is order-independent for symbols', () {
      final manager = BatchQueryCacheManager();

      manager.cacheLatestPrices(['B', 'A'], {'A': 1.0, 'B': 2.0});
      // Query with different order should find cached data
      final cached = manager.getLatestPrices<double>(['A', 'B']);

      expect(cached, isNotNull);
      expect(cached!['A'], equals(1.0));
    });
  });
}
