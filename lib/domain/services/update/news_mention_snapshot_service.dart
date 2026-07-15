import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';
import 'package:afterclose/domain/services/news/theme_matcher.dart';

/// 每日提及數快照（新聞熱度發現層）
///
/// 每次回補最近 [NewsHeatParams.snapshotBackfillDays] 個本地日
/// （重算後 upsert，晚到新聞自我修正、天然冪等）。
/// 由 UpdateService 於更新尾端 fail-safe 呼叫；顯示層不依賴此表。
class NewsMentionSnapshotService {
  NewsMentionSnapshotService({
    required AppDatabase database,
    required INewsRepository newsRepository,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _newsRepo = newsRepository,
       _clock = clock;

  final AppDatabase _db;
  final INewsRepository _newsRepo;
  final AppClock _clock;

  Future<void> snapshotRecentDays() async {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    const backfillDays = NewsHeatParams.snapshotBackfillDays;

    // +1 天緩衝涵蓋時區邊界
    final news = await _newsRepo.getRecentNews(days: backfillDays + 1);
    if (news.isEmpty) return;

    final stocks = await _db.getAllActiveStocks();
    final nameMatcher = StockNameMatcher.fromStocks(stocks);
    final themeMatcher = ThemeMatcher();

    // (localDay, kind, key) → count
    final counts = <(DateTime, String, String), int>{};
    for (final n in news) {
      final local = n.publishedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff >= backfillDays) continue;

      for (final sym in nameMatcher.match(n.title)) {
        final k = (day, 'stock', sym);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final theme in themeMatcher.match(n.title)) {
        final k = (day, 'theme', theme);
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return;

    await _db.upsertMentionCounts([
      for (final e in counts.entries)
        NewsMentionDailyCompanion.insert(
          date: e.key.$1,
          kind: e.key.$2,
          itemKey: e.key.$3,
          mentionCount: e.value,
          dictionaryVersion: NewsHeatParams.dictionaryVersion,
        ),
    ]);
  }
}
