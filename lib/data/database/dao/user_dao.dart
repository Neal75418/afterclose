import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/dao/batch_query_mixin.dart';
import 'package:afterclose/data/database/tables/user_tables.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';
import 'package:afterclose/data/database/tables/daily_price.drift.dart';
import 'package:afterclose/core/constants/rule_params_alert.dart';
import 'package:afterclose/domain/services/alert_evaluation_service.dart';

/// 使用者相關資料存取：自選股、設定、更新紀錄、股價提醒
mixin UserDaoMixin on $AppDatabase {
  // ==================================================
  // 自選股操作
  // ==================================================

  /// 取得所有自選股
  Future<List<WatchlistEntry>> getWatchlist() {
    return (select(
      watchlist,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// 加入自選股
  Future<void> addToWatchlist(String symbol) {
    return into(watchlist).insert(
      WatchlistCompanion.insert(symbol: symbol),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 從自選股移除
  Future<void> removeFromWatchlist(String symbol) {
    return (delete(watchlist)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// 檢查股票是否在自選股中
  Future<bool> isInWatchlist(String symbol) async {
    final result = await (select(
      watchlist,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
    return result != null;
  }

  /// 取得單一自選股條目（含 createdAt 時間戳）
  Future<WatchlistEntry?> getWatchlistEntry(String symbol) {
    return (select(
      watchlist,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  // ==================================================
  // 應用程式設定操作（Token 儲存用）
  // ==================================================

  /// 取得設定值
  Future<String?> getSetting(String key) async {
    final result = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  /// 設定設定值
  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// 刪除設定
  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  // ==================================================
  // 更新執行記錄操作
  // ==================================================

  /// 建立新的更新執行記錄
  Future<int> createUpdateRun(DateTime runDate, String status) {
    return into(
      updateRun,
    ).insert(UpdateRunCompanion.insert(runDate: runDate, status: status));
  }

  /// 更新執行狀態
  Future<void> finishUpdateRun(
    int id,
    String status, {
    String? message,
    DateTime? now,
  }) {
    return (update(updateRun)..where((t) => t.id.equals(id))).write(
      UpdateRunCompanion(
        finishedAt: Value(now ?? DateTime.now()),
        status: Value(status),
        message: Value(message),
      ),
    );
  }

  /// 更新執行記錄的資料日期
  ///
  /// 用於日期校正後更新 runDate，確保記錄的是實際資料日期
  Future<void> updateRunDate(int id, DateTime runDate) {
    return (update(updateRun)..where((t) => t.id.equals(id))).write(
      UpdateRunCompanion(runDate: Value(runDate)),
    );
  }

  /// 取得最新的更新執行記錄
  Future<UpdateRunEntry?> getLatestUpdateRun() {
    return (select(updateRun)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得最近 N 筆更新執行記錄（包含 SUCCESS / PARTIAL / FAILED）
  ///
  /// UI 顯示「更新紀錄」歷史列表用，user tap Today 上的 timestamp 帶出。
  /// 依 id DESC 排（最新的在前）。
  Future<List<UpdateRunEntry>> getRecentUpdateRuns({int limit = 30}) {
    return (select(updateRun)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
  }

  // ==================================================
  // 股價提醒操作
  // ==================================================

  /// 取得所有啟用中的股價提醒
  Future<List<PriceAlertEntry>> getActiveAlerts() {
    return (select(priceAlert)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 取得所有股價提醒（包含啟用與停用）
  Future<List<PriceAlertEntry>> getAllAlerts() {
    return (select(
      priceAlert,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// 取得股票的所有提醒
  Future<List<PriceAlertEntry>> getAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 取得股票的啟用中提醒
  Future<List<PriceAlertEntry>> getActiveAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 依 ID 取得單一提醒
  Future<PriceAlertEntry?> getAlertById(int id) {
    return (select(
      priceAlert,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 建立新的股價提醒
  Future<int> createPriceAlert({
    required String symbol,
    required String alertType,
    required double targetValue,
    String? note,
  }) {
    return into(priceAlert).insert(
      PriceAlertCompanion.insert(
        symbol: symbol,
        alertType: alertType,
        targetValue: targetValue,
        note: Value(note),
      ),
    );
  }

  /// 更新股價提醒
  Future<void> updatePriceAlert(int id, PriceAlertCompanion entry) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(entry);
  }

  /// 停用股價提醒（標記為已觸發）
  Future<void> triggerAlert(int id, {DateTime? now}) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(
      PriceAlertCompanion(
        isActive: const Value(false),
        triggeredAt: Value(now ?? DateTime.now()),
      ),
    );
  }

  /// 刪除股價提醒
  Future<void> deletePriceAlert(int id) {
    return (delete(priceAlert)..where((t) => t.id.equals(id))).go();
  }

  /// 刪除股票的所有提醒
  Future<void> deleteAlertsForSymbol(String symbol) {
    return (delete(priceAlert)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// 比對提醒與當前價格，回傳已觸發的提醒
  ///
  /// [evaluationService] 可由呼叫端注入，避免 DAO 直接建立 domain service。
  Future<List<PriceAlertEntry>> checkAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges, {
    AlertEvaluationService? evaluationService,
  }) async {
    final activeAlerts = await getActiveAlerts();
    if (activeAlerts.isEmpty) return [];

    final symbols = activeAlerts.map((a) => a.symbol).toSet().toList();

    // 統一時間基準，避免各 helper 各自呼叫 DateTime.now()
    final now = DateTime.now();

    // Data fetching stays in DAO (needs DB access)
    final volumeDataMap = await _fetchVolumeDataForAlerts(symbols, now);
    final priceHistoryMap = await _fetchPriceHistoryForAlerts(symbols, now);
    final indicatorDataMap = await _fetchIndicatorDataForAlerts(symbols, now);

    // 以批次查詢取代逐筆 N+1 模式，避免 N 個 symbol 產生 2N 次 DB 往返
    final disposalSymbols = await _fetchDisposalSymbolsBatch(symbols);
    final warningSymbols = await _fetchWarningSymbolsBatch(symbols);

    // Phase 3: 按需查詢進階警示所需的基本面/籌碼資料
    final alertTypes = activeAlerts.map((a) => a.alertType).toSet();
    final needsFundamental = alertTypes.any(
      (t) => const {
        'REVENUE_YOY_SURGE',
        'HIGH_DIVIDEND_YIELD',
        'PE_UNDERVALUED',
      }.contains(t),
    );
    final needsInsider = alertTypes.any(
      (t) => const {
        'INSIDER_SELLING',
        'INSIDER_BUYING',
        'HIGH_PLEDGE_RATIO',
      }.contains(t),
    );

    final revenueYoyMap = <String, double>{};
    final dividendYieldMap = <String, double>{};
    final peRatioMap = <String, double>{};
    final insiderChangeMap = <String, double>{};
    final pledgeRatioMap = <String, double>{};

    if (needsFundamental) {
      await _fetchFundamentalDataForAlerts(
        symbols,
        revenueYoyMap: revenueYoyMap,
        dividendYieldMap: dividendYieldMap,
        peRatioMap: peRatioMap,
      );
    }
    if (needsInsider) {
      await _fetchInsiderDataForAlerts(
        symbols,
        insiderChangeMap: insiderChangeMap,
        pledgeRatioMap: pledgeRatioMap,
      );
    }

    // Delegate evaluation to domain service (prefer injection from caller)
    final service = evaluationService ?? AlertEvaluationService();
    final result = service.evaluateAlerts(
      activeAlerts,
      AlertEvaluationContext(
        currentPrices: currentPrices,
        priceChanges: priceChanges,
        volumeDataMap: volumeDataMap,
        priceHistoryMap: priceHistoryMap,
        indicatorDataMap: indicatorDataMap,
        warningSymbols: warningSymbols,
        disposalSymbols: disposalSymbols,
        revenueYoyMap: revenueYoyMap,
        dividendYieldMap: dividendYieldMap,
        peRatioMap: peRatioMap,
        insiderChangeMap: insiderChangeMap,
        pledgeRatioMap: pledgeRatioMap,
      ),
    );

    // 自動停用未實作的警示類型（舊版 DB 殘留資料）
    for (final id in result.unimplementedIds) {
      await updatePriceAlert(
        id,
        const PriceAlertCompanion(isActive: Value(false)),
      );
    }

    return result.triggered;
  }

  // ==================================================
  // 警示檢查輔助方法 - Batch 1: 成交量警示
  // ==================================================

  /// 批次查詢成交量資料（最近 20 天）
  Future<Map<String, List<DailyPriceEntry>>> _fetchVolumeDataForAlerts(
    List<String> symbols,
    DateTime endDate,
  ) async {
    if (symbols.isEmpty) return {};
    final startDate = endDate.subtract(
      const Duration(days: AlertParams.volumeDataLookbackDays),
    );

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();
    return BatchQueryHelper.groupBySymbol(results, (entry) => entry.symbol);
  }

  /// 批次查詢 52 週價格歷史
  Future<Map<String, List<DailyPriceEntry>>> _fetchPriceHistoryForAlerts(
    List<String> symbols,
    DateTime endDate,
  ) async {
    if (symbols.isEmpty) return {};
    final startDate = endDate.subtract(
      const Duration(days: AlertParams.week52LookbackDays),
    );

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();
    return BatchQueryHelper.groupBySymbol(results, (entry) => entry.symbol);
  }

  /// 批次查詢技術指標資料（最近 30 天，用於計算 RSI 和 KD）
  Future<Map<String, List<DailyPriceEntry>>> _fetchIndicatorDataForAlerts(
    List<String> symbols,
    DateTime endDate,
  ) async {
    if (symbols.isEmpty) return {};
    final startDate = endDate.subtract(
      const Duration(days: AlertParams.indicatorDataLookbackDays),
    );

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();
    return BatchQueryHelper.groupBySymbol(results, (entry) => entry.symbol);
  }

  /// 批次取得處置股代碼（批次查詢，供警示檢查使用）
  Future<Set<String>> _fetchDisposalSymbolsBatch(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.equals('DISPOSAL')))
            .get();
    return results.map((r) => r.symbol).toSet();
  }

  /// 批次取得有警示（不含處置）的股票代碼（批次查詢，供警示檢查使用）
  Future<Set<String>> _fetchWarningSymbolsBatch(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.isNotValue('DISPOSAL')))
            .get();
    return results.map((r) => r.symbol).toSet();
  }

  /// 取得指定股票的所有有效警示（不含處置）
  Future<List<TradingWarningEntry>> getActiveWarningsForSymbol(
    String symbol,
  ) async {
    return (select(tradingWarning)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.warningType.isNotValue('DISPOSAL')))
        .get();
  }

  /// 取得指定股票的處置警示
  Future<List<TradingWarningEntry>> getDisposalWarningsForSymbol(
    String symbol,
  ) async {
    return (select(tradingWarning)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.warningType.equals('DISPOSAL')))
        .get();
  }

  // ==================================================
  // 進階警示資料查詢（Phase 3）
  // ==================================================

  /// 批次查詢基本面資料：營收年增率、殖利率、本益比
  Future<void> _fetchFundamentalDataForAlerts(
    List<String> symbols, {
    required Map<String, double> revenueYoyMap,
    required Map<String, double> dividendYieldMap,
    required Map<String, double> peRatioMap,
  }) async {
    // 營收年增率：取最近 3 個月的營收資料（每 symbol 只用最新一筆）
    final cutoffDate = DateTime.now().subtract(const Duration(days: 120));
    final revenues =
        await (select(monthlyRevenue)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.isBiggerOrEqualValue(cutoffDate))
              ..orderBy([
                (t) => OrderingTerm.desc(t.revenueYear),
                (t) => OrderingTerm.desc(t.revenueMonth),
              ]))
            .get();

    // 每個 symbol 只取最新一筆
    final seenRevenue = <String>{};
    for (final r in revenues) {
      if (!seenRevenue.contains(r.symbol) && r.yoyGrowth != null) {
        revenueYoyMap[r.symbol] = r.yoyGrowth!;
        seenRevenue.add(r.symbol);
      }
    }

    // 殖利率和本益比：從 stockValuation 表取最近 30 天資料
    final valCutoff = DateTime.now().subtract(const Duration(days: 30));
    final valuations =
        await (select(stockValuation)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.isBiggerOrEqualValue(valCutoff))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    final seenValuation = <String>{};
    for (final v in valuations) {
      if (!seenValuation.contains(v.symbol)) {
        if (v.dividendYield != null && v.dividendYield! > 0) {
          dividendYieldMap[v.symbol] = v.dividendYield!;
        }
        if (v.per != null && v.per! > 0) {
          peRatioMap[v.symbol] = v.per!;
        }
        seenValuation.add(v.symbol);
      }
    }
  }

  /// 批次查詢籌碼資料：董監持股變動、質押比例
  Future<void> _fetchInsiderDataForAlerts(
    List<String> symbols, {
    required Map<String, double> insiderChangeMap,
    required Map<String, double> pledgeRatioMap,
  }) async {
    // 董監持股：取最近 6 個月的資料（只需最新一筆的 sharesChange）
    final holdingCutoff = DateTime.now().subtract(const Duration(days: 180));
    final holdings =
        await (select(insiderHolding)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.isBiggerOrEqualValue(holdingCutoff))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    // 按 symbol 分組，取最新兩筆算差異
    final grouped = <String, List<InsiderHoldingEntry>>{};
    for (final h in holdings) {
      (grouped[h.symbol] ??= []).add(h);
    }
    for (final entry in grouped.entries) {
      final list = entry.value;
      if (list.isNotEmpty && list[0].sharesChange != null) {
        insiderChangeMap[entry.key] = list[0].sharesChange!;
      }
    }

    // 質押比例
    for (final entry in grouped.entries) {
      if (entry.value.isNotEmpty) {
        final latest = entry.value.first;
        if (latest.pledgeRatio != null) {
          pledgeRatioMap[entry.key] = latest.pledgeRatio!;
        }
      }
    }
  }
}
