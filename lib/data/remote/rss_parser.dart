import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';

/// 台灣財經新聞 RSS feed 解析器
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

  /// 從 URL 解析 RSS feed
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

  /// 並行解析多個 feeds
  ///
  /// 回傳包含解析結果和錯誤的 [RssParseResult]
  Future<RssParseResult> parseAllFeeds(List<RssFeedSource> sources) async {
    final results = <RssNewsItem>[];
    final errors = <RssFeedError>[];

    // 並行擷取 feeds，單一失敗不影響其他
    final futures = sources.map((source) async {
      try {
        return (items: await parseFeed(source), error: null, source: source);
      } catch (e) {
        // 擷取錯誤詳情供除錯用
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

    // 依發布日期排序，最新的在前
    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return RssParseResult(items: results, errors: errors);
  }

  List<RssNewsItem> _parseXml(String xmlString, RssFeedSource source) {
    final document = XmlDocument.parse(xmlString);
    final items = <RssNewsItem>[];

    // 先嘗試 RSS 2.0 格式
    final rssItems = document.findAllElements('item');
    for (final item in rssItems) {
      final newsItem = _parseRssItem(item, source);
      if (newsItem != null) {
        items.add(newsItem);
      }
    }

    // 若無 RSS 項目則嘗試 Atom 格式
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
    final text = element?.innerText.trim();
    // 空字串回傳 null（例如自閉合標籤 <guid/>）
    return (text == null || text.isEmpty) ? null : text;
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;

    // 嘗試 RFC 822 格式（RSS）
    try {
      return _parseRfc822(dateStr);
    } catch (_) {}

    // 嘗試 ISO 8601 格式（Atom）
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    return null;
  }

  /// 時區偏移量（小時）
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

  /// 月份對照表（不區分大小寫）
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  DateTime _parseRfc822(String dateStr) {
    // RFC 822 解析器（支援時區）
    // 格式: "Mon, 01 Jan 2026 12:00:00 +0800" 或 "Mon, 01 Jan 2026 12:00:00 GMT"
    // 也支援: "01 Jan 26 12:00:00 +08:00"（2 位數年份，時區含冒號）

    // 移除選擇性的星期前綴
    var cleanedDate = dateStr.trim();
    if (cleanedDate.contains(',')) {
      cleanedDate = cleanedDate.substring(cleanedDate.indexOf(',') + 1).trim();
    }

    final parts = cleanedDate.split(RegExp(r'\s+'));
    if (parts.length < 4) {
      throw const FormatException('Invalid RFC 822 date: insufficient parts');
    }

    // 解析日（1-31）
    final day = int.tryParse(parts[0]);
    if (day == null || day < 1 || day > 31) {
      throw FormatException('Invalid RFC 822 date: invalid day "${parts[0]}"');
    }

    // 解析月（不區分大小寫）
    final monthStr = parts[1].toLowerCase();
    final month = _months[monthStr];
    if (month == null) {
      throw FormatException(
        'Invalid RFC 822 date: invalid month "${parts[1]}"',
      );
    }

    // 解析年（處理 2 位數和 4 位數）
    var year = int.tryParse(parts[2]);
    if (year == null) {
      throw FormatException('Invalid RFC 822 date: invalid year "${parts[2]}"');
    }
    // 將 2 位數年份轉換為 4 位數（RFC 822 允許 2 位數年份）
    // 00-49 → 2000-2049，50-99 → 1950-1999
    if (year < 100) {
      year = year < 50 ? 2000 + year : 1900 + year;
    }

    var hour = 0;
    var minute = 0;
    var second = 0;
    var tzOffsetMinutes = 0;

    if (parts.length >= 4 && parts[3].contains(':')) {
      final timeParts = parts[3].split(':');
      hour = _clamp(int.tryParse(timeParts[0]) ?? 0, 0, 23);
      minute = _clamp(
        int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
        0,
        59,
      );
      second = _clamp(
        int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0,
        0,
        59,
      );

      // 解析時區（如有）
      if (parts.length >= 5) {
        tzOffsetMinutes = _parseTimezone(parts[4]);
      }
    }

    // 驗證特定月份的日期
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final validDay = day <= daysInMonth ? day : daysInMonth;

    // 建立 UTC 日期時間並調整時區
    final utc = DateTime.utc(year, month, validDay, hour, minute, second);
    return utc.subtract(Duration(minutes: tzOffsetMinutes));
  }

  /// 將時區字串解析為分鐘偏移量
  ///
  /// 支援: +0800, -0500, +08:00, -05:00, GMT, EST, PST 等
  int _parseTimezone(String tz) {
    if (tz.startsWith('+') || tz.startsWith('-')) {
      final sign = tz.startsWith('+') ? 1 : -1;
      var tzValue = tz.substring(1);

      // 處理含冒號格式（+08:00 → 0800）
      if (tzValue.contains(':')) {
        tzValue = tzValue.replaceAll(':', '');
      }

      if (tzValue.length >= 4) {
        final tzHours = int.tryParse(tzValue.substring(0, 2)) ?? 0;
        final tzMins = int.tryParse(tzValue.substring(2, 4)) ?? 0;
        return sign * (tzHours * 60 + tzMins);
      } else if (tzValue.length >= 2) {
        // 處理短格式如 +08（僅小時）
        final tzHours = int.tryParse(tzValue.substring(0, 2)) ?? 0;
        return sign * tzHours * 60;
      }
    } else if (_timezoneOffsets.containsKey(tz.toUpperCase())) {
      // 具名時區如 GMT、EST、PST
      return _timezoneOffsets[tz.toUpperCase()]! * 60;
    }
    return 0;
  }

  /// 將值限制在範圍內
  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// 使用更好的雜湊演算法產生唯一 ID
  ///
  /// 使用 FNV-1a 雜湊搭配來源資訊以減少碰撞
  String _generateId(String input, {String? source}) {
    // FNV-1a 雜湊參數
    const fnvPrime = 0x01000193;
    const fnvOffset = 0x811c9dc5;

    // 結合來源與輸入以提升唯一性
    final combined = source != null ? '$source:$input' : input;
    final bytes = utf8.encode(combined);

    var hash = fnvOffset;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    // 回傳補零的十六進位字串以維持一致長度
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// RSS 新聞項目
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

  /// 從標題擷取可能的股票代碼
  ///
  /// 回傳可能的 4 位數股票代碼列表
  List<String> extractStockCodes() {
    final regex = RegExp(r'\b(\d{4})\b');
    final matches = regex.allMatches(title);
    return matches.map((m) => m.group(1)!).toList();
  }
}

/// 多個 RSS feeds 的解析結果
class RssParseResult {
  const RssParseResult({required this.items, required this.errors});

  final List<RssNewsItem> items;
  final List<RssFeedError> errors;

  /// 是否有任何 feed 解析失敗
  bool get hasErrors => errors.isNotEmpty;

  /// 成功解析的項目數
  int get successCount => items.length;

  /// 失敗的 feed 數
  int get errorCount => errors.length;
}

/// RSS feed 解析失敗的錯誤詳情
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

/// RSS feed 來源設定
class RssFeedSource {
  const RssFeedSource({
    required this.name,
    required this.url,
    required this.category,
  });

  final String name;
  final String url;
  final String category; // 對應 NewsCategory

  /// 預設的台灣財經新聞來源
  static const List<RssFeedSource> defaultSources = [
    // MoneyDJ 理財網
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
    // cnYES 鉅亨網 - 台股新聞
    RssFeedSource(
      name: '鉅亨網',
      url: 'https://news.cnyes.com/rss/v1/news/category/tw_stock',
      category: 'OTHER',
    ),
    // 中央社 CNA - 財經新聞
    RssFeedSource(
      name: '中央社',
      url: 'https://feeds.feedburner.com/rsscna/finance',
      category: 'OTHER',
    ),
  ];
}
