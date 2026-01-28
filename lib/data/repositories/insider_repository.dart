import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 董監事持股資料 Repository
///
/// 提供內部人持股的存取與同步功能，用於追蹤董監持股變化。
class InsiderRepository {
  InsiderRepository({
    required AppDatabase database,
    TpexClient? tpexClient,
    TwseClient? twseClient,
  }) : _db = database,
       _tpexClient = tpexClient ?? TpexClient(),
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final TpexClient _tpexClient;
  final TwseClient _twseClient;

  /// 取得股票的董監持股歷史
  Future<List<InsiderHoldingEntry>> getInsiderHoldingHistory(
    String symbol, {
    int? months,
  }) async {
    final lookback = months ?? 12;
    final now = DateTime.now();
    // 使用 DateTime 自動處理跨年和月份溢位
    // 例如: 2026-01 往前 3 個月 = 2025-10
    final startDate = DateTime(now.year, now.month - lookback, 1);
    return _db.getInsiderHoldingHistory(symbol, startDate: startDate);
  }

  /// 取得股票的最新董監持股
  Future<InsiderHoldingEntry?> getLatestInsiderHolding(String symbol) {
    return _db.getLatestInsiderHolding(symbol);
  }

  /// 取得股票近 N 個月的董監持股資料
  Future<List<InsiderHoldingEntry>> getRecentInsiderHoldings(
    String symbol, {
    int months = 6,
  }) {
    return _db.getRecentInsiderHoldings(symbol, months: months);
  }

  /// 批次取得多檔股票的最新董監持股
  Future<Map<String, InsiderHoldingEntry>> getLatestInsiderHoldingsBatch(
    List<String> symbols,
  ) {
    return _db.getLatestInsiderHoldingsBatch(symbols);
  }

  /// 取得高質押比例的股票
  ///
  /// [threshold] - 質押比例門檻（預設 50%）
  Future<List<InsiderHoldingEntry>> getHighPledgeRatioStocks({
    double? threshold,
  }) {
    final ratio = threshold ?? RuleParams.highPledgeRatioThreshold;
    return _db.getHighPledgeRatioStocks(threshold: ratio);
  }

  /// 同步全市場董監持股資料（上市 + 上櫃）
  ///
  /// 使用 TWSE/TPEX OpenAPI 取得最新的董監持股資料。
  /// 免費 API，無需 token。
  ///
  /// [force] - 若為 true，則無視新鮮度檢查強制同步
  Future<int> syncAllInsiderHoldings({bool force = false}) async {
    try {
      final now = DateTime.now();

      // 新鮮度檢查（月報，每月只需同步一次）
      if (!force) {
        final existingCount = await _db.getInsiderHoldingCountForYearMonth(
          now.year,
          now.month,
        );
        // 上市 + 上櫃約 1800+ 家，用 1500 作為門檻
        if (existingCount > 1500) {
          AppLogger.info('InsiderRepo', '董監持股資料已是最新 ($existingCount 筆)');
          return existingCount;
        }
      }

      // 平行取得 TWSE 和 TPEX 董監持股資料
      // 先啟動兩個 Future（開始並行執行），再分別 await
      final twseFuture = _twseClient.getInsiderHoldings();
      final tpexFuture = _tpexClient.getInsiderHoldings();

      final twseData = await twseFuture;
      final tpexData = await tpexFuture;

      if (twseData.isEmpty && tpexData.isEmpty) {
        AppLogger.warning('InsiderRepo', '無董監持股資料');
        return 0;
      }

      // 使用 transaction 確保原子性
      return await _db.transaction(() async {
        // 取得有效股票代碼以避免 Foreign Key 錯誤
        final stockList = await _db.getAllActiveStocks();
        final validSymbols = stockList.map((s) => s.symbol).toSet();

        final entries = <InsiderHoldingCompanion>[];

        // 處理 TWSE（上市）資料
        for (final item in twseData) {
          if (!validSymbols.contains(item.code)) continue;
          entries.add(
            InsiderHoldingCompanion.insert(
              symbol: item.code,
              date: DateTime(item.date.year, item.date.month, item.date.day),
              insiderRatio: Value(item.insiderRatio),
              pledgeRatio: Value(item.pledgeRatio),
              sharesIssued: Value(item.sharesIssued),
            ),
          );
        }

        // 處理 TPEX（上櫃）資料
        for (final item in tpexData) {
          if (!validSymbols.contains(item.code)) continue;
          entries.add(
            InsiderHoldingCompanion.insert(
              symbol: item.code,
              date: DateTime(item.date.year, item.date.month, item.date.day),
              insiderRatio: Value(item.insiderRatio),
              pledgeRatio: Value(item.pledgeRatio),
              sharesIssued: Value(item.sharesIssued),
            ),
          );
        }

        if (entries.isEmpty) {
          AppLogger.warning('InsiderRepo', '無有效董監持股資料');
          return 0;
        }

        // 寫入資料庫
        await _db.insertInsiderHoldingData(entries);

        AppLogger.info(
          'InsiderRepo',
          '董監持股同步: ${entries.length} 筆 (上市 ${twseData.length}, 上櫃 ${tpexData.length})',
        );

        return entries.length;
      });
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync insider holding data', e);
    }
  }

  /// 同步上櫃股票的董監持股資料（向後相容）
  ///
  /// @deprecated 請使用 [syncAllInsiderHoldings] 取代
  Future<int> syncOtcInsiderHoldings({bool force = false}) async {
    return syncAllInsiderHoldings(force: force);
  }

  /// 檢查董監是否連續減持
  ///
  /// 若近期董監持股比例持續下降則回傳 true（強賣訊號）
  Future<bool> hasConsecutiveSellingStreak(
    String symbol, {
    int months = 3,
  }) async {
    final history = await getRecentInsiderHoldings(symbol, months: months + 1);
    if (history.length < months) return false;

    // 依日期升冪排序
    history.sort((a, b) => a.date.compareTo(b.date));

    // 檢查連續減持
    // 策略：遇到 null 時跳過該筆，不重置計數器
    // 只有在持股比例上升時才重置計數器
    int consecutiveDecreaseCount = 0;
    double? lastValidRatio;

    for (final entry in history) {
      final currRatio = entry.insiderRatio;

      // 跳過 null 或無效值，保持連續性
      if (currRatio == null || currRatio <= 0) {
        continue;
      }

      // 有前一個有效值才能比較
      if (lastValidRatio != null) {
        if (currRatio < lastValidRatio) {
          consecutiveDecreaseCount++;
        } else {
          consecutiveDecreaseCount = 0; // 持股上升或持平，重置計數
        }
      }

      lastValidRatio = currRatio;
    }

    return consecutiveDecreaseCount >= months;
  }

  /// 檢查董監是否大量增持
  ///
  /// 若最近一期與前期相比增持超過門檻則回傳 true（買進訊號）
  Future<bool> hasSignificantBuying(
    String symbol, {
    double threshold = 5.0, // 增持 5% 以上
  }) async {
    final history = await getRecentInsiderHoldings(symbol, months: 2);
    if (history.length < 2) return false;

    // 依日期降冪排序（最新在前）
    history.sort((a, b) => b.date.compareTo(a.date));

    final latestRatio = history[0].insiderRatio ?? 0;
    final previousRatio = history[1].insiderRatio ?? 0;

    if (previousRatio <= 0) return false;

    final change = latestRatio - previousRatio;
    return change >= threshold;
  }

  /// 檢查是否為高質押風險股
  ///
  /// 質押比例超過門檻則回傳 true（風險警示）
  Future<bool> isHighPledgeRisk(String symbol, {double? threshold}) async {
    final ratio = threshold ?? RuleParams.highPledgeRatioThreshold;
    final latest = await getLatestInsiderHolding(symbol);
    if (latest == null) return false;

    final pledgeRatio = latest.pledgeRatio ?? 0;
    return pledgeRatio >= ratio;
  }

  /// 取得自選股中的高質押股票
  ///
  /// 用於在自選股頁面顯示風險標記。
  Future<Map<String, InsiderHoldingEntry>> getWatchlistHighPledgeStocks(
    List<String> watchlistSymbols, {
    double? threshold,
  }) async {
    if (watchlistSymbols.isEmpty) return {};

    final ratio = threshold ?? RuleParams.highPledgeRatioThreshold;
    final holdings = await getLatestInsiderHoldingsBatch(watchlistSymbols);

    final result = <String, InsiderHoldingEntry>{};
    for (final entry in holdings.entries) {
      final pledgeRatio = entry.value.pledgeRatio ?? 0;
      if (pledgeRatio >= ratio) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// 批次計算董監連續減持/增持狀態
  ///
  /// 回傳 Map: symbol -> InsiderStatus
  /// 用於 UpdateService 批量分析時避免 N+1 問題
  Future<Map<String, InsiderStatus>> calculateInsiderStatusBatch(
    List<String> symbols, {
    int months = 3,
    double buyingThreshold = 5.0,
  }) async {
    if (symbols.isEmpty) return {};

    // 批次取得所有股票的近期董監持股歷史
    final historyMap = await _db.getRecentInsiderHoldingsBatch(
      symbols,
      months: months + 1,
    );

    final result = <String, InsiderStatus>{};
    for (final symbol in symbols) {
      final history = historyMap[symbol];
      if (history == null || history.isEmpty) {
        result[symbol] = const InsiderStatus();
        continue;
      }

      // 計算連續減持
      final (hasStreak, streakMonths) = _calculateSellingStreak(
        history,
        requiredMonths: months,
      );

      // 計算顯著增持
      final (hasBuying, buyingChange) = _calculateSignificantBuying(
        history,
        threshold: buyingThreshold,
      );

      result[symbol] = InsiderStatus(
        hasSellingStreak: hasStreak,
        sellingStreakMonths: streakMonths,
        hasSignificantBuying: hasBuying,
        buyingChange: buyingChange,
      );
    }

    return result;
  }

  /// 計算連續減持（內部方法）
  (bool, int) _calculateSellingStreak(
    List<InsiderHoldingEntry> history, {
    required int requiredMonths,
  }) {
    if (history.length < requiredMonths) return (false, 0);

    // 依日期升冪排序（最舊在前）
    final sorted = List<InsiderHoldingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    int consecutiveDecreaseCount = 0;
    double? lastValidRatio;

    for (final entry in sorted) {
      final currRatio = entry.insiderRatio;

      // 跳過 null 或無效值
      if (currRatio == null || currRatio <= 0) continue;

      if (lastValidRatio != null) {
        if (currRatio < lastValidRatio) {
          consecutiveDecreaseCount++;
        } else {
          consecutiveDecreaseCount = 0;
        }
      }

      lastValidRatio = currRatio;
    }

    return (
      consecutiveDecreaseCount >= requiredMonths,
      consecutiveDecreaseCount,
    );
  }

  /// 計算顯著增持（內部方法）
  (bool, double?) _calculateSignificantBuying(
    List<InsiderHoldingEntry> history, {
    required double threshold,
  }) {
    if (history.length < 2) return (false, null);

    // 依日期降冪排序（最新在前）
    final sorted = List<InsiderHoldingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    final latestRatio = sorted[0].insiderRatio ?? 0;
    final previousRatio = sorted[1].insiderRatio ?? 0;

    if (previousRatio <= 0) return (false, null);

    final change = latestRatio - previousRatio;
    return (change >= threshold, change);
  }
}

/// 董監狀態資料類別
class InsiderStatus {
  const InsiderStatus({
    this.hasSellingStreak = false,
    this.sellingStreakMonths = 0,
    this.hasSignificantBuying = false,
    this.buyingChange,
  });

  final bool hasSellingStreak;
  final int sellingStreakMonths;
  final bool hasSignificantBuying;
  final double? buyingChange;
}
