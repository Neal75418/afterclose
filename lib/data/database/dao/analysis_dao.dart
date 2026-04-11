import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/analysis_tables.drift.dart';

/// 每日分析、原因、推薦操作
mixin AnalysisDaoMixin on $AppDatabase {
  /// 取得指定日期的分析結果
  ///
  /// Stage 5b dual-horizon: 排序依據 `scoreShort`（Stage 5b UI 預設顯示
  /// 短線）。Stage 5c 會把預設 horizon 抽為 parameter 讓 UI 可切換。
  Future<List<DailyAnalysisEntry>> getAnalysisForDate(DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.desc(t.scoreShort)]))
        .get();
  }

  /// 取得股票的分析結果
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
  }

  /// 新增分析結果
  Future<void> insertAnalysis(DailyAnalysisCompanion entry) {
    return into(dailyAnalysis).insertOnConflictUpdate(entry);
  }

  /// 批次取得多檔股票在指定日期的分析結果（批次查詢）
  ///
  /// 回傳 symbol -> 分析結果 的 Map
  Future<Map<String, DailyAnalysisEntry>> getAnalysesBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyAnalysis)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date)))
            .get();

    return {for (final analysis in results) analysis.symbol: analysis};
  }

  /// 清除指定日期的所有分析記錄
  ///
  /// 在每日更新前呼叫，確保不會有舊的分析記錄殘留
  Future<int> clearAnalysisForDate(DateTime date) {
    return (delete(dailyAnalysis)..where((t) => t.date.equals(date))).go();
  }

  // ==================================================
  // 每日原因操作
  // ==================================================

  /// 取得股票在指定日期的觸發原因
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return (select(dailyReason)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// 批次取得多檔股票在指定日期的觸發原因（批次查詢）
  ///
  /// 回傳 symbol -> 原因列表 的 Map，依 rank 排序
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyReason)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date))
              ..orderBy([
                (t) => OrderingTerm.asc(t.symbol),
                (t) => OrderingTerm.asc(t.rank),
              ]))
            .get();

    // 依 symbol 分組
    final grouped = <String, List<DailyReasonEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 新增原因
  Future<void> insertReasons(List<DailyReasonCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyReason, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取代股票在指定日期的原因（原子性操作）
  Future<void> replaceReasons(
    String symbol,
    DateTime date,
    List<DailyReasonCompanion> entries,
  ) {
    return transaction(() async {
      // 刪除此 symbol/date 的既有原因
      await (delete(dailyReason)
            ..where((t) => t.symbol.equals(symbol))
            ..where((t) => t.date.equals(date)))
          .go();

      // 新增新的原因
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyReason, entry);
          }
        });
      }
    });
  }

  /// 清除指定日期的所有原因記錄
  ///
  /// 在每日更新前呼叫，確保不會有舊的原因記錄殘留
  Future<int> clearReasonsForDate(DateTime date) {
    return (delete(dailyReason)..where((t) => t.date.equals(date))).go();
  }

  // ==================================================
  // 推薦股操作
  // ==================================================

  /// 取得指定日期與 horizon 的推薦股
  ///
  /// Stage 5b dual-horizon: [horizon] 參數必填，查詢對應 pivot row。
  Future<List<DailyRecommendationEntry>> getRecommendations(
    DateTime date, {
    required Horizon horizon,
  }) {
    return (select(dailyRecommendation)
          ..where((t) => t.date.equals(date) & t.horizon.equals(horizon.name))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// 新增推薦股
  ///
  /// 呼叫端需在 `DailyRecommendationCompanion` 中指定 `horizon` 欄位
  /// （Stage 5b 之後為必填）。
  Future<void> insertRecommendations(
    List<DailyRecommendationCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyRecommendation, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取代指定日期、指定 horizon 的推薦股（原子性操作）
  ///
  /// Stage 5b dual-horizon: 只刪除並取代同一個 horizon 的 rows，
  /// 另一個 horizon 的資料不受影響。
  Future<void> replaceRecommendations(
    DateTime date,
    Horizon horizon,
    List<DailyRecommendationCompanion> entries,
  ) {
    return transaction(() async {
      // 刪除此日期、此 horizon 的既有推薦股
      await (delete(
            dailyRecommendation,
          )..where((t) => t.date.equals(date) & t.horizon.equals(horizon.name)))
          .go();

      // 新增新的推薦股
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyRecommendation, entry);
          }
        });
      }
    });
  }

  /// 檢查股票是否在日期範圍內曾被推薦（單次查詢）
  Future<bool> wasSymbolRecommendedInRange(
    String symbol, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result =
        await (select(dailyRecommendation)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// 取得日期範圍內所有曾被推薦的股票代碼（批次檢查）
  Future<Set<String>> getRecommendedSymbolsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results =
        await (select(dailyRecommendation)
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
            .get();
    return results.map((r) => r.symbol).toSet();
  }
}
