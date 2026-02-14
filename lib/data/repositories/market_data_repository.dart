import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/repositories/market_data_repository.dart';

/// 市場資料 Repository
///
/// 處理：財報、還原股價、週K線
class MarketDataRepository implements IMarketDataRepository {
  MarketDataRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _client = finMindClient,
       _clock = clock;

  final AppDatabase _db;
  final FinMindClient _client;
  final AppClock _clock;

  // ==================================================
  // 日期輔助方法
  // ==================================================

  /// 根據當前日期取得預期最新季度日期
  ///
  /// 財報通常在季度結束後約 45 天公布：
  /// - Q1（1-3月）→ 約 5 月中公布
  /// - Q2（4-6月）→ 約 8 月中公布
  /// - Q3（7-9月）→ 約 11 月中公布
  /// - Q4（10-12月）→ 約隔年 3 月中公布
  DateTime _getExpectedLatestQuarter() {
    final now = _clock.now();
    final month = now.month;

    if (month >= 3 && month < 5) {
      return DateTime(now.year - 1, 10, 1);
    } else if (month >= 5 && month < 8) {
      return DateTime(now.year, 1, 1);
    } else if (month >= 8 && month < 11) {
      return DateTime(now.year, 4, 1);
    } else if (month >= 11) {
      return DateTime(now.year, 7, 1);
    } else {
      return DateTime(now.year - 1, 7, 1);
    }
  }

  // ==================================================
  // 財報資料
  // ==================================================

  /// 同步損益表資料
  @override
  Future<int> syncIncomeStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) => _syncFinancialStatement(
    symbol,
    startDate: startDate,
    endDate: endDate,
    statementType: 'INCOME',
    fetchFn: (id, start, end) => _client.getFinancialStatements(
      stockId: id,
      startDate: start,
      endDate: end,
    ),
    extractFields: (item) => (
      stockId: item.stockId,
      date: item.date,
      type: item.type,
      value: item.value,
      origin: item.origin,
    ),
    logLabel: '損益表',
  );

  /// 同步資產負債表資料
  @override
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) => _syncFinancialStatement(
    symbol,
    startDate: startDate,
    endDate: endDate,
    statementType: 'BALANCE',
    fetchFn: (id, start, end) =>
        _client.getBalanceSheet(stockId: id, startDate: start, endDate: end),
    extractFields: (item) => (
      stockId: item.stockId,
      date: item.date,
      type: item.type,
      value: item.value,
      origin: item.origin,
    ),
    logLabel: '資產負債表',
  );

  /// 同步現金流量表資料
  @override
  Future<int> syncCashFlowStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) => _syncFinancialStatement(
    symbol,
    startDate: startDate,
    endDate: endDate,
    statementType: 'CASHFLOW',
    fetchFn: (id, start, end) => _client.getCashFlowsStatement(
      stockId: id,
      startDate: start,
      endDate: end,
    ),
    extractFields: (item) => (
      stockId: item.stockId,
      date: item.date,
      type: item.type,
      value: item.value,
      origin: item.origin,
    ),
    logLabel: '現金流量表',
  );

  /// 財報同步共用邏輯
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> _syncFinancialStatement<T>(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
    required String statementType,
    required Future<List<T>> Function(String stockId, String start, String? end)
    fetchFn,
    required ({
      String stockId,
      String date,
      String type,
      double value,
      String origin,
    })
    Function(T)
    extractFields,
    required String logLabel,
  }) async {
    try {
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        statementType,
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await fetchFn(
        symbol,
        DateContext.formatYmd(startDate),
        endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        final f = extractFields(item);
        return FinancialDataCompanion.insert(
          symbol: f.stockId,
          date: DateContext.parseQuarterDate(f.date),
          statementType: statementType,
          dataType: f.type,
          value: Value(f.value),
          originName: Value(f.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('MarketDataRepo', '$symbol: $logLabel同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync $statementType for $symbol', e);
    }
  }

  /// 取得特定財務指標
  @override
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    int quarters = 8,
  }) async {
    final startDate = _clock.now().subtract(Duration(days: quarters * 90 + 30));
    return _db.getFinancialMetrics(
      symbol,
      dataTypes: dataTypes,
      startDate: startDate,
    );
  }

  // ==================================================
  // 還原股價
  // ==================================================

  /// 取得還原股價歷史資料
  @override
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    int days = 120,
  }) async {
    final startDate = _clock.now().subtract(Duration(days: days + 30));
    return _db.getAdjustedPriceHistory(symbol, startDate: startDate);
  }

  /// 同步還原股價資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有目標日期資料則跳過。
  @override
  Future<int> syncAdjustedPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final targetDate = endDate ?? _clock.now();
      final latestDate = await _db.getLatestAdjustedPriceDate(symbol);
      if (latestDate != null && DateContext.isSameDay(latestDate, targetDate)) {
        return 0;
      }

      final data = await _client.getAdjustedPrices(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return AdjustedPriceCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          open: Value(item.open),
          high: Value(item.high),
          low: Value(item.low),
          close: Value(item.close),
          volume: Value(item.volume),
        );
      }).toList();

      await _db.insertAdjustedPrices(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('MarketDataRepo', '$symbol: 還原股價同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync adjusted prices for $symbol', e);
    }
  }

  // ==================================================
  // 週K線
  // ==================================================

  /// 取得週K線歷史資料
  @override
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    int weeks = 52,
  }) async {
    final startDate = _clock.now().subtract(Duration(days: weeks * 7 + 30));
    return _db.getWeeklyPriceHistory(symbol, startDate: startDate);
  }

  /// 同步週K線資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有本週資料則跳過。
  @override
  Future<int> syncWeeklyPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final latestDate = await _db.getLatestWeeklyPriceDate(symbol);
      if (latestDate != null &&
          DateContext.isSameWeek(latestDate, _clock.now())) {
        return 0;
      }

      final data = await _client.getWeeklyPrices(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return WeeklyPriceCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          open: Value(item.open),
          high: Value(item.high),
          low: Value(item.low),
          close: Value(item.close),
          volume: Value(item.volume),
        );
      }).toList();

      await _db.insertWeeklyPrices(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('MarketDataRepo', '$symbol: 週K線同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync weekly prices for $symbol', e);
    }
  }

  /// 取得 52 週最高/最低價
  @override
  Future<({double? high, double? low})> get52WeekHighLow(String symbol) async {
    final history = await getWeeklyPriceHistory(symbol, weeks: 52);
    if (history.isEmpty) return (high: null, low: null);

    double? maxHigh;
    double? minLow;

    for (final entry in history) {
      if (entry.high != null) {
        maxHigh = maxHigh == null
            ? entry.high
            : (entry.high! > maxHigh ? entry.high : maxHigh);
      }
      if (entry.low != null) {
        minLow = minLow == null
            ? entry.low
            : (entry.low! < minLow ? entry.low : minLow);
      }
    }

    return (high: maxHigh, low: minLow);
  }
}
