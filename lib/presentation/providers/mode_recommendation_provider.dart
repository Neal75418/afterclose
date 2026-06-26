import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/risk_warnings.dart';
import 'package:afterclose/core/constants/rule_params.dart';
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
/// - 雙 score（modeScoreShort / modeScoreLong）vs 單 score
/// - reasons 已 filter 到該 mode 內的 rule
/// - score 是該 mode 內 rule 加總（不是全 rule 加總）
class ModeRecommendation {
  ModeRecommendation({
    required this.symbol,
    required this.rank,
    required this.modeScoreShort,
    required this.modeScoreLong,
    required this.reasons,
    this.warningReasons = const [],
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

  /// 該股觸發的 **neutral 警訊類**訊號（[RiskWarnings.all] 子集）
  ///
  /// 與 [reasons]（mode-only evidence chip）正交：警訊不 route 股票、不貢獻 mode
  /// score、不污染 evidence chip，但要在卡片以風險徽章浮上來（補回階段重設計
  /// 拆掉的主畫面風險可見性）。空 list = 該股無警訊、徽章不顯示。
  final List<ReasonType> warningReasons;

  final String? trendState;
  final List<double>? recentPrices;

  /// reason type 字串 list — 預先計算給 UI evidence chip 用
  late final List<String> reasonTypes = reasons
      .map((r) => r.reasonType)
      .toList();

  /// 警訊中最高嚴重度（任一 severe → severe），無警訊回 `null` — 決定徽章顏色
  RiskSeverity? get topSeverity => RiskWarnings.topSeverity(warningReasons);
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

/// 從 priceHistory 算最新收盤對 MA20 的乖離率 (%)：`(close − MA20) / MA20 × 100`。
///
/// **2026-06-20 Wave 2a — analyst「延伸度」軸**：取代舊「5D/20D 漲幅 proxy」。
/// Mode A「準備起漲」應貼近 MA20（低乖離）；大幅正乖離 = 已漲一波、過度延伸、
/// 不符「還沒漲」語意（Minervini「not extended」原則）。
///
/// 回 null 當 history < 20 筆 / 任一收盤 null / MA20 為 0 → caller 視為「不知道、
/// 不擋」(permissive)，避免靜默 drop 新 IPO / sparse history。
@visibleForTesting
double? computeBiasMa20ForHistory(List<DailyPriceEntry>? history) {
  if (history == null || history.length < 20) return null;
  final latest = history.last.close;
  if (latest == null) return null;
  final last20 = history.sublist(history.length - 20);
  var sum = 0.0;
  for (final p in last20) {
    final c = p.close;
    if (c == null) return null;
    sum += c;
  }
  final ma20 = sum / 20;
  if (ma20 == 0) return null;
  return (latest - ma20) / ma20 * 100;
}

/// 從 priceHistory 算 60 trading days 報酬 (%)。
///
/// **2026-06-20 Wave 2b — Mode B 動能 / 相對強度排序鍵**：60D 報酬是 RS（相對
/// 強度）的 proxy。Mode B 內部用它排序、與「全市場 60D percentile rank」**同序**
/// （percentile 是 60D 報酬的單調函數）→ 無需算全市場 percentile。取代 score 排序
/// （實測 corr(score, 20D) ≈ +0.17、近乎無鑑別力）。
///
/// 回 null 當 history < 61 筆 / 端點 close null / 起點 0 → caller 視為「資料不足、
/// 排最後」。
@visibleForTesting
double? computeRet60dForHistory(List<DailyPriceEntry>? history) {
  if (history == null || history.length < 61) return null;
  final latest = history.last.close;
  final old = history[history.length - 61].close;
  if (latest == null || old == null || old == 0) return null;
  return (latest - old) / old * 100;
}

/// 是否為「成立訊號」層（任一 horizon ≥ [RuleParams.minScoreThreshold]）。
///
/// daily_analysis 持久化門檻已降到 observationScoreThreshold（8）以供掃描頁
/// 「觀察區」使用；mode tab 只收成立訊號（≥12），用此 predicate 還原該語意、
/// 把觀察層（8–11）擋在三個訊號 tab 之外。analysis 為 null（無評分）視為不合格。
@visibleForTesting
bool isSignalTier(DailyAnalysisEntry? analysis) =>
    analysis != null &&
    (analysis.scoreShort >= RuleParams.minScoreThreshold ||
        analysis.scoreLong >= RuleParams.minScoreThreshold);

/// 判斷某檔股票是否「夠資格」指派到 [mode]。
///
/// **2026-06-19 audit Action 5b — eligibility-first 指派**
///
/// 從「先指派再 drop」改成「指派前先 filter」。治掉 6651 全宇昕 case：
/// today +9.12%、A=42 / B=28 / C=0：
/// - 舊：max |score| 選中 A → anti-filter drop（today > 8%）→ 三 tab 都消失
/// - 新：A 不合格、B 合格、C 不合格 → 落到 B ✅
///
/// `todayPct` / `biasMa20` 為 null 代表 price data 缺失（新 IPO / sparse history /
/// data race）：採「不知道就不擋」semantics、避免靜默 drop。
@visibleForTesting
bool isEligibleForMode({
  required ScoringMode mode,
  required ModeStockScore score,
  required double? todayPct,
  double? biasMa20,
  Set<String> triggeredReasonCodes = const {},
}) {
  switch (mode) {
    case ScoringMode.momentumEntry:
      // 當日 > +8% 一律踢出（追高、自動導去 Mode B 強勢觀察）
      if (todayPct != null && todayPct > ModeFilters.modeAExcludeTodayPct) {
        return false;
      }
      // **2026-06-20 Wave 2a — 乖離率 gate 取代 5D 漲幅 proxy + 強訊號豁免**：
      // analyst 判「準備起漲 vs 已漲」看的是「離 MA20 多遠（延伸度）」而非「最近
      // 漲幅」。MA20 正乖離 > +15%（台股標準偏熱線）= 已漲一波、過度延伸 → 不符
      // 「還沒漲、即將起漲」語意，踢出（同時若它強勢、會自動導去 Mode B）。
      //
      // 取代舊「5D>8% + score≥50 豁免 + 20D≤20% 副條件」整套補丁：豁免本意是保護
      // 「強反轉但還沒漲」，但反覆漏掉「強反轉**已漲一波**」（6742 乖離+15.7%、
      // 6770 20D+25.5% 霸榜）。乖離率直接量「漲多少」、無需豁免特例。
      // bias null（history < 20）→ permissive 不擋。
      if (biasMa20 != null && biasMa20 > ModeFilters.modeAMaxBiasMa20Pct) {
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

      // STEP 4 — 一次撈所有 candidate 的 stock data（priceHistory 給 MA20 乖離 /
      //          sparkline 重用；reasons / stocks / analyses 給後續 build）
      //
      // **窗口長度需求**：Mode B 60D 報酬排序（Wave 2b）需 ≥ 61 筆收盤、Mode A
      // MA20 乖離需 ≥ 20 筆。95 日曆天 ≈ 65 交易日：足夠算 60D + MA20 + 30 日
      // sparkline + 連假 margin（CNY 等假日叢集）。
      //
      // **歷史備註**：原預設 historyDays=5 → 每檔 ~4 筆 → Mode A 漲幅 filter 從
      // commit 253f732 起一直是死的；2026-06-20 修為 50（乖離 gate）、再到 95（60D 排序）。
      final allCandidateSymbols = stockModeScores.keys.toList();
      final historyCtx = DateContext.forDate(analysisDate, historyDays: 95);
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
      var droppedEtf = 0;
      var droppedObservation = 0;
      for (final entry in stockModeScores.entries) {
        final symbol = entry.key;
        final modes = entry.value;

        // **2026-06-20 ETF 過濾**：台股掃描 app、rule 全為個股行為設計。ETF（尤其
        // 美股指數）走勢平滑、「淺回檔 + 量縮」幾乎天天成立 → 灌進 Mode C 純雜訊。
        // user 決定 3 個 tab 全濾。stock_master.industry == 'ETF' 是乾淨標記。
        if (data.stocks[symbol]?.industry == 'ETF') {
          droppedEtf++;
          continue;
        }

        // 觀察層（8–11 分）不路由進「訊號」mode tab。daily_analysis 持久化門檻已
        // 降到 observationScoreThreshold（8）供掃描頁「觀察區」使用，此處還原 mode
        // tab 的「只收成立訊號」語意：任一 horizon ≥ minScoreThreshold 才路由。
        if (!isSignalTier(data.analyses[symbol])) {
          droppedObservation++;
          continue;
        }

        final todayPct = priceChanges[symbol];
        final biasMa20 = computeBiasMa20ForHistory(data.priceHistories[symbol]);

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
            biasMa20: biasMa20,
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
            'droppedBelowFloor=$droppedBelowFloor '
            'droppedEtf=$droppedEtf '
            'droppedObservation=$droppedObservation',
      );

      // STEP 6 — Sort each mode
      //
      // **2026-06-20 Wave 2b — Mode B 改 60D 報酬排序**：score 排序實測 corr+0.17
      // 無鑑別力（同分平台、cut 點隨機）。改用 60D 報酬（相對強度 proxy）DESC →
      // top N 真的是最強 N 檔、cap 才有意義。null（history < 61）排最後、tiebreak
      // 用 score DESC 再 symbol ASC。
      // Mode A（起漲訊號強度）/ Mode C（回檔主訊號強度、2026-06-19 改 DESC 最正優先）
      // 維持 score DESC。
      final ret60ForB = <String, double>{};
      for (final s in assignmentMap[ScoringMode.strengthObserve]!) {
        final r = computeRet60dForHistory(data.priceHistories[s.symbol]);
        if (r != null) ret60ForB[s.symbol] = r;
      }
      for (final mode in assignmentMap.keys) {
        if (mode == ScoringMode.strengthObserve) {
          assignmentMap[mode]!.sort((a, b) {
            final ra = ret60ForB[a.symbol];
            final rb = ret60ForB[b.symbol];
            // 有資料優先於無資料；都有則 60D DESC
            if (ra != null && rb == null) return -1;
            if (ra == null && rb != null) return 1;
            if (ra != null && rb != null) {
              final byRet = rb.compareTo(ra);
              if (byRet != 0) return byRet;
            }
            final byScore = b.modeScoreShort.compareTo(a.modeScoreShort);
            if (byScore != 0) return byScore;
            return a.symbol.compareTo(b.symbol);
          });
        } else {
          assignmentMap[mode]!.sort((a, b) {
            final primary = b.modeScoreShort.compareTo(
              a.modeScoreShort,
            ); // DESC
            if (primary != 0) return primary;
            return a.symbol.compareTo(b.symbol); // 二級 key：symbol ASC
          });
        }
      }

      // STEP 7 — 組 ModeRecommendation per mode、cap modeRecommendationCap
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

          // 風險警訊：從全部 reasons 抽 warning-class（neutral 子集）、不分 mode。
          // 與 modeReasons 正交 — 不 route、不污染 evidence chip / mode score，只供
          // 卡片風險徽章。補回階段重設計把警訊丟 neutral 後消失的主畫面可見性。
          // 用 Set 去重（對齊相鄰 triggeredCodes idiom）防徽章 count 灌水。
          final warningSet = <ReasonType>{};
          for (final r in allReasons) {
            final type = reasonTypeFromCode(r.reasonType);
            if (type != null && RiskWarnings.all.contains(type)) {
              warningSet.add(type);
            }
          }
          final warningReasons = warningSet.toList();

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
              warningReasons: warningReasons,
              stockName: data.stocks[symbol]?.name,
              market: data.stocks[symbol]?.market,
              latestClose: data.latestPrices[symbol]?.close,
              priceChange: priceChanges[symbol],
              trendState: data.analyses[symbol]?.trendState,
              recentPrices: recentPrices,
            ),
          );

          if (list.length >= ModeFilters.modeRecommendationCap) break;
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
