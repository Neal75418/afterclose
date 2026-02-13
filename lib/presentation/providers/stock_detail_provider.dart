import 'dart:async';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';
import 'package:afterclose/presentation/mappers/summary_localizer.dart';
import 'package:afterclose/domain/services/personalization_service.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_state.dart';
import 'package:afterclose/presentation/providers/stock_fundamentals_loader.dart';
import 'package:afterclose/presentation/providers/stock_chip_loader.dart';

// Re-export state classes for consumers
export 'package:afterclose/presentation/providers/stock_detail_state.dart';

// ==================================================
// 股票詳情 Notifier
// ==================================================

class StockDetailNotifier extends StateNotifier<StockDetailState> {
  StockDetailNotifier(this._ref, this._symbol)
    : _fundamentalsLoader = StockFundamentalsLoader(
        db: _ref.read(databaseProvider),
        finMind: _ref.read(finMindClientProvider),
      ),
      _chipLoader = StockChipLoader(
        db: _ref.read(databaseProvider),
        finMind: _ref.read(finMindClientProvider),
        insiderRepo: _ref.read(insiderRepositoryProvider),
      ),
      super(const StockDetailState());

  final Ref _ref;
  final String _symbol;
  final StockFundamentalsLoader _fundamentalsLoader;
  final StockChipLoader _chipLoader;

  AppDatabase get _db => _ref.read(databaseProvider);
  DataSyncService get _dataSyncService => _ref.read(dataSyncServiceProvider);

  /// 載入股票詳情資料
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateCtx = DateContext.withLookback(RuleParams.lookbackPrice);
      final normalizedToday = dateCtx.today;
      final startDate = dateCtx.historyStart;

      // 決定分析資料的查詢日期
      // 使用資料庫最新價格日期，確保盤前/非交易日也能顯示上次分析結果
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : normalizedToday;

      // 使用 Dart 3 Records 進行型別安全的平行載入
      final (
        stock,
        priceHistory,
        recentPrices,
        analysis,
        reasons,
        dbInstHistory,
        isInWatchlist,
      ) = await (
        _db.getStock(_symbol),
        _db.getPriceHistory(
          _symbol,
          startDate: startDate,
          endDate: normalizedToday,
        ),
        _db.getRecentPrices(_symbol, count: 2),
        _db.getAnalysis(_symbol, analysisDate),
        _db.getReasons(_symbol, analysisDate),
        _db.getInstitutionalHistory(
          _symbol,
          startDate: normalizedToday.subtract(const Duration(days: 10)),
          endDate: normalizedToday,
        ),
        _db.isInWatchlist(_symbol),
      ).wait;
      var instHistory = dbInstHistory;

      // 從最近價格提取最新與前一日（recentPrices 依日期降序排列）
      final latestPrice = recentPrices.isNotEmpty ? recentPrices.first : null;
      final previousPrice = recentPrices.length >= 2 ? recentPrices[1] : null;

      AppLogger.debug(
        'StockDetail',
        'recentPrices count=${recentPrices.length}, '
            'latest=${latestPrice?.close} (${latestPrice?.date}), '
            'prev=${previousPrice?.close} (${previousPrice?.date})',
      );

      // DB 無法人資料時從 API 取得
      var hasInstitutionalError = false;
      if (instHistory.isEmpty) {
        final apiResult = await _chipLoader.fetchInstitutionalFromApi(_symbol);
        instHistory = apiResult.data;
        hasInstitutionalError = apiResult.hasError;
      }

      // 同步資料日期 — 找到共同最新日期
      final syncResult = _dataSyncService.synchronizeDataDates(
        priceHistory,
        instHistory,
      );
      final syncedInstHistory = syncResult.institutionalHistory;
      final dataDate = syncResult.dataDate;
      final hasDataMismatch = syncResult.hasDataMismatch;

      // 使用同步後的價格確保與 dataDate 一致
      final displayPrice = syncResult.latestPrice ?? latestPrice;
      final displayPreviousPrice = findPreviousPrice(
        priceHistory,
        displayPrice,
      );

      if (hasDataMismatch) {
        AppLogger.debug(
          'StockDetail',
          'Data mismatch: using synced price '
              '${displayPrice?.close} (${displayPrice?.date}) '
              'instead of ${latestPrice?.close} (${latestPrice?.date})',
        );
      }

      // 生成 AI 智慧分析摘要
      final summaryData = const AnalysisSummaryService().generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: displayPrice,
        priceChange: PriceCalculator.calculatePriceChange(
          priceHistory,
          displayPrice,
        ),
        institutionalHistory: syncedInstHistory,
        revenueHistory: state.fundamentals.revenueHistory,
        latestPER: state.fundamentals.latestPER,
      );
      final summary = const SummaryLocalizer().localize(summaryData);

      state = state.copyWith(
        stock: stock,
        latestPrice: displayPrice,
        previousPrice: displayPreviousPrice,
        priceHistory: priceHistory,
        analysis: analysis,
        reasons: reasons,
        institutionalHistory: syncedInstHistory,
        aiSummary: summary,
        isInWatchlist: isInWatchlist,
        isLoading: false,
        hasInstitutionalError: hasInstitutionalError,
        dataDate: dataDate,
        hasDataMismatch: hasDataMismatch,
      );

      // 記錄瀏覽行為（Sprint 11 - 個人化推薦）
      unawaited(
        _ref
            .read(personalizationServiceProvider)
            .trackInteraction(
              type: InteractionType.view,
              symbol: _symbol,
              sourcePage: 'stock_detail',
            ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 切換自選股 — 同步更新全域 watchlistProvider
  Future<void> toggleWatchlist() async {
    final watchlistNotifier = _ref.read(watchlistProvider.notifier);
    final wasInWatchlist = state.isInWatchlist;

    if (wasInWatchlist) {
      await watchlistNotifier.removeStock(_symbol);
    } else {
      await watchlistNotifier.addStock(_symbol);
    }

    // 更新本地狀態
    state = state.copyWith(isInWatchlist: !wasInWatchlist);

    // 記錄自選股變更行為（Sprint 11 - 個人化推薦）
    unawaited(
      _ref
          .read(personalizationServiceProvider)
          .trackInteraction(
            type: wasInWatchlist
                ? InteractionType.removeWatchlist
                : InteractionType.addWatchlist,
            symbol: _symbol,
            sourcePage: 'stock_detail',
          ),
    );
  }

  /// 載入融資融券資料
  Future<void> loadMarginData() async {
    if (state.loading.isLoadingMargin || state.chip.marginHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMargin: true);
    final marginData = await _chipLoader.loadMarginFromApi(_symbol);
    state = state.copyWith(marginHistory: marginData, isLoadingMargin: false);
  }

  /// 載入基本面資料（營收/股利/本益比/EPS）
  Future<void> loadFundamentals() async {
    if (state.loading.isLoadingFundamentals ||
        state.fundamentals.revenueHistory.isNotEmpty ||
        state.fundamentals.dividendHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingFundamentals: true);

    try {
      final result = await _fundamentalsLoader.loadAll(_symbol);

      state = state.copyWith(
        revenueHistory: result.revenueData,
        dividendHistory: result.dividendData,
        latestPER: result.latestPER,
        epsHistory: result.epsData,
        latestQuarterMetrics: result.quarterMetrics,
        isLoadingFundamentals: false,
      );

      // 基本面載入後重新生成 AI 摘要（含營收/估值資料）
      _regenerateAiSummary(
        revenueData: result.revenueData,
        latestPER: result.latestPER,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入基本面資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingFundamentals: false);
    }
  }

  /// 載入董監持股資料
  Future<void> loadInsiderData() async {
    if (state.loading.isLoadingInsider ||
        state.chip.insiderHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingInsider: true);
    final insiderHistory = await _chipLoader.loadInsiderFromDb(_symbol);
    state = state.copyWith(
      insiderHistory: insiderHistory,
      isLoadingInsider: false,
    );
  }

  /// 載入完整籌碼分析資料
  Future<void> loadChipData() async {
    if (state.loading.isLoadingChip || state.chip.chipStrength != null) return;

    state = state.copyWith(isLoadingChip: true);

    try {
      final result = await _chipLoader.loadAllChipData(
        _symbol,
        existingInstitutional: state.chip.institutionalHistory,
        existingInsider: state.chip.insiderHistory,
      );

      state = state.copyWith(
        dayTradingHistory: result.dayTrading,
        shareholdingHistory: result.shareholding,
        marginTradingHistory: result.marginTrading,
        holdingDistribution: result.holdingDist,
        insiderHistory: result.insider.isNotEmpty ? result.insider : null,
        chipStrength: result.strength,
        isLoadingChip: false,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入籌碼分析資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingChip: false);
    }
  }

  /// 從升序價格歷史中找到 [targetPrice] 的前一筆
  @visibleForTesting
  static DailyPriceEntry? findPreviousPrice(
    List<DailyPriceEntry> history,
    DailyPriceEntry? targetPrice,
  ) {
    if (targetPrice == null || history.length < 2) return null;
    final targetDate = DateContext.normalize(targetPrice.date);
    for (var i = history.length - 1; i >= 1; i--) {
      if (DateContext.normalize(history[i].date) == targetDate) {
        return history[i - 1];
      }
    }
    return null;
  }

  /// 重新生成 AI 智慧分析摘要（含營收/估值資料）
  void _regenerateAiSummary({
    required List<FinMindRevenue> revenueData,
    required FinMindPER? latestPER,
  }) {
    final summaryData = const AnalysisSummaryService().generate(
      analysis: state.price.analysis,
      reasons: state.reasons,
      latestPrice: state.price.latestPrice,
      priceChange: state.priceChange,
      institutionalHistory: state.chip.institutionalHistory,
      revenueHistory: revenueData,
      latestPER: latestPER,
    );
    state = state.copyWith(
      aiSummary: const SummaryLocalizer().localize(summaryData),
    );
  }
}

/// 股票詳情 Provider family
/// 使用 autoDispose + keepAlive 組合：
/// - autoDispose: 無訂閱者時觸發清理
/// - keepAlive: 保留 5 分鐘快取，改善列表↔詳情切換體驗
final stockDetailProvider = StateNotifierProvider.family
    .autoDispose<StockDetailNotifier, StockDetailState, String>((ref, symbol) {
      // 保活機制：5 分鐘內返回同一頁面時使用快取
      final link = ref.keepAlive();

      // 3 分鐘後自動釋放
      final timer = Timer(const Duration(minutes: 3), () {
        try {
          link.close();
        } catch (_) {
          // Timer 可能在 dispose 邊界觸發，忽略已關閉的 link
        }
      });

      // 清理：當 Provider 真正被釋放時取消 Timer
      ref.onDispose(() {
        timer.cancel();
      });

      return StockDetailNotifier(ref, symbol);
    });

/// 規則準確度 Provider（Sprint 10）
///
/// 透過 ruleId 查詢該規則的歷史命中率和平均報酬率。
/// 若該規則觸發次數少於 5 次，返回 null（資料不足）。
final ruleAccuracyProvider = FutureProvider.family
    .autoDispose<RuleStats?, String>((ref, ruleId) async {
      final service = ref.watch(ruleAccuracyServiceProvider);
      return service.getRuleStats(ruleId);
    });

/// 主要規則準確度摘要文字 Provider
///
/// 取得股票的主要觸發規則，並返回其準確度摘要文字。
/// 例如：「命中率 65%，平均 5 日報酬 +2.3%」
final primaryRuleAccuracySummaryProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, symbol) async {
      final state = ref.watch(stockDetailProvider(symbol));
      if (state.reasons.isEmpty) return null;

      // 取得主要規則（rank = 1）
      final primaryReason = state.reasons.firstWhere(
        (r) => r.rank == 1,
        orElse: () => state.reasons.first,
      );

      final service = ref.watch(ruleAccuracyServiceProvider);
      return service.getRuleSummaryText(primaryReason.reasonType);
    });
