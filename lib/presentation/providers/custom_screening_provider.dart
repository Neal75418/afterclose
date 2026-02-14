import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/data/repositories/screening_repository.dart';
import 'package:afterclose/domain/services/screening_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/core/constants/pagination.dart';
import 'package:afterclose/presentation/providers/scan_provider.dart';

// ==================================================
// State
// ==================================================

class CustomScreeningState {
  const CustomScreeningState({
    this.conditions = const [],
    this.savedStrategies = const [],
    this.result,
    this.stocks = const [],
    this.isExecuting = false,
    this.isLoadingStrategies = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  final List<ScreeningCondition> conditions;
  final List<ScreeningStrategy> savedStrategies;
  final ScreeningResult? result;
  final List<ScanStockItem> stocks;
  final bool isExecuting;
  final bool isLoadingStrategies;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  CustomScreeningState copyWith({
    List<ScreeningCondition>? conditions,
    List<ScreeningStrategy>? savedStrategies,
    ScreeningResult? result,
    bool clearResult = false,
    List<ScanStockItem>? stocks,
    bool? isExecuting,
    bool? isLoadingStrategies,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return CustomScreeningState(
      conditions: conditions ?? this.conditions,
      savedStrategies: savedStrategies ?? this.savedStrategies,
      result: clearResult ? null : (result ?? this.result),
      stocks: stocks ?? this.stocks,
      isExecuting: isExecuting ?? this.isExecuting,
      isLoadingStrategies: isLoadingStrategies ?? this.isLoadingStrategies,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error,
    );
  }
}

// ==================================================
// Notifier
// ==================================================

class CustomScreeningNotifier extends Notifier<CustomScreeningState> {
  var _active = true;

  @override
  CustomScreeningState build() {
    _active = true;
    ref.onDispose(() => _active = false);
    return const CustomScreeningState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);
  AnalysisRepository get _analysisRepo => ref.read(analysisRepositoryProvider);

  // 暫存篩選結果的全部 symbol，供分頁使用
  List<String> _allResultSymbols = [];
  Set<String> _watchlistSymbols = {};
  DateContext? _dateCtx;

  // ==================================================
  // 條件管理
  // ==================================================

  void addCondition(ScreeningCondition condition) {
    state = state.copyWith(
      conditions: [...state.conditions, condition],
      clearResult: true,
      stocks: [],
    );
  }

  void updateCondition(int index, ScreeningCondition condition) {
    final updated = List<ScreeningCondition>.from(state.conditions);
    updated[index] = condition;
    state = state.copyWith(conditions: updated, clearResult: true, stocks: []);
  }

  void removeCondition(int index) {
    final updated = List<ScreeningCondition>.from(state.conditions);
    updated.removeAt(index);
    state = state.copyWith(conditions: updated, clearResult: true, stocks: []);
  }

  void clearConditions() {
    state = state.copyWith(conditions: [], clearResult: true, stocks: []);
  }

  // ==================================================
  // 策略 CRUD
  // ==================================================

  Future<void> loadSavedStrategies() async {
    state = state.copyWith(isLoadingStrategies: true);
    try {
      final entries = await _db.getAllScreeningStrategies();
      final strategies = entries.map((e) {
        return ScreeningStrategy(
          id: e.id,
          name: e.name,
          conditions: ScreeningStrategy.conditionsFromJson(e.conditionsJson),
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
        );
      }).toList();
      if (_active) {
        state = state.copyWith(
          savedStrategies: strategies,
          isLoadingStrategies: false,
        );
      }
    } catch (e) {
      AppLogger.error('CustomScreening', '載入策略失敗', e);
      if (_active) {
        state = state.copyWith(isLoadingStrategies: false);
      }
    }
  }

  /// 儲存目前條件為策略，回傳是否成功
  Future<bool> saveStrategy(String name) async {
    if (state.conditions.isEmpty) return false;
    try {
      final json = ScreeningStrategy.conditionsToJson(state.conditions);
      await _db.insertScreeningStrategy(
        ScreeningStrategyTableCompanion.insert(
          name: name,
          conditionsJson: json,
        ),
      );
      await loadSavedStrategies();
      return true;
    } catch (e) {
      AppLogger.error('CustomScreening', '儲存策略失敗', e);
      return false;
    }
  }

  /// 刪除策略，回傳是否成功
  Future<bool> deleteStrategy(int id) async {
    try {
      await _db.deleteScreeningStrategy(id);
      await loadSavedStrategies();
      return true;
    } catch (e) {
      AppLogger.error('CustomScreening', '刪除策略失敗', e);
      return false;
    }
  }

  void loadStrategy(ScreeningStrategy strategy) {
    state = state.copyWith(
      conditions: List.from(strategy.conditions),
      clearResult: true,
      stocks: [],
    );
  }

  // ==================================================
  // 篩選執行
  // ==================================================

  Future<void> executeScreening() async {
    if (state.conditions.isEmpty) return;

    state = state.copyWith(
      isExecuting: true,
      clearError: true,
      stocks: [],
      clearResult: true,
    );

    try {
      // 找到有資料的日期
      final targetDate = await _analysisRepo.findLatestAnalysisDate();
      if (targetDate == null) {
        if (_active) {
          state = state.copyWith(isExecuting: false, error: '找不到分析資料');
        }
        return;
      }

      _dateCtx = DateContext.forDate(targetDate);

      final service = ScreeningService(
        repository: ScreeningRepository(database: _db),
      );
      final result = await service.execute(
        conditions: state.conditions,
        targetDate: targetDate,
      );

      if (!_active) return;

      _allResultSymbols = result.symbols;

      // 載入 watchlist
      final watchlist = await _db.getWatchlist();
      _watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // 載入第一頁
      final firstPage = await _loadStockItems(
        _allResultSymbols.take(kPageSize).toList(),
      );

      if (_active) {
        state = state.copyWith(
          result: result,
          stocks: firstPage,
          isExecuting: false,
          hasMore: _allResultSymbols.length > kPageSize,
        );
      }
    } catch (e) {
      AppLogger.error('CustomScreening', '篩選執行失敗', e);
      if (_active) {
        state = state.copyWith(isExecuting: false, error: e.toString());
      }
    }
  }

  /// 載入更多（無限滾動）
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _dateCtx == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentLen = state.stocks.length;
      final nextSymbols = _allResultSymbols
          .skip(currentLen)
          .take(kPageSize)
          .toList();

      if (nextSymbols.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final newItems = await _loadStockItems(nextSymbols);

      if (!_active) return;
      state = state.copyWith(
        stocks: [...state.stocks, ...newItems],
        isLoadingMore: false,
        hasMore: (currentLen + newItems.length) < _allResultSymbols.length,
      );
    } catch (e) {
      if (!_active) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ==================================================
  // 私有輔助
  // ==================================================

  Future<List<ScanStockItem>> _loadStockItems(List<String> symbols) async {
    final dateCtx = _dateCtx;
    if (symbols.isEmpty || dateCtx == null) return [];

    final data = await _cachedDb.loadScanData(
      symbols: symbols,
      analysisDate: dateCtx.today,
      historyStart: dateCtx.historyStart,
    );

    final stocksMap = data.stocks;
    final latestPricesMap = data.latestPrices;
    final reasonsMap = data.reasons;
    final priceHistoriesMap = data.priceHistories;

    // 批次載入分析結果取得 score
    final analyses = await _db.getAnalysesBatch(symbols, dateCtx.today);

    final priceChanges = PriceCalculator.calculatePriceChangesBatch(
      priceHistoriesMap,
      latestPricesMap,
    );

    return symbols.map((symbol) {
      final latestPrice = latestPricesMap[symbol];
      final priceHistory = priceHistoriesMap[symbol];
      final analysis = analyses[symbol];

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

      return ScanStockItem(
        symbol: symbol,
        score: analysis?.score ?? 0,
        stockName: stocksMap[symbol]?.name,
        market: stocksMap[symbol]?.market,
        industry: stocksMap[symbol]?.industry,
        latestClose: latestPrice?.close,
        priceChange: priceChanges[symbol],
        volume: latestPrice?.volume,
        trendState: analysis?.trendState,
        reasons: reasonsMap[symbol] ?? [],
        isInWatchlist: _watchlistSymbols.contains(symbol),
        recentPrices: recentPrices,
      );
    }).toList();
  }
}

// ==================================================
// Provider
// ==================================================

final customScreeningProvider =
    NotifierProvider<CustomScreeningNotifier, CustomScreeningState>(
      CustomScreeningNotifier.new,
    );
