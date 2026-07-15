import 'package:afterclose/core/constants/api_endpoints.dart';

/// 新聞 feed 來源設定
///
/// 領域層的純值物件 — 不耦合 RSS / XML 等實作細節，僅描述「一個可同步的
/// 新聞來源」。資料層的 parser 可直接接受此型別。
class NewsFeedSource {
  const NewsFeedSource({
    required this.name,
    required this.url,
    required this.category,
  });

  final String name;
  final String url;

  /// 對應 NewsCategory 字串
  final String category;

  /// 預設的台灣財經新聞來源
  static const List<NewsFeedSource> defaultSources = [
    // Yahoo Taiwan Finance
    NewsFeedSource(
      name: 'Yahoo財經',
      url: ApiEndpoints.rssYahooFinance,
      category: 'OTHER',
    ),
    // cnYES 鉅亨網
    NewsFeedSource(name: '鉅亨網', url: ApiEndpoints.rssCnyes, category: 'OTHER'),
    // 中央社 CNA
    NewsFeedSource(name: '中央社', url: ApiEndpoints.rssCna, category: 'OTHER'),
    // 經濟日報（證券版）
    NewsFeedSource(
      name: '經濟日報',
      url: ApiEndpoints.rssUdnMoney,
      category: 'OTHER',
    ),
    // 自由時報財經
    NewsFeedSource(
      name: '自由財經',
      url: ApiEndpoints.rssLtnBusiness,
      category: 'OTHER',
    ),
  ];
}

/// 新聞 feed 同步失敗的錯誤詳情
class NewsFeedError {
  const NewsFeedError({
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
