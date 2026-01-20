import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';

/// RSS feed parser for Taiwan financial news
class RssParser {
  RssParser({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'User-Agent': 'AfterClose/1.0'},
      ),
    );
  }

  /// Parse RSS feed from URL
  Future<List<RssNewsItem>> parseFeed(RssFeedSource source) async {
    try {
      final response = await _dio.get(source.url);

      if (response.statusCode == 200) {
        final xmlString = response.data.toString();
        return _parseXml(xmlString, source);
      }

      throw ApiException(
        'Failed to fetch RSS feed: ${source.name}',
        response.statusCode,
      );
    } on DioException catch (e) {
      throw NetworkException('Failed to fetch RSS: ${source.name}', e);
    } on XmlException catch (e) {
      throw ParseException('Failed to parse RSS XML: ${source.name}', e);
    }
  }

  /// Parse multiple feeds concurrently
  ///
  /// Returns a [RssParseResult] containing parsed items and any errors
  Future<RssParseResult> parseAllFeeds(List<RssFeedSource> sources) async {
    final results = <RssNewsItem>[];
    final errors = <RssFeedError>[];

    // Fetch feeds concurrently but don't fail all if one fails
    final futures = sources.map((source) async {
      try {
        return (items: await parseFeed(source), error: null, source: source);
      } catch (e) {
        // Capture error details for debugging
        return (items: <RssNewsItem>[], error: e.toString(), source: source);
      }
    });

    final feedResults = await Future.wait(futures);
    for (final result in feedResults) {
      results.addAll(result.items);
      if (result.error != null) {
        errors.add(
          RssFeedError(
            sourceName: result.source.name,
            url: result.source.url,
            error: result.error!,
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    // Sort by published date, newest first
    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return RssParseResult(items: results, errors: errors);
  }

  List<RssNewsItem> _parseXml(String xmlString, RssFeedSource source) {
    final document = XmlDocument.parse(xmlString);
    final items = <RssNewsItem>[];

    // Try RSS 2.0 format first
    final rssItems = document.findAllElements('item');
    for (final item in rssItems) {
      final newsItem = _parseRssItem(item, source);
      if (newsItem != null) {
        items.add(newsItem);
      }
    }

    // Try Atom format if no RSS items found
    if (items.isEmpty) {
      final atomEntries = document.findAllElements('entry');
      for (final entry in atomEntries) {
        final newsItem = _parseAtomEntry(entry, source);
        if (newsItem != null) {
          items.add(newsItem);
        }
      }
    }

    return items;
  }

  RssNewsItem? _parseRssItem(XmlElement item, RssFeedSource source) {
    final title = _getElementText(item, 'title');
    final link = _getElementText(item, 'link');
    final pubDate = _getElementText(item, 'pubDate');
    final guid = _getElementText(item, 'guid') ?? link;

    if (title == null || link == null) return null;

    return RssNewsItem(
      id: _generateId(guid ?? link, source: source.name),
      source: source.name,
      title: title,
      url: link,
      publishedAt: _parseDate(pubDate) ?? DateTime.now(),
      category: source.category,
    );
  }

  RssNewsItem? _parseAtomEntry(XmlElement entry, RssFeedSource source) {
    final title = _getElementText(entry, 'title');
    final linkElement = entry.findElements('link').firstOrNull;
    final link = linkElement?.getAttribute('href');
    final published =
        _getElementText(entry, 'published') ??
        _getElementText(entry, 'updated');
    final id = _getElementText(entry, 'id') ?? link;

    if (title == null || link == null) return null;

    return RssNewsItem(
      id: _generateId(id ?? link, source: source.name),
      source: source.name,
      title: title,
      url: link,
      publishedAt: _parseDate(published) ?? DateTime.now(),
      category: source.category,
    );
  }

  String? _getElementText(XmlElement parent, String name) {
    final element = parent.findElements(name).firstOrNull;
    return element?.innerText.trim();
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;

    // Try RFC 822 format (RSS)
    try {
      return _parseRfc822(dateStr);
    } catch (_) {}

    // Try ISO 8601 format (Atom)
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    return null;
  }

  /// Timezone offsets in hours
  static const _timezoneOffsets = {
    'GMT': 0,
    'UTC': 0,
    'UT': 0,
    'EST': -5,
    'EDT': -4,
    'CST': -6,
    'CDT': -5,
    'MST': -7,
    'MDT': -6,
    'PST': -8,
    'PDT': -7,
  };

  DateTime _parseRfc822(String dateStr) {
    // RFC 822 parser with timezone support
    // Format: "Mon, 01 Jan 2026 12:00:00 +0800" or "Mon, 01 Jan 2026 12:00:00 GMT"
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    // Remove optional day-of-week prefix
    var cleanedDate = dateStr.trim();
    if (cleanedDate.contains(',')) {
      cleanedDate = cleanedDate.substring(cleanedDate.indexOf(',') + 1).trim();
    }

    final parts = cleanedDate.split(RegExp(r'\s+'));
    if (parts.length < 4) {
      throw const FormatException('Invalid RFC 822 date');
    }

    final day = int.tryParse(parts[0]) ?? 1;
    final month = months[parts[1]] ?? 1;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;

    var hour = 0;
    var minute = 0;
    var second = 0;
    var tzOffsetMinutes = 0;

    if (parts.length >= 4 && parts[3].contains(':')) {
      final timeParts = parts[3].split(':');
      hour = int.tryParse(timeParts[0]) ?? 0;
      minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
      second = int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;

      // Parse timezone if present
      if (parts.length >= 5) {
        final tz = parts[4];
        if (tz.startsWith('+') || tz.startsWith('-')) {
          // Numeric timezone like +0800 or -0500
          final sign = tz.startsWith('+') ? 1 : -1;
          final tzValue = tz.substring(1);
          if (tzValue.length >= 4) {
            final tzHours = int.tryParse(tzValue.substring(0, 2)) ?? 0;
            final tzMins = int.tryParse(tzValue.substring(2, 4)) ?? 0;
            tzOffsetMinutes = sign * (tzHours * 60 + tzMins);
          }
        } else if (_timezoneOffsets.containsKey(tz.toUpperCase())) {
          // Named timezone like GMT, EST, PST
          tzOffsetMinutes = _timezoneOffsets[tz.toUpperCase()]! * 60;
        }
      }
    }

    // Create UTC datetime and adjust for timezone
    final utc = DateTime.utc(year, month, day, hour, minute, second);
    return utc.subtract(Duration(minutes: tzOffsetMinutes));
  }

  /// Generate a unique ID using a better hash algorithm
  ///
  /// Uses FNV-1a hash combined with source info to reduce collisions
  String _generateId(String input, {String? source}) {
    // FNV-1a hash parameters
    const fnvPrime = 0x01000193;
    const fnvOffset = 0x811c9dc5;

    // Combine source with input for better uniqueness
    final combined = source != null ? '$source:$input' : input;
    final bytes = utf8.encode(combined);

    var hash = fnvOffset;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    // Return as padded hex string for consistent length
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// RSS news item
class RssNewsItem {
  const RssNewsItem({
    required this.id,
    required this.source,
    required this.title,
    required this.url,
    required this.publishedAt,
    required this.category,
  });

  final String id;
  final String source;
  final String title;
  final String url;
  final DateTime publishedAt;
  final String category;

  /// Extract potential stock symbols from title
  /// Returns list of potential 4-digit stock codes
  List<String> extractStockCodes() {
    final regex = RegExp(r'\b(\d{4})\b');
    final matches = regex.allMatches(title);
    return matches.map((m) => m.group(1)!).toList();
  }
}

/// Result of parsing multiple RSS feeds
class RssParseResult {
  const RssParseResult({required this.items, required this.errors});

  final List<RssNewsItem> items;
  final List<RssFeedError> errors;

  /// Whether any feeds failed to parse
  bool get hasErrors => errors.isNotEmpty;

  /// Number of successfully parsed items
  int get successCount => items.length;

  /// Number of failed feeds
  int get errorCount => errors.length;
}

/// Error details for a failed RSS feed parse
class RssFeedError {
  const RssFeedError({
    required this.sourceName,
    required this.url,
    required this.error,
    required this.timestamp,
  });

  final String sourceName;
  final String url;
  final String error;
  final DateTime timestamp;

  @override
  String toString() => '[$sourceName] $error ($url)';
}

/// RSS feed source configuration
class RssFeedSource {
  const RssFeedSource({
    required this.name,
    required this.url,
    required this.category,
  });

  final String name;
  final String url;
  final String category; // Maps to NewsCategory

  /// Predefined Taiwan financial news sources
  static const List<RssFeedSource> defaultSources = [
    // MoneyDJ
    RssFeedSource(
      name: 'MoneyDJ',
      url:
          'https://www.moneydj.com/KMDJ/RssCenter.aspx?svc=NR&fno=1&arg=MB010000',
      category: 'OTHER',
    ),
    // Yahoo Taiwan Finance
    RssFeedSource(
      name: 'Yahoo財經',
      url: 'https://tw.stock.yahoo.com/rss?category=tw-market',
      category: 'OTHER',
    ),
    // Add more sources as needed
  ];
}
