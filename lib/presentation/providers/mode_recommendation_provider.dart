import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
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

/// 該 mode 的 Top N 推薦（real-time aggregate from daily_reason）
///
/// 跟 [todayProvider] 的 horizon-based 推薦清單共存、互不影響。
/// 用 FutureProvider.family 而非 NotifierProvider — 因為這只是 read-only
/// 查詢、沒有 command 動作，每次 mode 切換重新計算即可（query 量 <50ms）。
///
/// **Auto-reload**：watch [dataUpdateEpochProvider]，每次 update 完成自動
/// invalidate 重查。mode 切換時 family key 變動也會自動 reload。
final modeRecommendationsProvider =
    FutureProvider.family<List<ModeRecommendation>, ScoringMode>((
      ref,
      mode,
    ) async {
      // Auto-reload trigger
      ref.watch(dataUpdateEpochProvider);

      final repo = ref.read(analysisRepositoryProvider);
      final cachedDb = ref.read(cachedDbProvider);
      final marketRepo = ref.read(marketDataRepositoryProvider);

      // 1. 找出該 mode 內的 reason code list
      final modeCodes = reasonCodesForMode(mode);
      if (modeCodes.isEmpty) {
        AppLogger.warning(
          'ModeRecommendations',
          'mode ${mode.name} 沒任何 rule、回空清單',
        );
        return [];
      }

      // 2. 找最新 daily_reason 的日期（不依賴 daily_recommendation）
      //    用 marketRepo.getLatestDataDate() 作為查詢日 — 跟 todayProvider 的
      //    dataDate 對齊，避免 mode tab 跟 horizon tab 顯示不同日期。
      final latestPriceDate = await marketRepo.getLatestDataDate();
      if (latestPriceDate == null) return [];

      final analysisDate = DateContext.normalize(latestPriceDate);

      // 3. SUM aggregate 取得每檔股票該 mode 內 score 加總
      final scores = await repo.getModeStockScores(analysisDate, modeCodes);
      if (scores.isEmpty) return [];

      // 4. 按 abs(modeScoreShort) DESC 排序（涵蓋 Mode C 負分情況）
      //    UI 預設用 5D 排，user 可在 card 內看到 60D 是否同方向強
      final sorted = [...scores]
        ..sort(
          (a, b) => b.modeScoreShort.abs().compareTo(a.modeScoreShort.abs()),
        );
      final top = sorted.take(30).toList();

      // 5. 批次載入股票 master + 最新價 + 30 日價量 + 該日 reasons
      final symbols = top.map((s) => s.symbol).toList();
      final historyCtx = DateContext.forDate(analysisDate);
      final data = await cachedDb.loadStockListData(
        symbols: symbols,
        analysisDate: analysisDate,
        historyStart: historyCtx.historyStart,
      );

      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        data.priceHistories,
        data.latestPrices,
      );

      // 6. 組成 ModeRecommendation list（reasons filter 到 mode 內）
      final codeSet = modeCodes.toSet();
      final results = <ModeRecommendation>[];
      for (var i = 0; i < top.length; i++) {
        final score = top[i];
        final symbol = score.symbol;
        final stock = data.stocks[symbol];
        final analysis = data.analyses[symbol];

        // mode-filtered reasons（其他 mode + neutral 的不顯示）
        final allReasons = data.reasons[symbol] ?? [];
        final modeReasons = allReasons
            .where((r) => codeSet.contains(r.reasonType))
            .toList();

        // 最近 30 日收盤價（迷你走勢圖）
        final priceHistory = data.priceHistories[symbol];
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

        results.add(
          ModeRecommendation(
            symbol: symbol,
            rank: i + 1,
            modeScoreShort: score.modeScoreShort,
            modeScoreLong: score.modeScoreLong,
            reasons: modeReasons,
            stockName: stock?.name,
            market: stock?.market,
            latestClose: data.latestPrices[symbol]?.close,
            priceChange: priceChanges[symbol],
            trendState: analysis?.trendState,
            recentPrices: recentPrices,
          ),
        );
      }

      return results;
    });
