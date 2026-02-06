import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/market_index_names.dart';
export 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
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

/// 成交額統計（元）
class TradingTurnover {
  const TradingTurnover({this.totalTurnover = 0});

  final double totalTurnover; // 單位：元
}

/// 大盤總覽狀態
class MarketOverviewState {
  const MarketOverviewState({
    this.indices = const [],
    this.indexHistory = const {},
    this.advanceDecline = const AdvanceDecline(),
    this.institutional = const InstitutionalTotals(),
    this.margin = const MarginTradingTotals(),
    // 新增：依市場分組的統計（預設空 Map）
    this.advanceDeclineByMarket = const {},
    this.institutionalByMarket = const {},
    this.marginByMarket = const {},
    this.turnoverByMarket = const {},
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
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dataDate: dataDate ?? this.dataDate,
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
  TpexClient get _tpex => _ref.read(tpexClientProvider);

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
        _loadAdvanceDeclineByMarket(
          dataDate,
        ), // [5] Map<String, AdvanceDecline>
        _loadInstitutionalByMarket(
          dataDate,
        ), // [6] Map<String, InstitutionalTotals>
        _loadMarginByMarket(dataDate), // [7] Map<String, MarginTradingTotals>
        _loadTurnoverByMarket(dataDate), // [8] Map<String, TradingTurnover>
      ]);

      if (!mounted) return;

      state = MarketOverviewState(
        indices: results[0] as List<TwseMarketIndex>,
        advanceDecline: results[1] as AdvanceDecline,
        institutional: results[2] as InstitutionalTotals,
        margin: results[3] as MarginTradingTotals,
        indexHistory: results[4] as Map<String, List<double>>,
        advanceDeclineByMarket: results[5] as Map<String, AdvanceDecline>,
        institutionalByMarket: results[6] as Map<String, InstitutionalTotals>,
        marginByMarket: results[7] as Map<String, MarginTradingTotals>,
        turnoverByMarket: results[8] as Map<String, TradingTurnover>,
        dataDate: dataDate,
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

  /// 載入法人買賣超金額總額（上市+上櫃合計）
  ///
  /// 使用 TWSE/TPEX 的法人買賣金額統計 API
  Future<InstitutionalTotals> _loadInstitutionalTotals(DateTime date) async {
    try {
      // 平行呼叫 TWSE 和 TPEX API
      final futures = await Future.wait([
        _twse.getInstitutionalAmounts(date: date),
        _tpex.getInstitutionalAmounts(date: date),
      ]);

      final twseData = futures[0] as TwseInstitutionalAmounts?;
      final tpexData = futures[1] as TpexInstitutionalAmounts?;

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

  /// 載入漲跌家數（依市場分組）
  Future<Map<String, AdvanceDecline>> _loadAdvanceDeclineByMarket(
    DateTime date,
  ) async {
    try {
      final data = await _db.getAdvanceDeclineCountsByMarket(date);
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
  /// 使用 TWSE/TPEX 的法人買賣金額統計 API，直接取得市場總計金額（元）
  Future<Map<String, InstitutionalTotals>> _loadInstitutionalByMarket(
    DateTime date,
  ) async {
    try {
      final results = <String, InstitutionalTotals>{};

      // 平行呼叫 TWSE 和 TPEX API
      final futures = await Future.wait([
        _twse.getInstitutionalAmounts(date: date),
        _tpex.getInstitutionalAmounts(date: date),
      ]);

      final twseData = futures[0] as TwseInstitutionalAmounts?;
      final tpexData = futures[1] as TpexInstitutionalAmounts?;

      if (twseData != null) {
        results['TWSE'] = InstitutionalTotals(
          foreignNet: twseData.foreignNet,
          trustNet: twseData.trustNet,
          dealerNet: twseData.dealerNet,
          totalNet: twseData.totalNet,
        );
      }

      if (tpexData != null) {
        results['TPEx'] = InstitutionalTotals(
          foreignNet: tpexData.foreignNet,
          trustNet: tpexData.trustNet,
          dealerNet: tpexData.dealerNet,
          totalNet: tpexData.totalNet,
        );
      }

      return results;
    } catch (e) {
      AppLogger.warning('MarketOverview', '載入分市場法人總額失敗: $e');
      return {};
    }
  }

  /// 載入融資融券（依市場分組）
  Future<Map<String, MarginTradingTotals>> _loadMarginByMarket(
    DateTime date,
  ) async {
    try {
      final data = await _db.getMarginTradingTotalsByMarket(date);
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
  Future<Map<String, TradingTurnover>> _loadTurnoverByMarket(
    DateTime date,
  ) async {
    try {
      final data = await _db.getTurnoverSummaryByMarket(date);
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
}

// ==================================================
// Provider
// ==================================================

final marketOverviewProvider =
    StateNotifierProvider<MarketOverviewNotifier, MarketOverviewState>((ref) {
      return MarketOverviewNotifier(ref);
    });
