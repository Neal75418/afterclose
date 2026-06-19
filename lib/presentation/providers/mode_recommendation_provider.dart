import 'package:flutter/foundation.dart' show visibleForTesting;
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

/// 從 priceHistory 算 5 trading days 報酬 (%)。
///
/// 回 null 當：history 太短（< 6 個收盤）/ 端點 close null / 起點 close 0。
/// caller 把 null 視為「不知道、不擋」(permissive)，避免靜默 drop 新 IPO /
/// sparse history。
@visibleForTesting
double? computeRet5dForHistory(List<DailyPriceEntry>? history) {
  if (history == null || history.length < 6) return null;
  final latest = history.last.close;
  final old = history[history.length - 6].close;
  if (latest == null || old == null || old == 0) return null;
  return (latest - old) / old * 100;
}

/// 判斷某檔股票是否「夠資格」指派到 [mode]。
///
/// **2026-06-19 audit Action 5b — eligibility-first 指派**
///
/// 從「先指派再 drop」改成「指派前先 filter」。治掉 6651 全宇昕 case：
/// today +9.12%、A=42 / B=28 / C=0：
/// - 舊：max |score| 選中 A → anti-filter drop（today > 8%）→ 三 tab 都消失
/// - 新：A 不合格、B 合格、C 不合格 → 落到 B ✅
///
/// `todayPct` / `ret5d` 為 null 代表 price data 缺失（新 IPO / sparse history /
/// data race）：採「不知道就不擋」semantics、避免靜默 drop。
@visibleForTesting
bool isEligibleForMode({
  required ScoringMode mode,
  required ModeStockScore score,
  required double? todayPct,
  required double? ret5d,
  Set<String> triggeredReasonCodes = const {},
}) {
  switch (mode) {
    case ScoringMode.momentumEntry:
      // 當日 > +8% 一律踢出（**無強訊號豁免**、會自動導去 Mode B）
      if (todayPct != null && todayPct > ModeFilters.modeAExcludeTodayPct) {
        return false;
      }
      // 5D > +8% 踢出 UNLESS score ≥ 50（強訊號豁免、僅作用 5D）
      if (ret5d != null &&
          ret5d > ModeFilters.modeAExclude5dPct &&
          score.modeScoreShort < ModeFilters.modeAStrongScoreOverride) {
        return false;
      }
      return true;

    case ScoringMode.strengthObserve:
      // 強勢觀察需要正分證據；score ≤ 0 不指派（避免 SUM-cancel 0 row 或
      // 罕見負分 B-rule 污染 DESC 排序）
      if (score.modeScoreShort <= 0) return false;
      // **2026-06-19 v2 audit**：今日下跌讓 Mode C 處理（B/C 排他）
      if (todayPct != null && todayPct <= ModeFilters.modeCMaxTodayPct) {
        return false;
      }
      return true;

    case ScoringMode.weaknessObserve:
      // **2026-06-19 v2 audit — 回檔觀察重定義**：強股剛開始回檔、找進場時機
      //
      // (1) 今日須回檔但非崩跌（0 ≥ todayPct ≥ -4%）
      if (todayPct != null) {
        if (todayPct > ModeFilters.modeCMaxTodayPct) return false;
        if (todayPct < ModeFilters.modeCMinTodayPct) return false;
      }
      // (2) **必過 gate**：至少 1 條主訊號 rule fire
      //     避免「純警示無進場點」雜訊（舊 Mode C 主問題）
      final hasMainSignal = ModeFilters.modeCRequiredAnyOf.any(
        triggeredReasonCodes.contains,
      );
      if (!hasMainSignal) return false;
      // (3) Mode score ≥ +12（v2 從負分改正分機會 tab、+12 是最弱主訊號）
      return score.modeScoreShort >= ModeFilters.modeCMinScore;

    case ScoringMode.neutral:
      return false;
  }
}

/// **2026-06-19 audit Action 5b — eligibility-first 指派**
///
/// 從「max |score| 指派 → 後 anti-filter drop」改成「**filter-aware
/// assignment**」：每檔股票只在「合格 mode」之間選 max |scoreShort|，0 個
/// 合格 OR 合格但 |score| < [ModeFilters.minRoutedAbsScore] floor 則整檔
/// drop。
///
/// ## 為什麼換架構
///
/// 5a 版本「先指派、後 drop」會把「主要 mode 過 filter / 次要 mode 仍有
/// 訊號」的股票完全弄丟。例：6651 全宇昕 today +9.12%, A=42 / B=28 / C=0：
/// - 5a：max |score| 選 A → Mode A filter today > 8% → drop → 3 tab 都消失 ❌
/// - 5b：A 不合格、B 合格、C 不合格 → 落 B ✅
///
/// 同時治掉漲停股出現在 Mode C 弱勢 tab（5% threshold 太鬆）— 收緊到 0%、
/// 透過 eligibility 自動把「有警示但今天漲」的股票導去 B（強勢觀察）。
///
/// ## 結構
///
/// 內部 [_modeAssignmentsProvider] 一次拉完整
/// `Map<ScoringMode, List<ModeRecommendation>>`、外部 [modeRecommendationsProvider]
/// 是薄 slice — 既有 test override 模式不動。
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

      // STEP 1 — 找最新 data date
      final latestPriceDate = await marketRepo.getLatestDataDate();
      if (latestPriceDate == null) return emptyResult;
      final analysisDate = DateContext.normalize(latestPriceDate);

      // STEP 2 — 平行查 3 個 mode 的 SUM aggregate
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

      // STEP 3 — Build symbol → {mode → ModeStockScore} 矩陣
      final stockModeScores = <String, Map<ScoringMode, ModeStockScore>>{};
      for (final entry in modeScoresEntries) {
        for (final s in entry.value) {
          stockModeScores.putIfAbsent(s.symbol, () => {})[entry.key] = s;
        }
      }
      if (stockModeScores.isEmpty) return emptyResult;

      // STEP 4 — 一次撈所有 candidate 的 stock data（priceHistory 給 ret5d /
      //          sparkline 重用；reasons / stocks / analyses 給後續 build）
      final allCandidateSymbols = stockModeScores.keys.toList();
      final historyCtx = DateContext.forDate(analysisDate);
      final data = await cachedDb.loadStockListData(
        symbols: allCandidateSymbols,
        analysisDate: analysisDate,
        historyStart: historyCtx.historyStart,
      );
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        data.priceHistories,
        data.latestPrices,
      );

      // STEP 5 — eligibility-first 指派 + floor + routing priority
      //
      // **2026-06-19 v2 audit**：multi-mode eligible 時，先按 ScoringMode.routingPriority
      // 高者勝（pullbackEntry 3 > momentumEntry 2 > strengthObserve 1）、tiebreak
      // 用 max |scoreShort|。Mode C 是「進場時機」最 actionable、應優先 surface。
      final assignmentMap = <ScoringMode, List<ModeStockScore>>{
        for (final m in ScoringMode.userFacingModes) m: <ModeStockScore>[],
      };
      var droppedNoEligible = 0;
      var droppedBelowFloor = 0;
      for (final entry in stockModeScores.entries) {
        final symbol = entry.key;
        final modes = entry.value;
        final todayPct = priceChanges[symbol];
        final ret5d = computeRet5dForHistory(data.priceHistories[symbol]);

        // 取得該股 daily_reason 內所有 triggered reason codes（給 Mode C gate 用）
        final triggeredCodes = <String>{
          for (final r in data.reasons[symbol] ?? const <DailyReasonEntry>[])
            r.reasonType,
        };

        ScoringMode? bestMode;
        var bestPriority = -1;
        var bestAbs = -1.0;
        for (final mEntry in modes.entries) {
          if (!isEligibleForMode(
            mode: mEntry.key,
            score: mEntry.value,
            todayPct: todayPct,
            ret5d: ret5d,
            triggeredReasonCodes: triggeredCodes,
          )) {
            continue;
          }
          final priority = mEntry.key.routingPriority;
          final absScore = mEntry.value.modeScoreShort.abs();
          // 優先 priority 高者；同 priority 用 max |score| tiebreak
          if (priority > bestPriority ||
              (priority == bestPriority && absScore > bestAbs)) {
            bestPriority = priority;
            bestAbs = absScore;
            bestMode = mEntry.key;
          }
        }

        if (bestMode == null) {
          droppedNoEligible++;
          continue;
        }
        if (bestAbs < ModeFilters.minRoutedAbsScore) {
          droppedBelowFloor++;
          continue;
        }
        assignmentMap[bestMode]!.add(modes[bestMode]!);
      }
      AppLogger.debug(
        'ModeRecommendations',
        'candidates=${stockModeScores.length} '
            'A=${assignmentMap[ScoringMode.momentumEntry]!.length} '
            'B=${assignmentMap[ScoringMode.strengthObserve]!.length} '
            'C=${assignmentMap[ScoringMode.weaknessObserve]!.length} '
            'droppedNoEligible=$droppedNoEligible '
            'droppedBelowFloor=$droppedBelowFloor',
      );

      // STEP 6 — Sort all modes DESC by score + symbol tiebreaker
      //
      // **2026-06-19 v2 audit**：Mode C 從 ASC（最負優先）改 DESC（最正優先）— 因為
      // v2 Mode C 是「機會 tab」（正分主訊號 + 負分 warning context），主訊號
      // (+15/+18) 應排在最前面。
      for (final mode in assignmentMap.keys) {
        assignmentMap[mode]!.sort((a, b) {
          final primary = b.modeScoreShort.compareTo(a.modeScoreShort); // DESC
          if (primary != 0) return primary;
          return a.symbol.compareTo(b.symbol); // 二級 key：symbol ASC
        });
      }

      // STEP 7 — 組 ModeRecommendation per mode、cap 30
      final result = <ScoringMode, List<ModeRecommendation>>{};
      for (final mode in ScoringMode.userFacingModes) {
        final codeSet = reasonCodesForMode(mode).toSet();
        final list = <ModeRecommendation>[];

        for (final s in assignmentMap[mode]!) {
          final symbol = s.symbol;
          final priceHistory = data.priceHistories[symbol];

          // mode-filtered reasons（其他 mode + neutral 的 chip 不顯示）
          final allReasons = data.reasons[symbol] ?? const [];
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

          list.add(
            ModeRecommendation(
              symbol: symbol,
              rank: list.length + 1,
              modeScoreShort: s.modeScoreShort,
              modeScoreLong: s.modeScoreLong,
              reasons: modeReasons,
              stockName: data.stocks[symbol]?.name,
              market: data.stocks[symbol]?.market,
              latestClose: data.latestPrices[symbol]?.close,
              priceChange: priceChanges[symbol],
              trendState: data.analyses[symbol]?.trendState,
              recentPrices: recentPrices,
            ),
          );

          if (list.length >= 30) break;
        }

        result[mode] = list;
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
