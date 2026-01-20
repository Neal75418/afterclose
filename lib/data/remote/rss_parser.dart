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
  Future<List<RssNewsItem>> parseAllFeeds(List<RssFeedSource> sources) async {
    final results = <RssNewsItem>[];

    // Fetch feeds concurrently but don't fail all if one fails
    final futures = sources.map((source) async {
      try {
        return await parseFeed(source);
      } catch (_) {
        // Log error but continue with other feeds
        return <RssNewsItem>[];
      }
    });

    final feedResults = await Future.wait(futures);
    for (final items in feedResults) {
      results.addAll(items);
    }

    // Sort by published date, newest first
    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return results;
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
      id: _generateId(guid ?? link),
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
      id: _generateId(id ?? link),
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

  DateTime _parseRfc822(String dateStr) {
    // Simple RFC 822 parser
    // Format: "Mon, 01 Jan 2026 12:00:00 +0800"
    final months = {
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

    final parts = dateStr.split(' ');
    if (parts.length >= 5) {
      final day = int.tryParse(parts[1]) ?? 1;
      final month = months[parts[2]] ?? 1;
      final year = int.tryParse(parts[3]) ?? DateTime.now().year;
      final timeParts = parts[4].split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute =
          int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
      final second =
          int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;

      return DateTime(year, month, day, hour, minute, second);
    }

    throw const FormatException('Invalid RFC 822 date');
  }

  String _generateId(String input) {
    // Simple hash for ID generation
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & 0xFFFFFFFF; // Convert to 32-bit integer
    }
    return hash.toRadixString(16);
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
