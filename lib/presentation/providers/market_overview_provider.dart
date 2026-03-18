import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/industry_names.dart';
import 'package:afterclose/core/constants/market_index_names.dart';
export 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/chip_anomaly_service.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Market Overview State
// ==================================================

/// 漲跌家數
class AdvanceDecline {
  const AdvanceDecline({
    this.advance = 0,
    this.decline = 0,
    this.unchanged = 0,
  });

  final int advance;
  final int decline;
  final int unchanged;

  int get total => advance + decline + unchanged;
}

/// 法人買賣超總額（元）
class InstitutionalTotals {
  const InstitutionalTotals({
    this.foreignNet = 0,
    this.trustNet = 0,
    this.dealerNet = 0,
    this.totalNet = 0,
  });

  final double foreignNet;
  final double trustNet;
  final double dealerNet;
  final double totalNet;
}

/// 融資融券彙總（張）
class MarginTradingTotals {
  const MarginTradingTotals({
    this.marginBalance = 0,
    this.marginChange = 0,
    this.shortBalance = 0,
    this.shortChange = 0,
  });

  final double marginBalance;
  final double marginChange;
  final double shortBalance;
  final double shortChange;
}

/// 成交額統計（元）
class TradingTurnover {
  const TradingTurnover({this.totalTurnover = 0});

  final double totalTurnover; // 單位：元
}

/// 漲停/跌停家數
class LimitUpDown {
  const LimitUpDown({this.limitUp = 0, this.limitDown = 0});

  final int limitUp;
  final int limitDown;
}

/// 成交額 vs 均量比較
class TurnoverComparison {
  const TurnoverComparison({this.todayTurnover = 0, this.avg5dTurnover = 0});

  final double todayTurnover;
  final double avg5dTurnover;

  /// 與 5 日均量的變化百分比
  double get changePercent => avg5dTurnover > 0
      ? (todayTurnover - avg5dTurnover) / avg5dTurnover * 100
      : 0;
}

/// 注意/處置股家數
class WarningCounts {
  const WarningCounts({this.attention = 0, this.disposal = 0});

  final int attention;
  final int disposal;

  int get total => attention + disposal;
}

/// 法人連續買賣超天數
class InstitutionalStreak {
  const InstitutionalStreak({
    this.foreignStreak = 0,
    this.trustStreak = 0,
    this.dealerStreak = 0,
  });

  /// 正數 = 連續買超天數，負數 = 連續賣超天數
  final int foreignStreak;
  final int trustStreak;
  final int dealerStreak;
}

/// 推薦績效摘要（用於 dashboard 精簡顯示）
class RecommendationPerformance {
  const RecommendationPerformance({
    required this.recentResults,
    required this.winRate,
    required this.avgReturn,
    required this.totalCount,
    required this.topRules,
  });

  /// 近 30 筆驗證勝負序列（true=獲利，false=虧損），newest→oldest
  final List<bool> recentResults;

  /// 整體勝率 %
  final double winRate;

  /// 平均報酬 %
  final double avgReturn;

  /// 已驗證推薦總筆數
  final int totalCount;

  /// 勝率最高的 Top 3 規則
  final List<TopRule> topRules;
}

/// 勝率最高的規則（用於 dashboard 顯示）
class TopRule {
  const TopRule({
    required this.ruleId,
    required this.winRate,
    required this.avgReturn,
    required this.triggerCount,
  });

  final String ruleId;
  final double winRate;
  final double avgReturn;
  final int triggerCount;
}

/// 產業表現
class IndustrySummary {
  const IndustrySummary({
    required this.industry,
    required this.stockCount,
    required this.avgChangePct,
    required this.advance,
    required this.decline,
  });

  final String industry;
  final int stockCount;
  final double avgChangePct;
  final int advance;
  final int decline;
}

/// 大盤總覽狀態
class MarketOverviewState {
  const MarketOverviewState({
    this.indices = const [],
    this.indexHistory = const {},
    this.advanceDecline = const AdvanceDecline(),
    this.institutional = const InstitutionalTotals(),
    this.margin = const MarginTradingTotals(),
    // 依市場分組的統計（預設空 Map）
    this.advanceDeclineByMarket = const {},
    this.institutionalByMarket = const {},
    this.marginByMarket = const {},
    this.turnoverByMarket = const {},
    this.limitUpDownByMarket = const {},
    this.turnoverComparisonByMarket = const {},
    this.warningCountsByMarket = const {},
    this.institutionalStreakByMarket = const {},
    this.industrySummaryByMarket = const {},
    // 30日歷史趨勢（供 sparkline / bar chart，時序排列 oldest→newest）
    this.institutionalTotalNetHistory = const {},
    this.turnoverHistory = const {},
    this.marginBalanceHistory = const {},
    this.shortBalanceHistory = const {},
    this.advanceRatioHistory = const {},
    this.recommendationPerformance,
    this.chipAnomaliesByMarket = const {},
    this.isLoading = false,
    this.error,
    this.dataDate,
  });

  final List<TwseMarketIndex> indices;

  /// 指數名稱 → 近 30 日收盤值列表（供走勢圖使用）
  final Map<String, List<double>> indexHistory;
  final AdvanceDecline advanceDecline;
  final InstitutionalTotals institutional;
  final MarginTradingTotals margin;

  /// 漲跌家數（依市場分組）
  /// Key: 'TWSE' / 'TPEx'
  final Map<String, AdvanceDecline> advanceDeclineByMarket;

  /// 法人買賣超（依市場分組）
  /// Key: 'TWSE' / 'TPEx'
  final Map<String, InstitutionalTotals> institutionalByMarket;

  /// 融資融券（依市場分組）
  /// Key: 'TWSE' / 'TPEx'
  final Map<String, MarginTradingTotals> marginByMarket;

  /// 成交額統計（依市場分組）
  /// Key: 'TWSE' / 'TPEx'
  final Map<String, TradingTurnover> turnoverByMarket;

  /// 漲停/跌停家數（依市場分組）
  final Map<String, LimitUpDown> limitUpDownByMarket;

  /// 成交額 vs 5 日均量比較（依市場分組）
  final Map<String, TurnoverComparison> turnoverComparisonByMarket;

  /// 注意/處置股家數（依市場分組）
  final Map<String, WarningCounts> warningCountsByMarket;

  /// 法人連續買賣超天數（依市場分組）
  final Map<String, InstitutionalStreak> institutionalStreakByMarket;

  /// 產業表現（依市場分組）
  final Map<String, List<IndustrySummary>> industrySummaryByMarket;

  /// 30日法人合計淨額歷史（供趨勢 bar chart，元，oldest→newest）
  final Map<String, List<double>> institutionalTotalNetHistory;

  /// 30日成交量歷史（供趨勢 bar chart，元，oldest→newest）
  final Map<String, List<double>> turnoverHistory;

  /// 30日融資餘額歷史（供趨勢 sparkline，張，oldest→newest）
  final Map<String, List<double>> marginBalanceHistory;

  /// 30日融券餘額歷史（供趨勢 sparkline，張，oldest→newest）
  final Map<String, List<double>> shortBalanceHistory;

  /// 30日漲跌比歷史（供趨勢 sparkline，advance/total 0~1，oldest→newest）
  final Map<String, List<double>> advanceRatioHistory;

  /// 推薦績效摘要（全市場，非 per-market）
  final RecommendationPerformance? recommendationPerformance;

  /// 籌碼異動摘要（依市場分組）
  final Map<String, List<ChipAnomaly>> chipAnomaliesByMarket;

  final bool isLoading;
  final String? error;

  /// 資料日期（用於 UI 顯示「資料更新日期」）
  final DateTime? dataDate;

  /// 是否有任何有效資料
  bool get hasData => indices.isNotEmpty || advanceDecline.total > 0;

  MarketOverviewState copyWith({
    List<TwseMarketIndex>? indices,
    Map<String, List<double>>? indexHistory,
    AdvanceDecline? advanceDecline,
    InstitutionalTotals? institutional,
    MarginTradingTotals? margin,
    Map<String, AdvanceDecline>? advanceDeclineByMarket,
    Map<String, InstitutionalTotals>? institutionalByMarket,
    Map<String, MarginTradingTotals>? marginByMarket,
    Map<String, TradingTurnover>? turnoverByMarket,
    Map<String, LimitUpDown>? limitUpDownByMarket,
    Map<String, TurnoverComparison>? turnoverComparisonByMarket,
    Map<String, WarningCounts>? warningCountsByMarket,
    Map<String, InstitutionalStreak>? institutionalStreakByMarket,
    Map<String, List<IndustrySummary>>? industrySummaryByMarket,
    Map<String, List<double>>? institutionalTotalNetHistory,
    Map<String, List<double>>? turnoverHistory,
    Map<String, List<double>>? marginBalanceHistory,
    Map<String, List<double>>? shortBalanceHistory,
    Map<String, List<double>>? advanceRatioHistory,
    RecommendationPerformance? recommendationPerformance,
    Map<String, List<ChipAnomaly>>? chipAnomaliesByMarket,
    bool? isLoading,
    String? error,
    DateTime? dataDate,
  }) {
    return MarketOverviewState(
      indices: indices ?? this.indices,
      indexHistory: indexHistory ?? this.indexHistory,
      advanceDecline: advanceDecline ?? this.advanceDecline,
      institutional: institutional ?? this.institutional,
      margin: margin ?? this.margin,
      advanceDeclineByMarket:
          advanceDeclineByMarket ?? this.advanceDeclineByMarket,
      institutionalByMarket:
          institutionalByMarket ?? this.institutionalByMarket,
      marginByMarket: marginByMarket ?? this.marginByMarket,
      turnoverByMarket: turnoverByMarket ?? this.turnoverByMarket,
      limitUpDownByMarket: limitUpDownByMarket ?? this.limitUpDownByMarket,
      turnoverComparisonByMarket:
          turnoverComparisonByMarket ?? this.turnoverComparisonByMarket,
      warningCountsByMarket:
          warningCountsByMarket ?? this.warningCountsByMarket,
      institutionalStreakByMarket:
          institutionalStreakByMarket ?? this.institutionalStreakByMarket,
      industrySummaryByMarket:
          industrySummaryByMarket ?? this.industrySummaryByMarket,
      institutionalTotalNetHistory:
          institutionalTotalNetHistory ?? this.institutionalTotalNetHistory,
      turnoverHistory: turnoverHistory ?? this.turnoverHistory,
      marginBalanceHistory: marginBalanceHistory ?? this.marginBalanceHistory,
      shortBalanceHistory: shortBalanceHistory ?? this.shortBalanceHistory,
      advanceRatioHistory: advanceRatioHistory ?? this.advanceRatioHistory,
      recommendationPerformance:
          recommendationPerformance ?? this.recommendationPerformance,
      chipAnomaliesByMarket:
          chipAnomaliesByMarket ?? this.chipAnomaliesByMarket,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dataDate: dataDate ?? this.dataDate,
    );
  }
}

// ==================================================
// Market Overview Notifier
// ==================================================

class MarketOverviewNotifier extends Notifier<MarketOverviewState> {
  var _active = true;

  @override
  MarketOverviewState build() {
    _active = true;
    ref.onDispose(() => _active = false);
    return const MarketOverviewState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  TwseClient get _twse => ref.read(twseClientProvider);
  TpexClient get _tpex => ref.read(tpexClientProvider);

  /// 載入大盤總覽資料
  ///
  /// 平行執行 API 呼叫與 DB 彙總查詢，任一失敗不影響其他。
  /// 設有總超時機制：超過 [_loadTimeoutSec] 秒後先結束 loading 顯示 DB 資料，
  /// API 資料在背景繼續載入，完成後自動更新 UI。
  static const _loadTimeoutSec = 20;

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 取得最新資料日期
      final dataDate = await _db.getLatestDataDate() ?? DateTime.now();

      // 回退日期：前一個交易日
      // 處理開工日盤後資料未釋出、DB 重置後部分同步等情境
      final fallbackDate = TaiwanCalendar.getPreviousTradingDay(
        dataDate.subtract(const Duration(days: 1)),
      );

      // 平行載入所有資料（各 _load* 方法內部已處理錯誤）
      // by-market 方法在主要日期無資料時會自動回退到 fallbackDate
      final allTasks = Future.wait([
        _loadIndices(), // [0] List<TwseMarketIndex>
        _loadAdvanceDecline(dataDate), // [1] AdvanceDecline
        _loadInstitutionalTotals(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [2] InstitutionalTotals
        _loadIndexHistory(), // [3] Map<String, List<double>>
        _loadAdvanceDeclineByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [4] Map<String, AdvanceDecline>
        _loadInstitutionalByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [5] Map<String, InstitutionalTotals>
        _loadMarginByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [6] Map<String, MarginTradingTotals>
        _loadTurnoverByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [7] Map<String, TradingTurnover>
        _loadLimitUpDownByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [8] Map<String, LimitUpDown>
        _loadTurnoverComparisonByMarket(
          dataDate,
        ), // [9] Map<String, TurnoverComparison>
        _loadWarningCountsByMarket(), // [10] Map<String, WarningCounts>
        _loadInstitutionalStreakByMarket(
          dataDate,
        ), // [11] Map<String, InstitutionalStreak>
        _loadIndustrySummaryByMarket(
          dataDate,
          fallbackDate: fallbackDate,
        ), // [12] Map<String, List<IndustrySummary>>
        _loadInstitutionalHistoryByMarket(dataDate), // [13]
        _loadTurnoverHistoryByMarket(dataDate), // [14]
        _loadMarginHistoryByMarket(dataDate), // [15]
        _loadAdvanceDeclineHistoryByMarket(dataDate), // [16]
        _loadRecommendationPerformance(), // [17]
        _loadChipAnomalies(dataDate), // [18]
      ]);

      // 超時機制：最多等 _loadTimeoutSec 秒
      // 超時後先結束 loading 顯示 DB 資料，API 在背景繼續載入
      List<Object?> results;
      try {
        results = await allTasks.timeout(
          const Duration(seconds: _loadTimeoutSec),
        );
      } on TimeoutException {
        AppLogger.warning(
          'MarketOverview',
          '大盤總覽載入超過 ${_loadTimeoutSec}s，先顯示可用資料',
        );
        // 結束 loading 指示器，讓 UI 可互動
        if (_active) {
          state = state.copyWith(isLoading: false, dataDate: dataDate);
        }
        // 背景繼續等待 API 回應，完成後靜默更新
        unawaited(
          allTasks
              .then((r) {
                if (_active) state = _buildState(r, dataDate);
              })
              .catchError((Object e) {
                AppLogger.warning('MarketOverview', '背景載入完成但建構 state 失敗: $e');
              }),
        );
        return;
      }

      if (!_active) return;

      state = _buildState(results, dataDate);
    } catch (e) {
      // getLatestDataDate() 可能拋出例外
      AppLogger.error('MarketOverview', '載入大盤總覽失敗', e);
      if (_active) {
        state = state.copyWith(
          isLoading: false,
          error: ErrorDisplay.message(e),
        );
      }
    }
  }

  /// 從載入結果建構 state
  MarketOverviewState _buildState(List<Object?> results, DateTime dataDate) {
    final indices = results[0] as List<TwseMarketIndex>;
    final rawHistory = results[3] as Map<String, List<double>>;

    // 複製歷史資料，避免原地修改導致重複追加
    final indexHistory = <String, List<double>>{
      for (final e in rawHistory.entries) e.key: List<double>.from(e.value),
    };

    // 將即時 API 的今日收盤價追加到歷史資料，確保走勢圖反映最新資料
    for (final idx in indices) {
      final history = indexHistory[idx.name];
      if (history != null && history.isNotEmpty) {
        // 使用 epsilon 比較避免浮點數精度問題
        if ((history.last - idx.close).abs() > 0.001) {
          history.add(idx.close);
        }
      }
    }

    final instByMarket = results[5] as Map<String, InstitutionalTotals>;
    final marginByMarket = results[6] as Map<String, MarginTradingTotals>;

    // 從 byMarket 合併全市場融資融券總額（避免重複查詢）
    final marginTotal = _mergeMarginTotals(marginByMarket);

    // Streak 來自 DB（per-stock 聚合），顯示金額來自 API（市場總計）。
    // 兩者資料來源不同，方向可能矛盾（API 含大宗交易等 per-stock 未涵蓋的項目）。
    // 當 streak 方向與 API 值矛盾時，重置為 ±1（不會顯示 badge，因門檻 ≥ 2）。
    final rawStreak = results[11] as Map<String, InstitutionalStreak>;
    final validatedStreak = _validateStreakConsistency(rawStreak, instByMarket);

    // 30日歷史趨勢資料
    final instHistory = results[13] as Map<String, List<double>>;
    final turnoverHist = results[14] as Map<String, List<double>>;
    final marginHistory =
        results[15] as Map<String, ({List<double> margin, List<double> short})>;
    final advRatioHistory = results[16] as Map<String, List<double>>;
    final recPerf = results[17] as RecommendationPerformance?;
    final chipAnomalies = results[18] as Map<String, List<ChipAnomaly>>;

    return MarketOverviewState(
      indices: indices,
      advanceDecline: results[1] as AdvanceDecline,
      institutional: results[2] as InstitutionalTotals,
      margin: marginTotal,
      indexHistory: indexHistory,
      advanceDeclineByMarket: results[4] as Map<String, AdvanceDecline>,
      institutionalByMarket: instByMarket,
      marginByMarket: marginByMarket,
      turnoverByMarket: results[7] as Map<String, TradingTurnover>,
      limitUpDownByMarket: results[8] as Map<String, LimitUpDown>,
      turnoverComparisonByMarket: results[9] as Map<String, TurnoverComparison>,
      warningCountsByMarket: results[10] as Map<String, WarningCounts>,
      institutionalStreakByMarket: validatedStreak,
      industrySummaryByMarket:
          results[12] as Map<String, List<IndustrySummary>>,
      institutionalTotalNetHistory: instHistory,
      turnoverHistory: turnoverHist,
      marginBalanceHistory: {
        for (final e in marginHistory.entries) e.key: e.value.margin,
      },
      shortBalanceHistory: {
        for (final e in marginHistory.entries) e.key: e.value.short,
      },
      advanceRatioHistory: advRatioHistory,
      recommendationPerformance: recPerf,
      chipAnomaliesByMarket: chipAnomalies,
      dataDate: dataDate,
    );
  }

  /// 從分市場融資融券合併為全市場總額
  static MarginTradingTotals _mergeMarginTotals(
    Map<String, MarginTradingTotals> byMarket,
  ) {
    if (byMarket.isEmpty) return const MarginTradingTotals();
    double sum(double Function(MarginTradingTotals m) fn) =>
        byMarket.values.fold(0, (acc, m) => acc + fn(m));
    return MarginTradingTotals(
      marginBalance: sum((m) => m.marginBalance),
      marginChange: sum((m) => m.marginChange),
      shortBalance: sum((m) => m.shortBalance),
      shortChange: sum((m) => m.shortChange),
    );
  }

  /// 驗證 streak 方向與 API 顯示值的一致性
  ///
  /// Streak 資料來自 DB（per-stock 聚合），顯示金額來自 API（市場總計）。
  /// 當兩者方向矛盾時（例如 DB 顯示買超但 API 顯示賣超），
  /// 重置該法人的 streak 為 ±1，避免 UI 出現「連N日買超」但金額為負的矛盾。
  static Map<String, InstitutionalStreak> _validateStreakConsistency(
    Map<String, InstitutionalStreak> streaks,
    Map<String, InstitutionalTotals> totals,
  ) {
    final result = <String, InstitutionalStreak>{};
    for (final market in streaks.keys) {
      final streak = streaks[market]!;
      final inst = totals[market];
      if (inst == null) {
        result[market] = streak;
        continue;
      }
      result[market] = InstitutionalStreak(
        foreignStreak: _alignStreak(streak.foreignStreak, inst.foreignNet),
        trustStreak: _alignStreak(streak.trustStreak, inst.trustNet),
        dealerStreak: _alignStreak(streak.dealerStreak, inst.dealerNet),
      );
    }
    return result;
  }

  /// 若 streak 方向與 API 值矛盾，重置為 ±1（badge 門檻 ≥ 2，不會顯示）
  static int _alignStreak(int streak, double apiValue) {
    if (streak == 0 || apiValue == 0) return 0;
    final streakPositive = streak > 0;
    final apiPositive = apiValue > 0;
    if (streakPositive == apiPositive) return streak;
    // 方向矛盾：今日可能翻轉，重置為 day-1
    return apiPositive ? 1 : -1;
  }

  Future<List<TwseMarketIndex>> _loadIndices() async {
    try {
      // 獨立呼叫 TWSE 和 TPEx API，避免一方失敗拖垮另一方
      List<TwseMarketIndex> twseIndices = [];
      List<TwseMarketIndex> tpexIndices = [];

      try {
        twseIndices = await _twse.getMarketIndices();
      } catch (e) {
        AppLogger.warning('MarketOverview', '載入 TWSE 指數失敗: $e');
      }

      try {
        tpexIndices = await _tpex.getTpexIndex();
      } catch (e) {
        AppLogger.warning('MarketOverview', '載入 TPEx 指數失敗: $e');
      }

      // API 全部失敗時，從 DB 取最新指數作為備援
      if (twseIndices.isEmpty && tpexIndices.isEmpty) {
        return _loadIndicesFromDb();
      }

      // 精確名稱匹配，僅保留 Dashboard 需要的 TWSE 重點指數
      final targetNames = MarketIndexNames.dashboardIndices.toSet();
      final filtered = twseIndices
          .where((idx) => targetNames.contains(idx.name))
          .toList();

      // 需要從 DB 補資料時，只查一次（lazy cache）
      List<TwseMarketIndex>? dbCache;
      Future<List<TwseMarketIndex>> getDbCache() async =>
          dbCache ??= await _loadIndicesFromDb();

      // TWSE API 失敗但 TPEx 成功時，從 DB 補 TWSE 指數
      if (filtered.isEmpty) {
        final dbIndices = await getDbCache();
        filtered.addAll(
          dbIndices.where((idx) => targetNames.contains(idx.name)),
        );
      }

      // 加入 TPEx 櫃買指數（取最新一筆作為即時資料）
      if (tpexIndices.isNotEmpty) {
        filtered.add(tpexIndices.last);
      } else {
        // TPEx API 失敗時，從 DB 補櫃買指數
        final dbIndices = await getDbCache();
        final dbTpex = dbIndices
            .where((idx) => idx.name == MarketIndexNames.tpexIndex)
            .toList();
        if (dbTpex.isNotEmpty) filtered.add(dbTpex.last);
      }

      return filtered;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入大盤指數失敗: $e');
      return _loadIndicesFromDb();
    }
  }

  /// 從 DB 載入最新指數值（API 失敗時的備援）
  Future<List<TwseMarketIndex>> _loadIndicesFromDb() async {
    try {
      final indexNames = [
        ...MarketIndexNames.dashboardIndices,
        MarketIndexNames.tpexIndex,
        MarketIndexNames.totalReturnIndex,
      ];
      final historyMap = await _db.getIndexHistoryBatch(indexNames, days: 5);

      // 取每個指數的最新一筆
      return historyMap.entries.where((e) => e.value.isNotEmpty).map((e) {
        final latest = e.value.last;
        return TwseMarketIndex(
          date: latest.date,
          name: latest.name,
          close: latest.close,
          change: latest.change,
          changePercent: latest.changePercent,
        );
      }).toList();
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入 DB 指數備援失敗: $e');
      return [];
    }
  }

  /// 從 DB 載入近 30 日指數歷史（供走勢圖使用）
  Future<Map<String, List<double>>> _loadIndexHistory() async {
    try {
      // 查詢 TWSE 重點指數 + TPEx 櫃買指數的歷史
      final indexNames = [
        ...MarketIndexNames.dashboardIndices,
        MarketIndexNames.tpexIndex,
        MarketIndexNames.totalReturnIndex,
      ];

      final historyMap = await _db.getIndexHistoryBatch(indexNames, days: 30);

      // 轉換為 name → close 值列表
      final result = <String, List<double>>{};
      for (final entry in historyMap.entries) {
        result[entry.key] = entry.value.map((e) => e.close).toList();
      }
      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入指數歷史失敗: $e');
      return {};
    }
  }

  Future<AdvanceDecline> _loadAdvanceDecline(DateTime date) async {
    try {
      final counts = await _db.getAdvanceDeclineCounts(date);
      return AdvanceDecline(
        advance: counts['advance'] ?? 0,
        decline: counts['decline'] ?? 0,
        unchanged: counts['unchanged'] ?? 0,
      );
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入漲跌家數失敗: $e');
      return const AdvanceDecline();
    }
  }

  /// 載入法人買賣超金額總額（上市+上櫃合計）
  ///
  /// 使用 TWSE/TPEX 的法人買賣金額統計 API。
  /// TWSE 和 TPEX 獨立呼叫，避免一方失敗拖垮另一方。
  /// 若主要日期的 API 回傳 null，自動用 [fallbackDate] 重試。
  Future<InstitutionalTotals> _loadInstitutionalTotals(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    // 平行呼叫 TWSE 和 TPEX API，各自獨立 catch 避免互相拖垮
    final results = await Future.wait([
      () async {
        try {
          var data = await _twse.getInstitutionalAmounts(date: date);
          if (data == null && fallbackDate != null) {
            data = await _twse.getInstitutionalAmounts(date: fallbackDate);
          }
          return data;
        } catch (e) {
          AppLogger.warning('MarketOverview', '載入 TWSE 法人總額失敗: $e');
          return null;
        }
      }(),
      () async {
        try {
          var data = await _tpex.getInstitutionalAmounts(date: date);
          if (data == null && fallbackDate != null) {
            data = await _tpex.getInstitutionalAmounts(date: fallbackDate);
          }
          return data;
        } catch (e) {
          AppLogger.warning('MarketOverview', '載入 TPEx 法人總額失敗: $e');
          return null;
        }
      }(),
    ]);

    final twseData = results[0] as TwseInstitutionalAmounts?;
    final tpexData = results[1] as TpexInstitutionalAmounts?;

    final foreignNet =
        (twseData?.foreignNet ?? 0) + (tpexData?.foreignNet ?? 0);
    final trustNet = (twseData?.trustNet ?? 0) + (tpexData?.trustNet ?? 0);
    final dealerNet = (twseData?.dealerNet ?? 0) + (tpexData?.dealerNet ?? 0);

    return InstitutionalTotals(
      foreignNet: foreignNet,
      trustNet: trustNet,
      dealerNet: dealerNet,
      totalNet: foreignNet + trustNet + dealerNet,
    );
  }

  /// 載入漲跌家數（依市場分組）
  ///
  /// 若主要日期缺少某市場資料，自動用 [fallbackDate] 補齊。
  Future<Map<String, AdvanceDecline>> _loadAdvanceDeclineByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    try {
      final data = await _db.getAdvanceDeclineCountsByMarket(date);

      // 回退：若缺少某市場，嘗試前一交易日補齊
      if (fallbackDate != null && data.length < 2) {
        final fallbackData = await _db.getAdvanceDeclineCountsByMarket(
          fallbackDate,
        );
        for (final entry in fallbackData.entries) {
          data.putIfAbsent(entry.key, () => entry.value);
        }
      }

      return {
        for (final entry in data.entries)
          entry.key: AdvanceDecline(
            advance: entry.value['advance'] ?? 0,
            decline: entry.value['decline'] ?? 0,
            unchanged: entry.value['unchanged'] ?? 0,
          ),
      };
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入分市場漲跌家數失敗: $e');
      return {};
    }
  }

  /// 載入法人買賣超金額（依市場分組）
  ///
  /// 使用 TWSE/TPEX 的法人買賣金額統計 API，直接取得市場總計金額（元）。
  /// TWSE 和 TPEX 獨立呼叫，避免一方失敗拖垮另一方。
  /// 若主要日期的 API 回傳 null，自動用 [fallbackDate] 重試。
  Future<Map<String, InstitutionalTotals>> _loadInstitutionalByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    // 平行呼叫 TWSE 和 TPEX API，各自獨立 catch 避免互相拖垮
    final results = await Future.wait([
      () async {
        try {
          var data = await _twse.getInstitutionalAmounts(date: date);
          if (data == null && fallbackDate != null) {
            data = await _twse.getInstitutionalAmounts(date: fallbackDate);
          }
          return data != null
              ? MapEntry(
                  'TWSE',
                  InstitutionalTotals(
                    foreignNet: data.foreignNet,
                    trustNet: data.trustNet,
                    dealerNet: data.dealerNet,
                    totalNet: data.totalNet,
                  ),
                )
              : null;
        } catch (e) {
          AppLogger.warning('MarketOverview', '載入 TWSE 法人總額失敗: $e');
          return null;
        }
      }(),
      () async {
        try {
          var data = await _tpex.getInstitutionalAmounts(date: date);
          if (data == null && fallbackDate != null) {
            data = await _tpex.getInstitutionalAmounts(date: fallbackDate);
          }
          return data != null
              ? MapEntry(
                  'TPEx',
                  InstitutionalTotals(
                    foreignNet: data.foreignNet,
                    trustNet: data.trustNet,
                    dealerNet: data.dealerNet,
                    totalNet: data.totalNet,
                  ),
                )
              : null;
        } catch (e) {
          AppLogger.warning('MarketOverview', '載入 TPEx 法人總額失敗: $e');
          return null;
        }
      }(),
    ]);

    return {
      for (final entry in results)
        if (entry != null) entry.key: entry.value,
    };
  }

  /// 載入融資融券（依市場分組）
  ///
  /// 融資融券資料日期可能與 daily_price 不同步（TPEx 有 T+1 延遲），
  /// 因此直接使用 [getLatestMarginTradingTotalsByMarket] 取得各市場最新資料，
  /// 不依賴 daily_price 的日期。
  Future<Map<String, MarginTradingTotals>> _loadMarginByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    try {
      // 直接查詢各市場最新融資融券資料，避免日期不同步問題
      final data = await _db.getLatestMarginTradingTotalsByMarket();

      return {
        for (final entry in data.entries)
          entry.key: MarginTradingTotals(
            marginBalance: entry.value['marginBalance'] ?? 0,
            marginChange: entry.value['marginChange'] ?? 0,
            shortBalance: entry.value['shortBalance'] ?? 0,
            shortChange: entry.value['shortChange'] ?? 0,
          ),
      };
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入分市場融資融券總額失敗: $e');
      return {};
    }
  }

  /// 載入成交額統計（依市場分組）
  ///
  /// 若主要日期缺少某市場資料，自動用 [fallbackDate] 補齊。
  Future<Map<String, TradingTurnover>> _loadTurnoverByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    try {
      final data = await _db.getTurnoverSummaryByMarket(date);

      // 回退：若缺少某市場，嘗試前一交易日補齊
      if (fallbackDate != null && data.length < 2) {
        final fallbackData = await _db.getTurnoverSummaryByMarket(fallbackDate);
        for (final entry in fallbackData.entries) {
          data.putIfAbsent(entry.key, () => entry.value);
        }
      }

      return {
        for (final entry in data.entries)
          entry.key: TradingTurnover(
            totalTurnover: entry.value['totalTurnover'] ?? 0.0,
          ),
      };
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入分市場成交額失敗: $e');
      return {};
    }
  }

  /// 載入漲停/跌停家數（依市場分組）
  Future<Map<String, LimitUpDown>> _loadLimitUpDownByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    try {
      final data = await _db.getLimitUpDownCountsByMarket(date);

      if (fallbackDate != null && data.length < 2) {
        final fallbackData = await _db.getLimitUpDownCountsByMarket(
          fallbackDate,
        );
        for (final entry in fallbackData.entries) {
          data.putIfAbsent(entry.key, () => entry.value);
        }
      }

      return {
        for (final entry in data.entries)
          entry.key: LimitUpDown(
            limitUp: entry.value['limitUp'] ?? 0,
            limitDown: entry.value['limitDown'] ?? 0,
          ),
      };
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入漲停跌停家數失敗: $e');
      return {};
    }
  }

  /// 載入成交額 vs 5 日均量比較（依市場分組）
  Future<Map<String, TurnoverComparison>> _loadTurnoverComparisonByMarket(
    DateTime date,
  ) async {
    try {
      final data = await _db.getRecentTurnoverByMarket(date, days: 5);
      final result = <String, TurnoverComparison>{};

      for (final entry in data.entries) {
        final list = entry.value;
        if (list.length < 2) continue; // 至少要有今日 + 1 天歷史

        final todayTurnover = list.first.turnover;
        // 前 5 天平均（跳過第一筆今日資料）
        final historyDays = list.skip(1).take(5).toList();
        if (historyDays.isEmpty) continue;

        final avg5d =
            historyDays.fold<double>(0, (sum, e) => sum + e.turnover) /
            historyDays.length;

        result[entry.key] = TurnoverComparison(
          todayTurnover: todayTurnover,
          avg5dTurnover: avg5d,
        );
      }

      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入成交額均量比較失敗: $e');
      return {};
    }
  }

  /// 載入注意/處置股家數（依市場分組）
  Future<Map<String, WarningCounts>> _loadWarningCountsByMarket() async {
    try {
      final data = await _db.getActiveWarningCountsByMarket();

      return {
        for (final entry in data.entries)
          entry.key: WarningCounts(
            attention: entry.value['ATTENTION'] ?? 0,
            disposal: entry.value['DISPOSAL'] ?? 0,
          ),
      };
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入注意處置股家數失敗: $e');
      return {};
    }
  }

  /// 載入法人連續買賣超天數（依市場分組）
  Future<Map<String, InstitutionalStreak>> _loadInstitutionalStreakByMarket(
    DateTime date,
  ) async {
    try {
      final data = await _db.getRecentInstitutionalDailyByMarket(date);
      final result = <String, InstitutionalStreak>{};

      for (final entry in data.entries) {
        final dailyList = entry.value;
        if (dailyList.isEmpty) continue;

        result[entry.key] = InstitutionalStreak(
          foreignStreak: _calculateStreak(
            dailyList.map((e) => e.foreignNet).toList(),
          ),
          trustStreak: _calculateStreak(
            dailyList.map((e) => e.trustNet).toList(),
          ),
          dealerStreak: _calculateStreak(
            dailyList.map((e) => e.dealerNet).toList(),
          ),
        );
      }

      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入法人連續買賣超失敗: $e');
      return {};
    }
  }

  /// 計算連續同方向天數（純函式）
  ///
  /// [values] 按日期降序（最新在前）
  /// 回傳：正數 = 連續買超天數，負數 = 連續賣超天數，0 = 最新一天為零
  static int _calculateStreak(List<double> values) {
    if (values.isEmpty) return 0;

    final first = values.first;
    if (first == 0) return 0;

    final isPositive = first > 0;
    int count = 0;
    for (final v in values) {
      if ((isPositive && v > 0) || (!isPositive && v < 0)) {
        count++;
      } else {
        break;
      }
    }

    return isPositive ? count : -count;
  }

  /// 載入法人合計淨額 30 日歷史（供趨勢 bar chart）
  ///
  /// 複用既有 [getRecentInstitutionalDailyByMarket]，
  /// 提取 totalNet (foreign+trust+dealer) 並反轉為 oldest→newest。
  Future<Map<String, List<double>>> _loadInstitutionalHistoryByMarket(
    DateTime date,
  ) async {
    try {
      final raw = await _db.getRecentInstitutionalDailyByMarket(date);
      final result = <String, List<double>>{};
      for (final entry in raw.entries) {
        result[entry.key] = entry.value
            .map((e) => e.foreignNet + e.trustNet + e.dealerNet)
            .toList()
            .reversed
            .toList();
      }
      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入法人歷史趨勢失敗: $e');
      return {};
    }
  }

  /// 載入成交額 30 日歷史（供趨勢 bar chart）
  ///
  /// 傳入 days: 30 覆蓋預設的 5 天，反轉為 oldest→newest。
  Future<Map<String, List<double>>> _loadTurnoverHistoryByMarket(
    DateTime date,
  ) async {
    try {
      final raw = await _db.getRecentTurnoverByMarket(date, days: 30);
      final result = <String, List<double>>{};
      for (final entry in raw.entries) {
        result[entry.key] = entry.value
            .map((e) => e.turnover)
            .toList()
            .reversed
            .toList();
      }
      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入成交額歷史趨勢失敗: $e');
      return {};
    }
  }

  /// 載入融資/融券餘額 30 日歷史（供趨勢 sparkline）
  ///
  /// 回傳同時包含 margin 和 short 兩組 List，避免查兩次。
  Future<Map<String, ({List<double> margin, List<double> short})>>
  _loadMarginHistoryByMarket(DateTime date) async {
    try {
      final raw = await _db.getRecentMarginTradingByMarket(date);
      final result = <String, ({List<double> margin, List<double> short})>{};
      for (final entry in raw.entries) {
        final reversed = entry.value.reversed.toList();
        result[entry.key] = (
          margin: reversed.map((e) => e.marginBalance).toList(),
          short: reversed.map((e) => e.shortBalance).toList(),
        );
      }
      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入融資融券歷史趨勢失敗: $e');
      return {};
    }
  }

  /// 載入漲跌比 30 日歷史（供趨勢 sparkline）
  ///
  /// 計算 advance / (advance + decline + unchanged)，範圍 0~1。
  Future<Map<String, List<double>>> _loadAdvanceDeclineHistoryByMarket(
    DateTime date,
  ) async {
    try {
      final raw = await _db.getRecentAdvanceDeclineByMarket(date);
      final result = <String, List<double>>{};
      for (final entry in raw.entries) {
        result[entry.key] = entry.value.reversed.map((e) {
          final total = e.advance + e.decline + e.unchanged;
          return total > 0 ? e.advance / total : 0.5;
        }).toList();
      }
      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入漲跌比歷史趨勢失敗: $e');
      return {};
    }
  }

  /// 載入推薦績效摘要（全市場，非 per-market）
  ///
  /// 使用現有 [RuleAccuracyService] 的查詢方法，
  /// 組合出 dashboard 需要的精簡摘要。
  Future<RecommendationPerformance?> _loadRecommendationPerformance() async {
    try {
      final service = RuleAccuracyService(database: _db);

      // 平行載入三組資料
      final results = await Future.wait([
        service.getOverallPerformanceStats(),
        service.getStockValidationRecords(limit: 30),
        service.getAllRuleStats(),
      ]);

      final stats = results[0] as OverallPerformanceStats;
      final records = results[1] as List<StockValidationRecord>;
      final allRules = results[2] as List<RuleStats>;

      // 門檻：至少 5 筆驗證資料
      if (stats.totalCount < 5) return null;

      // 近 30 筆勝負序列
      final recentResults = records
          .where((r) => r.isSuccess != null)
          .take(30)
          .map((r) => r.isSuccess!)
          .toList();

      // Top 3 規則（門檻：至少 5 次觸發）
      final qualifiedRules = allRules.where((r) => r.triggerCount >= 5).toList()
        ..sort((a, b) => b.hitRate.compareTo(a.hitRate));
      final topRules = qualifiedRules
          .take(3)
          .map(
            (r) => TopRule(
              ruleId: r.ruleId,
              winRate: r.hitRate,
              avgReturn: r.avgReturn,
              triggerCount: r.triggerCount,
            ),
          )
          .toList();

      return RecommendationPerformance(
        recentResults: recentResults,
        winRate: stats.winRate,
        avgReturn: stats.avgReturn,
        totalCount: stats.totalCount,
        topRules: topRules,
      );
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入推薦績效摘要失敗: $e');
      return null;
    }
  }

  /// 載入籌碼異動偵測結果（依市場分組）
  Future<Map<String, List<ChipAnomaly>>> _loadChipAnomalies(
    DateTime date,
  ) async {
    try {
      final service = ChipAnomalyService(database: _db);
      return await service.detectAnomaliesByMarket(date);
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入籌碼異動失敗: $e');
      return {};
    }
  }

  /// 載入產業表現（依市場分組，TWSE + TPEx 各自查詢）
  Future<Map<String, List<IndustrySummary>>> _loadIndustrySummaryByMarket(
    DateTime date, {
    DateTime? fallbackDate,
  }) async {
    try {
      final result = <String, List<IndustrySummary>>{};

      for (final market in ['TWSE', 'TPEx']) {
        var data = await _db.getIndustrySummaryByMarket(date, market);

        if (data.isEmpty && fallbackDate != null) {
          data = await _db.getIndustrySummaryByMarket(fallbackDate, market);
        }

        if (data.isNotEmpty) {
          result[market] = _mergeNormalizedIndustries(data);
        }
      }

      return result;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入產業表現失敗: $e');
      return {};
    }
  }

  /// 正規化產業名稱並合併重複項（FinMind API 命名不一致）
  ///
  /// 例如「其他電子業」與「其他電子類」會被合併為同一筆。
  /// 合併後重新排序（avgChangePct DESC）。
  static List<IndustrySummary> _mergeNormalizedIndustries(
    List<Map<String, dynamic>> rows,
  ) {
    final merged = <String, _MutableIndustry>{};

    for (final row in rows) {
      final rawName = row['industry'] as String;
      final canonical = IndustryNames.normalize(rawName);
      final entry = merged.putIfAbsent(canonical, _MutableIndustry.new);
      entry.addRow(row);
    }

    final list = merged.entries.map((e) => e.value.toSummary(e.key)).toList()
      ..sort((a, b) => b.avgChangePct.compareTo(a.avgChangePct));
    return list;
  }
}

/// 可變的產業聚合器（用於合併重複命名的產業）
class _MutableIndustry {
  int stockCount = 0;
  double _changePctSum = 0;
  int _changePctCount = 0;
  int advance = 0;
  int decline = 0;

  void addRow(Map<String, dynamic> row) {
    final count = row['stockCount'] as int;
    stockCount += count;
    _changePctSum += (row['avgChangePct'] as double) * count;
    _changePctCount += count;
    advance += row['advance'] as int;
    decline += row['decline'] as int;
  }

  /// 加權平均漲跌幅
  double get avgChangePct =>
      _changePctCount > 0 ? _changePctSum / _changePctCount : 0;

  IndustrySummary toSummary(String industry) => IndustrySummary(
    industry: industry,
    stockCount: stockCount,
    avgChangePct: avgChangePct,
    advance: advance,
    decline: decline,
  );
}

// ==================================================
// Provider
// ==================================================

final marketOverviewProvider =
    NotifierProvider<MarketOverviewNotifier, MarketOverviewState>(
      MarketOverviewNotifier.new,
    );
