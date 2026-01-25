import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';

/// 每日價格資料 Repository
///
/// 主要資料來源：TWSE Open Data（免費、無限制、全市場）
/// 備援資料來源：FinMind（歷史資料）
class PriceRepository implements IPriceRepository {
  PriceRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final TwseClient _twseClient;

  // 註：保留 FinMindClient 在建構子以維持向下相容，
  // 但不再使用，TWSE 為主要資料來源

  /// 取得價格歷史資料供分析使用
  ///
  /// 若可用，至少回傳 [RuleParams.lookbackPrice] 天的資料
  @override
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    int? days,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final effectiveStartDate =
        startDate ??
        DateTime.now().subtract(
          Duration(days: (days ?? RuleParams.lookbackPrice) + 30),
        );

    return _db.getPriceHistory(
      symbol,
      startDate: effectiveStartDate,
      endDate: endDate,
    );
  }

  /// 取得股票最新價格
  @override
  Future<DailyPriceEntry?> getLatestPrice(String symbol) {
    return _db.getLatestPrice(symbol);
  }

  /// 使用 TWSE 歷史 API 同步單檔股票價格
  ///
  /// 使用 TWSE 取得歷史資料（免費、官方來源）
  /// 最佳化：僅抓取 Database 中缺少的月份
  @override
  Future<int> syncStockPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final effectiveEndDate = endDate ?? DateTime.now();

      // 最佳化：檢查既有資料
      final existingHistory = await _db.getPriceHistory(
        symbol,
        startDate: startDate,
        endDate: effectiveEndDate,
      );

      // 計算需要抓取的月份（僅抓取資料不足的月份）
      final monthsToFetch = <DateTime>[];
      var current = DateTime(startDate.year, startDate.month, 1);
      final end = DateTime(effectiveEndDate.year, effectiveEndDate.month, 1);

      while (!current.isAfter(end)) {
        // 僅當該月資料不足時才抓取（少於 10 個交易日）
        final existingDaysInMonth = existingHistory
            .where(
              (p) =>
                  p.date.year == current.year && p.date.month == current.month,
            )
            .length;
        if (existingDaysInMonth < 10) {
          monthsToFetch.add(current);
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      // 若無需抓取，直接回傳
      if (monthsToFetch.isEmpty) {
        return 0;
      }

      // 僅抓取缺少的月份
      final allPrices = <TwseDailyPrice>[];
      for (var i = 0; i < monthsToFetch.length; i++) {
        final month = monthsToFetch[i];
        try {
          final monthData = await _twseClient.getStockMonthlyPrices(
            code: symbol,
            year: month.year,
            month: month.month,
          );
          allPrices.addAll(monthData);
        } on RateLimitException {
          // Rate Limit 錯誤應向上拋出以進行適當的 Backoff 處理
          rethrow;
        } catch (_) {
          // 忽略個別月份失敗，繼續處理其他月份
        }

        // API 請求間隔（250ms：batchSize=2 的安全甜蜜點）
        if (i < monthsToFetch.length - 1) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }

      // 過濾至請求的日期範圍
      final filteredPrices = allPrices.where(
        (p) => !p.date.isBefore(startDate) && !p.date.isAfter(effectiveEndDate),
      );

      final entries = filteredPrices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.code,
          date: price.date,
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      if (entries.isNotEmpty) {
        await _db.insertPrices(entries);
      }

      return entries.length;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync prices for $symbol', e);
    }
  }

  /// 同步今日所有股票價格（批次模式）
  ///
  /// [syncAllPricesForDate] 的別名，使用預設日期
  @override
  Future<MarketSyncResult> syncTodayPrices({DateTime? date}) {
    return syncAllPricesForDate(date ?? DateTime.now());
  }

  /// 同步最新交易日的所有價格，並回傳快篩候選股
  ///
  /// 主要來源：TWSE Open Data（免費、無限制、全市場）
  ///
  /// 同時以 TWSE 資料更新 stock_master 中的股票名稱。
  ///
  /// 回傳 [MarketSyncResult]，包含同步筆數和快篩候選股。
  @override
  Future<MarketSyncResult> syncAllPricesForDate(
    DateTime date, {
    List<String>? fallbackSymbols,
    bool force = false,
  }) async {
    try {
      // 正規化日期至 UTC 午夜時間，確保跨時區一致性
      final normalizedDate = DateContext.normalize(date);

      // 最佳化：先檢查 Database，避免不必要的 API 呼叫
      if (!force) {
        final existingCount = await _db.getPriceCountForDate(normalizedDate);
        if (existingCount > 1000) {
          // 仍需取得候選股供 Pipeline 使用，從 Database 載入
          final candidates = await _quickFilterCandidatesFromDb(normalizedDate);

          final dateStr =
              '${normalizedDate.year}-${normalizedDate.month.toString().padLeft(2, '0')}-${normalizedDate.day.toString().padLeft(2, '0')}';
          AppLogger.info('PriceRepo', '價格同步: $existingCount 筆 ($dateStr, 快取)');

          return MarketSyncResult(
            count: existingCount,
            candidates: candidates,
            dataDate: normalizedDate,
            skipped: true,
          );
        }
      }

      // 僅在尚無資料時呼叫 API
      final prices = await _twseClient.getAllDailyPrices();

      if (prices.isEmpty) {
        AppLogger.warning('PriceRepo', '價格同步: 無資料');
        return const MarketSyncResult(count: 0, candidates: []);
      }

      // 建立價格資料
      final priceEntries = prices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.code,
          date: price.date,
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      // 從 TWSE 資料建立股票主檔（包含股票名稱！）
      final stockEntries = prices.where((p) => p.name.isNotEmpty).map((price) {
        return StockMasterCompanion.insert(
          symbol: price.code,
          name: price.name,
          market: 'TWSE',
          isActive: const Value(true),
        );
      }).toList();

      // 寫入資料庫
      if (stockEntries.isNotEmpty) {
        await _db.upsertStocks(stockEntries);
      }
      await _db.insertPrices(priceEntries);

      // 快篩候選股
      final candidates = _quickFilterCandidates(prices);

      final dataDate = prices.first.date;
      final dateStr =
          '${dataDate.year}-${dataDate.month.toString().padLeft(2, '0')}-${dataDate.day.toString().padLeft(2, '0')}';
      AppLogger.info(
        'PriceRepo',
        '價格同步: ${priceEntries.length} 筆 ($dateStr, 候選 ${candidates.length})',
      );

      return MarketSyncResult(
        count: priceEntries.length,
        candidates: candidates,
        dataDate: dataDate,
      );
    } on NetworkException {
      rethrow;
    } catch (e, stack) {
      AppLogger.error('PriceRepo', '價格同步失敗', e, stack);
      throw DatabaseException('Failed to sync prices from TWSE', e);
    }
  }

  /// 從今日市場資料快篩候選股
  ///
  /// 條件（任一觸發）：
  /// 1. 漲跌幅 >= 2%（顯著波動）
  /// 2. 接近漲停或跌停
  /// 3. 漲跌幅 >= 1.5% 且具高成交量潛力
  ///
  /// 回傳約 100 檔股票供進一步分析
  List<String> _quickFilterCandidates(List<TwseDailyPrice> prices) {
    final candidates = <_QuickCandidate>[];

    for (final price in prices) {
      // 跳過缺少關鍵資料的股票
      if (price.close == null || price.close! <= 0) continue;
      if (price.change == null) continue;

      // 跳過 ETF、權證等（代碼非數字開頭或過短）
      if (price.code.length < 4) continue;
      // 嚴格過濾：僅允許純數字代碼（排除 02001L、00631L 等）
      // 避免「Invalid argument」錯誤，專注於股票/ETF 分析
      if (!RegExp(r'^\d+$').hasMatch(price.code)) continue;

      // 計算漲跌幅
      final prevClose = price.close! - price.change!;
      if (prevClose <= 0) continue;

      // 過濾：跳過極低成交量股票（< 50 張）
      // 移除冷門股以維持分析品質
      if ((price.volume ?? 0) < RuleParams.minQuickFilterVolumeShares) continue;

      // 全市場策略：
      // 納入所有活躍股票，不論漲跌幅。
      // 讓 Rule Engine 在盤整行情中也能發現型態

      final changePercent = (price.change! / prevClose).abs() * 100;
      candidates.add(
        _QuickCandidate(
          symbol: price.code,
          score: changePercent, // 簡單分數供排序
        ),
      );
    }

    // 依波動度排序（僅供顯示一致性）
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 回傳所有合格候選股（全市場掃描）
    return candidates.map((c) => c.symbol).toList();
  }

  /// 從 Database 快篩候選股（當跳過 API 時使用）
  ///
  /// 類似 _quickFilterCandidates，但從本地 Database 讀取，
  /// 而非 API 回應。當已有今日資料時使用。
  Future<List<String>> _quickFilterCandidatesFromDb(DateTime date) async {
    // 從 Database 取得該日期的所有價格
    final prices = await _db.getPricesForDate(date);

    if (prices.isEmpty) return [];

    final candidates = <_QuickCandidate>[];

    for (final price in prices) {
      // 跳過缺少關鍵資料的股票
      final close = price.close;
      if (close == null || close <= 0) continue;

      // 跳過 ETF、權證等
      if (price.symbol.length < 4) continue;
      if (!RegExp(r'^\d+$').hasMatch(price.symbol)) continue;

      // 跳過極低成交量股票
      if ((price.volume ?? 0) < RuleParams.minQuickFilterVolumeShares) continue;

      // 需要前一日收盤價計算漲跌幅
      // 簡化處理：納入所有活躍股票
      // （Rule Engine 會進行完整分析）
      candidates.add(
        _QuickCandidate(
          symbol: price.symbol,
          score: 0, // 無需排名
        ),
      );
    }

    return candidates.map((c) => c.symbol).toList();
  }

  /// 同步指定股票清單的價格（免費帳號備援方案）
  ///
  /// 逐一抓取價格並注意 Rate Limiting。
  /// 僅抓取 Database 中缺少的資料。
  ///
  /// [onProgress] - 進度回呼（current, total, symbol）
  /// [delayBetweenRequests] - API 呼叫間隔以避免 Rate Limit
  Future<int> _syncPricesForSymbols(
    List<String> symbols,
    DateTime date, {
    void Function(int current, int total, String symbol)? onProgress,
    Duration delayBetweenRequests = const Duration(milliseconds: 200),
  }) async {
    var totalSynced = 0;
    final errors = <String>[];

    // 分析用歷史資料範圍（lookback + buffer）
    final historyStartDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 30),
    );

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      onProgress?.call(i + 1, symbols.length, symbol);

      try {
        // 檢查既有資料
        final latestPrice = await _db.getLatestPrice(symbol);
        final latestDate = latestPrice?.date;

        // 若已有今日資料則跳過
        if (latestDate != null && _isSameDay(latestDate, date)) {
          continue;
        }

        // 決定抓取範圍
        DateTime fetchStartDate;
        if (latestDate == null) {
          // 完全無資料，抓取完整歷史
          fetchStartDate = historyStartDate;
        } else if (latestDate.isBefore(historyStartDate)) {
          // 資料過舊，抓取完整歷史
          fetchStartDate = historyStartDate;
        } else {
          // 有部分資料，從最新日期後一天開始
          fetchStartDate = latestDate.add(const Duration(days: 1));
        }

        // 若抓取起始日超過目標日期則跳過
        if (fetchStartDate.isAfter(date)) {
          continue;
        }

        final count = await syncStockPrices(
          symbol,
          startDate: fetchStartDate,
          endDate: date,
        );
        totalSynced += count;

        // API 請求間隔
        if (i < symbols.length - 1 && delayBetweenRequests.inMilliseconds > 0) {
          await Future.delayed(delayBetweenRequests);
        }
      } on RateLimitException {
        // Rate Limit 立即停止
        rethrow;
      } catch (e) {
        // 記錄錯誤並繼續處理其他股票
        errors.add('$symbol: $e');
      }
    }

    // 若所有股票都失敗則拋出例外
    if (totalSynced == 0 && errors.isNotEmpty && symbols.isNotEmpty) {
      throw DatabaseException(
        'Failed to sync any prices. Errors: ${errors.take(3).join("; ")}',
      );
    }

    return totalSynced;
  }

  /// 檢查兩個日期是否為同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 同步多檔指定股票的價格（供 Update Service 使用的公開 API）
  ///
  /// 當您有特定股票清單需要更新時使用。
  /// 僅抓取缺少的資料，已最新的股票會跳過。
  ///
  /// [onProgress] - 進度回呼（current, total, symbol）
  @override
  Future<int> syncPricesForSymbols(
    List<String> symbols, {
    required DateTime targetDate,
    void Function(int current, int total, String symbol)? onProgress,
  }) async {
    return _syncPricesForSymbols(symbols, targetDate, onProgress: onProgress);
  }

  /// 取得指定日期需要更新價格的股票清單
  ///
  /// 回傳該日期尚無價格資料的股票。
  /// 使用批次查詢避免 N+1 效能問題。
  @override
  Future<List<String>> getSymbolsNeedingUpdate(
    List<String> symbols,
    DateTime targetDate,
  ) async {
    if (symbols.isEmpty) return [];

    // 批次查詢取代 N+1 個別查詢
    final latestPrices = await _db.getLatestPricesBatch(symbols);

    return symbols.where((symbol) {
      final latestPrice = latestPrices[symbol];
      return latestPrice == null || !_isSameDay(latestPrice.date, targetDate);
    }).toList();
  }

  /// 取得股票漲跌幅
  @override
  Future<double?> getPriceChange(String symbol) async {
    final history = await getPriceHistory(symbol, days: 2);
    if (history.length < 2) return null;

    final today = history.last;
    final yesterday = history[history.length - 2];

    if (today.close == null || yesterday.close == null) return null;
    if (yesterday.close == 0) return null;

    final change = ((today.close! - yesterday.close!) / yesterday.close!) * 100;
    // 防護 NaN/Infinity（分母極小時）
    return change.isFinite ? change : null;
  }

  /// 取得 20 日成交量移動平均
  @override
  Future<double?> getVolumeMA20(String symbol) async {
    final history = await getPriceHistory(symbol, days: RuleParams.volMa + 5);
    if (history.length < RuleParams.volMa) return null;

    final recent = history.reversed.take(RuleParams.volMa).toList();
    final validVolumes = recent
        .where((p) => p.volume != null)
        .map((p) => p.volume!);

    if (validVolumes.isEmpty) return null;

    return validVolumes.reduce((a, b) => a + b) / validVolumes.length;
  }

  // ==================================================
  // 批次方法（N+1 最佳化）
  // ==================================================

  /// 批次取得多檔股票的漲跌幅
  ///
  /// 回傳 Map：symbol -> 漲跌幅百分比
  /// 比迴圈呼叫 [getPriceChange] 更有效率
  ///
  /// Database 查詢失敗時拋出 [DatabaseException]
  @override
  Future<Map<String, double?>> getPriceChangesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 5));

      // 單一批次查詢所有股票（包含最新價格）
      final priceHistories = await _db.getPriceHistoryBatch(
        symbols,
        startDate: startDate,
        endDate: today,
      );

      final result = <String, double?>{};

      for (final symbol in symbols) {
        final history = priceHistories[symbol];

        if (history == null || history.length < 2) {
          result[symbol] = null;
          continue;
        }

        // 直接使用歷史資料的最後兩筆
        final todayClose = history.last.close;
        final prevClose = history[history.length - 2].close;

        if (todayClose == null || prevClose == null || prevClose == 0) {
          result[symbol] = null;
          continue;
        }

        final change = ((todayClose - prevClose) / prevClose) * 100;
        // 防護 NaN/Infinity（分母極小時）
        result[symbol] = change.isFinite ? change : null;
      }

      return result;
    } catch (e) {
      throw DatabaseException('Failed to fetch price changes batch', e);
    }
  }

  /// 批次取得多檔股票的 20 日成交量移動平均
  ///
  /// 回傳 Map：symbol -> 成交量 MA
  /// 比迴圈呼叫 [getVolumeMA20] 更有效率
  ///
  /// Database 查詢失敗時拋出 [DatabaseException]
  @override
  Future<Map<String, double?>> getVolumeMA20Batch(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    try {
      final today = DateTime.now();
      final startDate = today.subtract(
        const Duration(days: RuleParams.volMa + 10),
      );

      // 單一批次查詢所有股票
      final priceHistories = await _db.getPriceHistoryBatch(
        symbols,
        startDate: startDate,
        endDate: today,
      );

      final result = <String, double?>{};

      for (final symbol in symbols) {
        final history = priceHistories[symbol];

        if (history == null || history.length < RuleParams.volMa) {
          result[symbol] = null;
          continue;
        }

        final recent = history.reversed.take(RuleParams.volMa).toList();
        final validVolumes = recent
            .where((p) => p.volume != null)
            .map((p) => p.volume!)
            .toList();

        if (validVolumes.isEmpty) {
          result[symbol] = null;
          continue;
        }

        result[symbol] =
            validVolumes.reduce((a, b) => a + b) / validVolumes.length;
      }

      return result;
    } catch (e) {
      throw DatabaseException('Failed to fetch volume MA batch', e);
    }
  }
}

/// 快篩候選股輔助類別
class _QuickCandidate {
  const _QuickCandidate({required this.symbol, required this.score});

  final String symbol;
  final double score;
}
