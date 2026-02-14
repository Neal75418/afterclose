import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/rss_parser.dart';

/// 新聞資料儲存庫介面
///
/// 提供 RSS 新聞的同步、查詢與清理功能。
/// 支援測試時的 Mock 及不同實作。
abstract class INewsRepository {
  /// 同步 RSS 新聞
  Future<NewsSyncResult> syncNews({List<RssFeedSource>? sources});

  /// 取得近期新聞
  Future<List<NewsItemEntry>> getRecentNews({
    int days = 3,
    int? limit,
    int offset = 0,
  });

  /// 取得股票相關新聞
  Future<List<NewsItemEntry>> getNewsForStock(
    String symbol, {
    int days = 3,
    int? limit,
    int offset = 0,
  });

  /// 批次取得多檔股票的新聞
  Future<Map<String, List<NewsItemEntry>>> getNewsForStocksBatch(
    List<String> symbols, {
    int days = 3,
  });

  /// 檢查股票是否有近期新聞
  Future<bool> hasRecentNews(String symbol, {int days = 2});

  /// 依 ID 取得新聞
  Future<NewsItemEntry?> getNewsById(String id);

  /// 清除過期新聞
  Future<int> cleanupOldNews({int olderThanDays = 30});
}

/// 新聞同步結果
class NewsSyncResult {
  const NewsSyncResult({required this.itemsAdded, required this.errors});

  final int itemsAdded;
  final List<RssFeedError> errors;

  /// 是否有 Feed 解析失敗
  bool get hasErrors => errors.isNotEmpty;

  /// 是否完全成功（無錯誤）
  bool get isFullySuccessful => errors.isEmpty;
}
