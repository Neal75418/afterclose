import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/market_index_names.dart';
export 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
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

/// 大盤總覽狀態
class MarketOverviewState {
  const MarketOverviewState({
    this.indices = const [],
    this.indexHistory = const {},
    this.advanceDecline = const AdvanceDecline(),
    this.institutional = const InstitutionalTotals(),
    this.margin = const MarginTradingTotals(),
    this.isLoading = false,
    this.error,
  });

  final List<TwseMarketIndex> indices;

  /// 指數名稱 → 近 30 日收盤值列表（供走勢圖使用）
  final Map<String, List<double>> indexHistory;
  final AdvanceDecline advanceDecline;
  final InstitutionalTotals institutional;
  final MarginTradingTotals margin;
  final bool isLoading;
  final String? error;

  /// 是否有任何有效資料
  bool get hasData => indices.isNotEmpty || advanceDecline.total > 0;

  MarketOverviewState copyWith({
    List<TwseMarketIndex>? indices,
    Map<String, List<double>>? indexHistory,
    AdvanceDecline? advanceDecline,
    InstitutionalTotals? institutional,
    MarginTradingTotals? margin,
    bool? isLoading,
    String? error,
  }) {
    return MarketOverviewState(
      indices: indices ?? this.indices,
      indexHistory: indexHistory ?? this.indexHistory,
      advanceDecline: advanceDecline ?? this.advanceDecline,
      institutional: institutional ?? this.institutional,
      margin: margin ?? this.margin,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================================================
// Market Overview Notifier
// ==================================================

class MarketOverviewNotifier extends StateNotifier<MarketOverviewState> {
  MarketOverviewNotifier(this._ref) : super(const MarketOverviewState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  TwseClient get _twse => _ref.read(twseClientProvider);

  /// 載入大盤總覽資料
  ///
  /// 平行執行 API 呼叫與 DB 彙總查詢，任一失敗不影響其他。
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 取得最新資料日期
      final dataDate = await _db.getLatestDataDate() ?? DateTime.now();

      // 平行載入所有資料（各 _load* 方法內部已處理錯誤）
      final results = await Future.wait([
        _loadIndices(), // [0] List<TwseMarketIndex>
        _loadAdvanceDecline(dataDate), // [1] AdvanceDecline
        _loadInstitutionalTotals(dataDate), // [2] InstitutionalTotals
        _loadMarginTotals(dataDate), // [3] MarginTradingTotals
        _loadIndexHistory(), // [4] Map<String, List<double>>
      ]);

      if (!mounted) return;

      state = MarketOverviewState(
        indices: results[0] as List<TwseMarketIndex>,
        advanceDecline: results[1] as AdvanceDecline,
        institutional: results[2] as InstitutionalTotals,
        margin: results[3] as MarginTradingTotals,
        indexHistory: results[4] as Map<String, List<double>>,
      );
    } catch (e) {
      // getLatestDataDate() 可能拋出例外
      AppLogger.error('MarketOverview', '載入大盤總覽失敗', e);
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<List<TwseMarketIndex>> _loadIndices() async {
    try {
      final indices = await _twse.getMarketIndices();
      // 精確名稱匹配，僅保留 Dashboard 需要的 4 個重點指數
      final targetNames = MarketIndexNames.dashboardIndices.toSet();
      return indices.where((idx) => targetNames.contains(idx.name)).toList();
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入大盤指數失敗: $e');
      return [];
    }
  }

  /// 從 DB 載入近 30 日指數歷史（供走勢圖使用）
  Future<Map<String, List<double>>> _loadIndexHistory() async {
    try {
      // 查詢 4 個重點指數的歷史
      const indexNames = MarketIndexNames.dashboardIndices;

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

  Future<InstitutionalTotals> _loadInstitutionalTotals(DateTime date) async {
    try {
      final totals = await _db.getInstitutionalTotals(date);
      return InstitutionalTotals(
        foreignNet: totals['foreignNet'] ?? 0,
        trustNet: totals['trustNet'] ?? 0,
        dealerNet: totals['dealerNet'] ?? 0,
        totalNet: totals['totalNet'] ?? 0,
      );
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入法人總額失敗: $e');
      return const InstitutionalTotals();
    }
  }

  Future<MarginTradingTotals> _loadMarginTotals(DateTime date) async {
    try {
      final totals = await _db.getMarginTradingTotals(date);
      return MarginTradingTotals(
        marginBalance: totals['marginBalance'] ?? 0,
        marginChange: totals['marginChange'] ?? 0,
        shortBalance: totals['shortBalance'] ?? 0,
        shortChange: totals['shortChange'] ?? 0,
      );
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入融資融券總額失敗: $e');
      return const MarginTradingTotals();
    }
  }
}

// ==================================================
// Provider
// ==================================================

final marketOverviewProvider =
    StateNotifierProvider<MarketOverviewNotifier, MarketOverviewState>((ref) {
      return MarketOverviewNotifier(ref);
    });
