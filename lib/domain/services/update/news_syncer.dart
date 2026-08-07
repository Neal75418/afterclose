import 'package:daredevil/core/constants/data_freshness.dart';
import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/core/utils/logger.dart';
import 'package:daredevil/data/repositories/news_repository.dart';

/// 新聞資料同步器
///
/// 負責同步 RSS 新聞並清理過期新聞
class NewsSyncer {
  const NewsSyncer({required NewsRepository newsRepository})
    : _newsRepo = newsRepository;

  final NewsRepository _newsRepo;

  /// 同步 RSS 新聞
  ///
  /// 回傳 [NewsSyncResult] 包含同步詳情
  Future<NewsSyncResult> syncNews() async {
    final errors = <String>[];
    var itemsAdded = 0;

    // RateLimit/Network 必須 rethrow(CLAUDE.md 慣例;2026-08-01 補)——
    // 修前這裡是十個 syncer 中唯一的裸 catch:RateLimitException 被降級
    // 成 errors 字串,UpdateService 的 rateLimitedAbort 熔斷對新聞路徑
    // 完全失效(限流時下游照打)。fail-soft 只留給非限流/非網路的錯誤。
    try {
      final result = await _newsRepo.syncNews();
      itemsAdded = result.itemsAdded;

      if (result.hasErrors) {
        for (final error in result.errors) {
          errors.add('RSS 錯誤: $error');
        }
      }
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      errors.add('新聞同步失敗: $e');
      AppLogger.warning('NewsSyncer', '新聞同步失敗', e);
    }

    // 重大訊息公告（一手訊號）fail-soft：失敗不影響 RSS 結果
    try {
      final added = await _newsRepo.syncMaterialInfo();
      itemsAdded += added;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      errors.add('重大訊息同步失敗: $e');
      AppLogger.warning('NewsSyncer', '重大訊息同步失敗', e);
    }

    return NewsSyncResult(itemsAdded: itemsAdded, errors: errors);
  }

  /// 清理過期新聞
  ///
  /// [olderThanDays] 指定保留天數，預設 30 天
  Future<int> cleanupOldNews({
    int olderThanDays = DataFreshness.newsRetentionDays,
  }) async {
    try {
      final deletedCount = await _newsRepo.cleanupOldNews(
        olderThanDays: olderThanDays,
      );

      if (deletedCount > 0) {
        AppLogger.info('NewsSyncer', '已清理 $deletedCount 則過期新聞');
      }

      return deletedCount;
    } catch (e) {
      AppLogger.warning('NewsSyncer', '清理過期新聞失敗', e);
      return 0;
    }
  }

  /// 同步新聞並清理過期資料
  ///
  /// 整合同步和清理操作
  Future<NewsSyncResult> syncAndCleanup({
    int olderThanDays = DataFreshness.newsRetentionDays,
  }) async {
    final syncResult = await syncNews();
    final deletedCount = await cleanupOldNews(olderThanDays: olderThanDays);

    return NewsSyncResult(
      itemsAdded: syncResult.itemsAdded,
      errors: syncResult.errors,
      deletedCount: deletedCount,
    );
  }
}

/// 新聞同步結果
class NewsSyncResult {
  const NewsSyncResult({
    required this.itemsAdded,
    this.errors = const [],
    this.deletedCount = 0,
  });

  final int itemsAdded;
  final List<String> errors;
  final int deletedCount;

  bool get hasErrors => errors.isNotEmpty;
}
