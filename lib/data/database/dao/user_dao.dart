part of 'package:afterclose/data/database/app_database.dart';

/// 使用者相關資料存取：自選股、設定、更新紀錄、股價提醒、選股策略
mixin _UserDaoMixin on _$AppDatabase {
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
  Future<List<PriceAlertEntry>> checkAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    final activeAlerts = await getActiveAlerts();
    final triggered = <PriceAlertEntry>[];

    // 批次預載所有資料（避免 N+1 問題）
    final symbols = activeAlerts.map((a) => a.symbol).toSet().toList();
    final volumeDataMap = await _fetchVolumeDataForAlerts(symbols);
    final priceHistoryMap = await _fetchPriceHistoryForAlerts(symbols);
    final indicatorDataMap = await _fetchIndicatorDataForAlerts(symbols);

    for (final alert in activeAlerts) {
      final currentPrice = currentPrices[alert.symbol];
      final priceChange = priceChanges[alert.symbol];

      if (currentPrice == null) continue;

      bool shouldTrigger = false;

      switch (alert.alertType) {
        case 'ABOVE':
          shouldTrigger = currentPrice >= alert.targetValue;
          break;
        case 'BELOW':
          shouldTrigger = currentPrice <= alert.targetValue;
          break;
        case 'CHANGE_PCT':
          if (priceChange != null) {
            shouldTrigger = priceChange.abs() >= alert.targetValue;
          }
          break;

        // Batch 1: Volume Alerts
        case 'VOLUME_SPIKE':
          final volumeData = volumeDataMap[alert.symbol];
          if (volumeData != null && volumeData.isNotEmpty) {
            shouldTrigger = await _checkVolumeSpike(
              volumeData,
              currentPrice,
              priceChange,
            );
          }
          break;
        case 'VOLUME_ABOVE':
          final volumeData = volumeDataMap[alert.symbol];
          if (volumeData != null && volumeData.isNotEmpty) {
            shouldTrigger = _checkVolumeAbove(
              volumeData.last,
              alert.targetValue,
            );
          }
          break;

        // Batch 2: 52-Week Alerts
        case 'WEEK_52_HIGH':
          final priceHistory = priceHistoryMap[alert.symbol];
          if (priceHistory != null && priceHistory.isNotEmpty) {
            shouldTrigger = _checkWeek52High(priceHistory, currentPrice);
          }
          break;
        case 'WEEK_52_LOW':
          final priceHistory = priceHistoryMap[alert.symbol];
          if (priceHistory != null && priceHistory.isNotEmpty) {
            shouldTrigger = _checkWeek52Low(priceHistory, currentPrice);
          }
          break;

        // Batch 3: RSI/KD Indicator Alerts
        case 'RSI_OVERBOUGHT':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkRsiOverbought(
              indicatorData,
              alert.targetValue,
            );
          }
          break;
        case 'RSI_OVERSOLD':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkRsiOversold(indicatorData, alert.targetValue);
          }
          break;
        case 'KD_GOLDEN_CROSS':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkKdGoldenCross(indicatorData);
          }
          break;
        case 'KD_DEATH_CROSS':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkKdDeathCross(indicatorData);
          }
          break;

        // Batch 4: MA Cross + Trading Warning Alerts
        case 'CROSS_ABOVE_MA':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            final maDays = alert.targetValue.toInt();
            shouldTrigger = _checkCrossAboveMa(indicatorData, maDays);
          }
          break;
        case 'CROSS_BELOW_MA':
          final indicatorData = indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            final maDays = alert.targetValue.toInt();
            shouldTrigger = _checkCrossBelowMa(indicatorData, maDays);
          }
          break;
        case 'TRADING_WARNING':
          // 警示股票：檢查是否在警示名單中
          final warnings = await getActiveWarningsForSymbol(alert.symbol);
          shouldTrigger = warnings.isNotEmpty;
          break;
        case 'TRADING_DISPOSAL':
          // 處置股票：檢查是否在處置名單中
          final warnings = await getDisposalWarningsForSymbol(alert.symbol);
          shouldTrigger = warnings.isNotEmpty;
          break;
      }

      if (shouldTrigger) {
        triggered.add(alert);
      }
    }

    return triggered;
  }

  // ==================================================
  // 警示檢查輔助方法 - Batch 1: 成交量警示
  // ==================================================

  /// 批次查詢成交量資料（最近 20 天）
  Future<Map<String, List<DailyPriceEntry>>> _fetchVolumeDataForAlerts(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final endDate = DateTime.now();
    final startDate = endDate.subtract(
      const Duration(days: 30),
    ); // 30 天確保有 20 個交易日

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 計算平均成交量（排除最新一天，計算前 20 個交易日）
  double? _calculateAverageVolume(List<DailyPriceEntry> prices) {
    if (prices.length < 2) return null; // 至少需要 2 筆資料（1 筆歷史 + 1 筆最新）

    // 排除最新一天，只計算歷史資料
    final historicalPrices = prices.sublist(0, prices.length - 1);

    final volumes = historicalPrices
        .map((p) => p.volume)
        .where((v) => v != null && v > 0)
        .map((v) => v!)
        .toList();

    if (volumes.isEmpty) return null;

    // 取最近 20 個交易日（排除今天後的）
    final recent = volumes.length > 20
        ? volumes.sublist(volumes.length - 20)
        : volumes;
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  /// 檢查成交量爆量（成交量 >= 4x 均量 且價格變動 >= 1.5%）
  Future<bool> _checkVolumeSpike(
    List<DailyPriceEntry> prices,
    double currentPrice,
    double? priceChange,
  ) async {
    if (prices.isEmpty) return false;

    final avgVolume = _calculateAverageVolume(prices);
    if (avgVolume == null) return false;

    final latestVolume = prices.last.volume;
    if (latestVolume == null || latestVolume <= 0) return false;

    // 條件 1: 成交量 >= 4x 均量
    final volumeSpike = latestVolume >= avgVolume * 4;

    // 條件 2: 價格變動 >= 1.5%
    final significantPriceChange =
        priceChange != null && priceChange.abs() >= 1.5;

    return volumeSpike && significantPriceChange;
  }

  /// 檢查成交量高於目標值
  bool _checkVolumeAbove(DailyPriceEntry price, double targetVolume) {
    final volume = price.volume;
    if (volume == null || volume <= 0) return false;
    return volume >= targetVolume;
  }

  // ==================================================
  // 警示檢查輔助方法 - Batch 2: 52 週警示
  // ==================================================

  /// 批次查詢 52 週價格歷史
  Future<Map<String, List<DailyPriceEntry>>> _fetchPriceHistoryForAlerts(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final endDate = DateTime.now();
    final startDate = endDate.subtract(
      const Duration(days: 370),
    ); // 52 週 + buffer

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 檢查是否創 52 週新高
  bool _checkWeek52High(List<DailyPriceEntry> prices, double currentPrice) {
    if (prices.isEmpty) return false;

    // 找出過去 52 週的最高價
    double? maxHigh;
    for (final price in prices) {
      if (price.high != null) {
        if (maxHigh == null || price.high! > maxHigh) {
          maxHigh = price.high;
        }
      }
    }

    if (maxHigh == null) return false;

    // 當前價格 >= 52 週最高價
    return currentPrice >= maxHigh;
  }

  /// 檢查是否創 52 週新低
  bool _checkWeek52Low(List<DailyPriceEntry> prices, double currentPrice) {
    if (prices.isEmpty) return false;

    // 找出過去 52 週的最低價
    double? minLow;
    for (final price in prices) {
      if (price.low != null) {
        if (minLow == null || price.low! < minLow) {
          minLow = price.low;
        }
      }
    }

    if (minLow == null) return false;

    // 當前價格 <= 52 週最低價
    return currentPrice <= minLow;
  }

  // ==================================================
  // 警示檢查輔助方法 - Batch 3: RSI/KD 指標警示
  // ==================================================

  /// 批次查詢技術指標資料（最近 30 天，用於計算 RSI 和 KD）
  Future<Map<String, List<DailyPriceEntry>>> _fetchIndicatorDataForAlerts(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final endDate = DateTime.now();
    final startDate = endDate.subtract(
      const Duration(days: 40),
    ); // 40 天確保有 30 個交易日

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate))
      ..where((t) => t.date.isSmallerOrEqualValue(endDate))
      ..orderBy([
        (t) => OrderingTerm.asc(t.symbol),
        (t) => OrderingTerm.asc(t.date),
      ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 檢查 RSI 超買（RSI >= 目標值，如 70）
  bool _checkRsiOverbought(List<DailyPriceEntry> prices, double targetRsi) {
    if (prices.length < 15) return false; // RSI 需要至少 15 筆資料（14 期 + 1）

    final closePrices = prices.map((p) => p.close).whereType<double>().toList();
    if (closePrices.length < 15) return false;

    // 使用 TechnicalIndicatorService 計算 RSI
    final service = TechnicalIndicatorService();
    final rsiValues = service.calculateRSI(closePrices, period: 14);

    final latestRsi = rsiValues.last;
    if (latestRsi == null) return false;

    return latestRsi >= targetRsi;
  }

  /// 檢查 RSI 超賣（RSI <= 目標值，如 30）
  bool _checkRsiOversold(List<DailyPriceEntry> prices, double targetRsi) {
    if (prices.length < 15) return false;

    final closePrices = prices.map((p) => p.close).whereType<double>().toList();
    if (closePrices.length < 15) return false;

    final service = TechnicalIndicatorService();
    final rsiValues = service.calculateRSI(closePrices, period: 14);

    final latestRsi = rsiValues.last;
    if (latestRsi == null) return false;

    return latestRsi <= targetRsi;
  }

  /// 檢查 KD 黃金交叉（K 上穿 D）
  ///
  /// 檢查最近 2 天內是否發生過黃金交叉。
  /// 簡化版本：只檢查交叉本身，不要求在低檔區。
  bool _checkKdGoldenCross(List<DailyPriceEntry> prices) {
    if (prices.length < 11) return false; // KD 需要至少 11 筆資料（9 期 + 2）

    final highs = prices.map((p) => p.high).whereType<double>().toList();
    final lows = prices.map((p) => p.low).whereType<double>().toList();
    final closes = prices.map((p) => p.close).whereType<double>().toList();

    if (highs.length < 11 || lows.length < 11 || closes.length < 11) {
      return false;
    }

    final service = TechnicalIndicatorService();
    final kd = service.calculateKD(highs, lows, closes, kPeriod: 9, dPeriod: 3);

    if (kd.k.length < 2 || kd.d.length < 2) return false;

    // 檢查最近 2 天內是否發生過黃金交叉
    final startIndex = kd.k.length >= 3 ? kd.k.length - 3 : 0;
    for (int i = startIndex; i < kd.k.length - 1; i++) {
      final prevK = kd.k[i];
      final prevD = kd.d[i];
      final nextK = kd.k[i + 1];
      final nextD = kd.d[i + 1];

      if (prevK != null && prevD != null && nextK != null && nextD != null) {
        // K 上穿 D（前一天 K < D，今天 K >= D）
        if (prevK < prevD && nextK >= nextD) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查 KD 死亡交叉（K 下穿 D）
  ///
  /// 檢查最近 2 天內是否發生過死亡交叉。
  /// 簡化版本：只檢查交叉本身，不要求在高檔區。
  bool _checkKdDeathCross(List<DailyPriceEntry> prices) {
    if (prices.length < 11) return false;

    final highs = prices.map((p) => p.high).whereType<double>().toList();
    final lows = prices.map((p) => p.low).whereType<double>().toList();
    final closes = prices.map((p) => p.close).whereType<double>().toList();

    if (highs.length < 11 || lows.length < 11 || closes.length < 11) {
      return false;
    }

    final service = TechnicalIndicatorService();
    final kd = service.calculateKD(highs, lows, closes, kPeriod: 9, dPeriod: 3);

    if (kd.k.length < 2 || kd.d.length < 2) return false;

    // 檢查最近 2 天內是否發生過死亡交叉
    final startIndex = kd.k.length >= 3 ? kd.k.length - 3 : 0;
    for (int i = startIndex; i < kd.k.length - 1; i++) {
      final prevK = kd.k[i];
      final prevD = kd.d[i];
      final nextK = kd.k[i + 1];
      final nextD = kd.d[i + 1];

      if (prevK != null && prevD != null && nextK != null && nextD != null) {
        // K 下穿 D（前一天 K > D，今天 K <= D）
        if (prevK > prevD && nextK <= nextD) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查股價突破均線（價格由下往上穿越均線）
  ///
  /// 檢查最近 2 天內是否發生過突破。
  bool _checkCrossAboveMa(List<DailyPriceEntry> prices, int maDays) {
    if (prices.length < maDays + 2) return false;

    final closes = prices.map((p) => p.close).whereType<double>().toList();
    if (closes.length < maDays + 2) return false;

    final service = TechnicalIndicatorService();
    final maValues = service.calculateSMA(closes, maDays);

    if (maValues.length < 2) return false;

    // 檢查最近 2 天內是否發生過突破
    final startIndex = maValues.length >= 3 ? maValues.length - 3 : 0;
    for (int i = startIndex; i < maValues.length - 1; i++) {
      final prevClose = closes[i];
      final prevMa = maValues[i];
      final nextClose = closes[i + 1];
      final nextMa = maValues[i + 1];

      if (prevMa != null && nextMa != null) {
        // 價格由下往上穿越均線（前一天 close < MA，今天 close >= MA）
        if (prevClose < prevMa && nextClose >= nextMa) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查股價跌破均線（價格由上往下穿越均線）
  ///
  /// 檢查最近 2 天內是否發生過跌破。
  bool _checkCrossBelowMa(List<DailyPriceEntry> prices, int maDays) {
    if (prices.length < maDays + 2) return false;

    final closes = prices.map((p) => p.close).whereType<double>().toList();
    if (closes.length < maDays + 2) return false;

    final service = TechnicalIndicatorService();
    final maValues = service.calculateSMA(closes, maDays);

    if (maValues.length < 2) return false;

    // 檢查最近 2 天內是否發生過跌破
    final startIndex = maValues.length >= 3 ? maValues.length - 3 : 0;
    for (int i = startIndex; i < maValues.length - 1; i++) {
      final prevClose = closes[i];
      final prevMa = maValues[i];
      final nextClose = closes[i + 1];
      final nextMa = maValues[i + 1];

      if (prevMa != null && nextMa != null) {
        // 價格由上往下穿越均線（前一天 close > MA，今天 close <= MA）
        if (prevClose > prevMa && nextClose <= nextMa) {
          return true;
        }
      }
    }

    return false;
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
  // 自訂選股策略操作
  // ==================================================

  /// 取得所有已儲存的選股策略
  Future<List<ScreeningStrategyEntry>> getAllScreeningStrategies() {
    return (select(
      screeningStrategyTable,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  /// 新增選股策略，回傳自動產生的 ID
  Future<int> insertScreeningStrategy(ScreeningStrategyTableCompanion entry) {
    return into(screeningStrategyTable).insert(entry);
  }

  /// 更新選股策略
  Future<void> updateScreeningStrategy(
    int id,
    ScreeningStrategyTableCompanion entry,
  ) {
    return (update(
      screeningStrategyTable,
    )..where((t) => t.id.equals(id))).write(entry);
  }

  /// 刪除選股策略
  Future<void> deleteScreeningStrategy(int id) {
    return (delete(screeningStrategyTable)..where((t) => t.id.equals(id))).go();
  }
}
