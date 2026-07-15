import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';
import 'package:afterclose/domain/services/news/theme_matcher.dart';

/// 每日提及數快照（新聞熱度發現層）
///
/// 每次回補最近 [NewsHeatParams.snapshotBackfillDays] 個本地日：**窗內全量
/// 覆寫**（先刪 [from, to] 全部快照列、再寫入重算結果），而非單純 upsert。
/// 這讓「晚到新聞」與「已消失的 key」都能自我修正——upsert-only 只覆蓋重算
/// 後仍 count > 0 的列，字典異動或個股下市等原因造成某 key 重算為 0 時，
/// 舊的非零殘留列不會被觸及；全量覆寫則先清空整個窗再寫入，殘留列必然歸零。
///
/// 例外：若當次讀到的新聞 feed 為空（[INewsRepository.getRecentNews] 回傳
/// 空陣列），視為讀取失敗的保守訊號，直接 early return、**不清空窗內既有
/// 資料**——避免把「暫時讀不到新聞」誤判成「這個窗內都沒有提及」而抹掉
/// 昨天已經算好的快照。
///
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
    // 空 feed = 保守視為讀取失敗，直接放棄本次快照、不清空窗內既有資料
    // （見 class docstring）。這是唯一提早 return 且不觸及 DB 的分支。
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

    // news 非空但 counts 為空（例如窗內新聞都無匹配）仍要往下走：對窗做
    // 全量覆寫是合法結果（窗內合理歸零），不能提早 return 略過覆寫。
    final windowFrom = today.subtract(const Duration(days: backfillDays - 1));
    await _db.replaceMentionCountsInWindow(
      from: windowFrom,
      to: today,
      rows: [
        for (final e in counts.entries)
          NewsMentionDailyCompanion.insert(
            date: e.key.$1,
            kind: e.key.$2,
            itemKey: e.key.$3,
            mentionCount: e.value,
            dictionaryVersion: NewsHeatParams.dictionaryVersion,
          ),
      ],
    );
  }
}
