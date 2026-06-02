import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/news_feed.dart';

/// 新聞資料儲存庫介面
///
/// 提供新聞 feed 的同步、查詢與清理功能。
/// 支援測試時的 Mock 及不同實作。
abstract class INewsRepository {
  /// 同步新聞 feed
  Future<NewsSyncResult> syncNews({List<NewsFeedSource>? sources});

  /// 取得近期新聞
  Future<List<NewsItemEntry>> getRecentNews({
    int days = 3,
    int? limit,
    int offset = 0,
  });

  /// 批次取得多檔股票的新聞
  Future<Map<String, List<NewsItemEntry>>> getNewsForStocksBatch(
    List<String> symbols, {
    int days = 3,
  });

  /// 清除過期新聞
  Future<int> cleanupOldNews({
    int olderThanDays = DataFreshness.newsRetentionDays,
  });
}

/// 新聞同步結果
class NewsSyncResult {
  const NewsSyncResult({required this.itemsAdded, required this.errors});

  final int itemsAdded;
  final List<NewsFeedError> errors;

  /// 是否有 Feed 解析失敗
  bool get hasErrors => errors.isNotEmpty;
}
