import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/analysis_dao.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// Mode-based 推薦項目（每檔包含 5D 跟 60D 雙 score）
///
/// 跟 [RecommendationWithDetails] 的差別：
/// - 雙 score（modeScoreShort / modeScoreLong）vs 單 score
/// - reasons 已 filter 到該 mode 內的 rule
/// - score 是該 mode 內 rule 加總（不是全 rule 加總、不是 daily_recommendation 的 stored score）
class ModeRecommendation {
  ModeRecommendation({
    required this.symbol,
    required this.rank,
    required this.modeScoreShort,
    required this.modeScoreLong,
    required this.reasons,
    this.stockName,
    this.market,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.recentPrices,
  });

  final String symbol;

  /// 該 mode 內排名（1-based、按 sort key abs DESC 排）
  final int rank;

  /// 該 mode 內所有觸發 rule 的 ruleScoreShort 加總
  final double modeScoreShort;

  /// 該 mode 內所有觸發 rule 的 ruleScoreLong 加總
  final double modeScoreLong;

  final String? stockName;
  final String? market;
  final double? latestClose;
  final double? priceChange;

  /// **該 mode 內**的觸發理由（已過濾掉其他 mode 跟 neutral 的 rule）
  final List<DailyReasonEntry> reasons;

  final String? trendState;
  final List<double>? recentPrices;

  /// reason type 字串 list — 預先計算給 UI evidence chip 用
  late final List<String> reasonTypes = reasons
      .map((r) => r.reasonType)
      .toList();
}

/// 把 [ScoringMode] mapping 到該 mode 內所有 [ReasonType] 的 DB code
///
/// extracted 為 helper 讓 test / DAO 都能 reuse、避免 mode 分類散落各處。
List<String> reasonCodesForMode(ScoringMode mode) {
  return ReasonType.values
      .where((rt) => rt.scoringMode == mode)
      .map((rt) => rt.code)
      .toList();
}

/// **2026-06-19 audit Action 5 + C-1 重構**
///
/// 從「per-mode 獨立查詢」改成「all-mode 預先計算 + 獨佔分派 + anti-filter」。
///
/// ## 為什麼換架構
///
/// 原版每次 tab 切換各自 query DB、各 mode 沒有共識：
/// - 同一檔股票（如 6742 澤米）會同時出現在 3 個 tab（A +57 / B +62 / C -25）
/// - User 觀感「這檔到底該歸哪邊？」、tab 區分模糊
/// - 已大漲股 / 漲停股出現在「起漲」/「弱勢」tab 違反 mental model
///
/// 新版：
/// - **C-1 mode 獨佔**：每檔股票指派到 |score| 最大的 mode、只在該 tab 顯示
/// - **B anti-filter**：Mode A 5D > +8% 踢出（強訊號例外）/ Mode C 今日 > +5% 踢出
/// - 拉一次資料、3 個 tab 共用、tab 切換瞬間 cached
///
/// ## 結構
///
/// 內部 [_modeAssignmentsProvider] 拉完整 `Map<ScoringMode, List<ModeRecommendation>>`、
/// 外部 [modeRecommendationsProvider] 是薄 slice — 既有 test override 模式不動。
final _modeAssignmentsProvider =
    FutureProvider<Map<ScoringMode, List<ModeRecommendation>>>((ref) async {
      // Auto-reload trigger
      ref.watch(dataUpdateEpochProvider);

      final repo = ref.read(analysisRepositoryProvider);
      final cachedDb = ref.read(cachedDbProvider);
      final marketRepo = ref.read(marketDataRepositoryProvider);

      final emptyResult = <ScoringMode, List<ModeRecommendation>>{
        for (final m in ScoringMode.userFacingModes) m: const [],
      };

      // 1. 找最新 daily_reason 的日期
      final latestPriceDate = await marketRepo.getLatestDataDate();
      if (latestPriceDate == null) return emptyResult;
      final analysisDate = DateContext.normalize(latestPriceDate);

      // 2. 平行查 3 個 mode 的 SUM aggregate
      final modeScoresEntries = await Future.wait(
        ScoringMode.userFacingModes.map((m) async {
          final codes = reasonCodesForMode(m);
          if (codes.isEmpty) {
            AppLogger.warning('ModeRecommendations', 'mode ${m.name} 沒任何 rule');
            return MapEntry(m, const <ModeStockScore>[]);
          }
          final scores = await repo.getModeStockScores(analysisDate, codes);
          return MapEntry(m, scores);
        }),
      );

      // 3. Build symbol → {mode → ModeStockScore} 矩陣
      final stockModeScores = <String, Map<ScoringMode, ModeStockScore>>{};
      for (final entry in modeScoresEntries) {
        for (final s in entry.value) {
          stockModeScores.putIfAbsent(s.symbol, () => {})[entry.key] = s;
        }
      }

      // 4. C-1 mode 獨佔分派：每檔股票指派給 |scoreShort| 最大的 mode
      final assignmentMap = <ScoringMode, List<ModeStockScore>>{
        for (final m in ScoringMode.userFacingModes) m: [],
      };
      for (final entry in stockModeScores.entries) {
        final modes = entry.value;
        ScoringMode? bestMode;
        double bestAbs = -1;
        for (final mEntry in modes.entries) {
          final absScore = mEntry.value.modeScoreShort.abs();
          if (absScore > bestAbs) {
            bestAbs = absScore;
            bestMode = mEntry.key;
          }
        }
        if (bestMode != null) {
          assignmentMap[bestMode]!.add(modes[bestMode]!);
        }
      }

      // 5. Mode-aware sort（Mode C ASC 最負優先、其他 DESC 最正優先）
      //    取 top 50 buffer（為了 anti-filter 後仍 ≥ 30 顯示）
      for (final mode in assignmentMap.keys) {
        assignmentMap[mode]!.sort((a, b) {
          return mode == ScoringMode.weaknessObserve
              ? a.modeScoreShort.compareTo(b.modeScoreShort)
              : b.modeScoreShort.compareTo(a.modeScoreShort);
        });
        if (assignmentMap[mode]!.length > 50) {
          assignmentMap[mode] = assignmentMap[mode]!.take(50).toList();
        }
      }

      // 6. Bulk load stock data — all assigned symbols 一次撈
      final allSymbols = assignmentMap.values
          .expand((l) => l.map((s) => s.symbol))
          .toSet()
          .toList();
      if (allSymbols.isEmpty) return emptyResult;

      final historyCtx = DateContext.forDate(analysisDate);
      final data = await cachedDb.loadStockListData(
        symbols: allSymbols,
        analysisDate: analysisDate,
        historyStart: historyCtx.historyStart,
      );
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        data.priceHistories,
        data.latestPrices,
      );

      // 7. B anti-filter + 組 ModeRecommendation
      final result = <ScoringMode, List<ModeRecommendation>>{};
      for (final mode in ScoringMode.userFacingModes) {
        final codeSet = reasonCodesForMode(mode).toSet();
        final filtered = <ModeRecommendation>[];

        for (final s in assignmentMap[mode]!) {
          final symbol = s.symbol;
          final priceChange = priceChanges[symbol];
          final priceHistory = data.priceHistories[symbol];

          // 5D return（Mode A 用）— 從 priceHistory 算（已 load 給 sparkline）
          double? ret5d;
          if (priceHistory != null && priceHistory.length >= 6) {
            final latest = priceHistory.last.close;
            final old = priceHistory[priceHistory.length - 6].close;
            if (latest != null && old != null && old != 0) {
              ret5d = (latest - old) / old * 100;
            }
          }

          // Anti-filter
          if (mode == ScoringMode.momentumEntry) {
            // Mode A: 5D > +8% 踢出 UNLESS score ≥ 50（強訊號豁免）
            if (ret5d != null &&
                ret5d > ModeFilters.modeAExclude5dPct &&
                s.modeScoreShort < ModeFilters.modeAStrongScoreOverride) {
              continue;
            }
          } else if (mode == ScoringMode.weaknessObserve) {
            // Mode C: 今日 > +5% 踢出（漲停絕不在弱勢）
            if (priceChange != null &&
                priceChange > ModeFilters.modeCExcludeTodayPct) {
              continue;
            }
          }

          // mode-filtered reasons（其他 mode + neutral 的 chip 不顯示）
          final allReasons = data.reasons[symbol] ?? [];
          final modeReasons = allReasons
              .where((r) => codeSet.contains(r.reasonType))
              .toList();

          // 最近 30 日收盤價（迷你走勢圖）
          List<double>? recentPrices;
          if (priceHistory != null && priceHistory.isNotEmpty) {
            final startIdx = priceHistory.length > 30
                ? priceHistory.length - 30
                : 0;
            recentPrices = priceHistory
                .sublist(startIdx)
                .map((p) => p.close)
                .whereType<double>()
                .toList();
          }

          filtered.add(
            ModeRecommendation(
              symbol: symbol,
              rank: filtered.length + 1,
              modeScoreShort: s.modeScoreShort,
              modeScoreLong: s.modeScoreLong,
              reasons: modeReasons,
              stockName: data.stocks[symbol]?.name,
              market: data.stocks[symbol]?.market,
              latestClose: data.latestPrices[symbol]?.close,
              priceChange: priceChange,
              trendState: data.analyses[symbol]?.trendState,
              recentPrices: recentPrices,
            ),
          );

          if (filtered.length >= 30) break;
        }

        result[mode] = filtered;
      }

      return result;
    });

/// 該 mode 的 Top N 推薦（real-time aggregate from daily_reason）
///
/// 跟 [todayProvider] 的 horizon-based 推薦清單共存、互不影響。
/// 用 FutureProvider.family 當薄 slice：實際運算在 [_modeAssignmentsProvider]
/// 內、跨 mode 共用一次 DB query + assignment + filter。
///
/// **Auto-reload**：透過內部 provider watch [dataUpdateEpochProvider]、每次
/// update 完成自動 invalidate 重查。mode 切換時瞬間從 cached map 抽 slice。
final modeRecommendationsProvider =
    FutureProvider.family<List<ModeRecommendation>, ScoringMode>((
      ref,
      mode,
    ) async {
      final all = await ref.watch(_modeAssignmentsProvider.future);
      return all[mode] ?? const [];
    });
