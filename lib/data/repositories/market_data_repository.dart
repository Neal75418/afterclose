import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// 市場資料 Repository
///
/// 處理：財報、還原股價、週K線
class MarketDataRepository {
  MarketDataRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  // ============================================
  // 日期輔助方法
  // ============================================

  /// 檢查兩個日期是否為同一天（忽略時間）
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 檢查兩個日期是否在同一週（週一至週日）
  bool _isSameWeek(DateTime a, DateTime b) {
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aWeekStart, bWeekStart);
  }

  /// 根據當前日期取得預期最新季度日期
  ///
  /// 財報通常在季度結束後約 45 天公布：
  /// - Q1（1-3月）→ 約 5 月中公布
  /// - Q2（4-6月）→ 約 8 月中公布
  /// - Q3（7-9月）→ 約 11 月中公布
  /// - Q4（10-12月）→ 約隔年 3 月中公布
  DateTime _getExpectedLatestQuarter() {
    final now = DateTime.now();
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

  /// 解析季度日期字串（如 "2024-Q1" 或 "2024-01-01"）
  DateTime _parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
  }

  // ============================================
  // 財報資料
  // ============================================

  /// 同步損益表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncIncomeStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final latestDate = await _db.getLatestFinancialDataDate(symbol, 'INCOME');
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getFinancialStatements(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'INCOME',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync income statement for $symbol', e);
    }
  }

  /// 同步資產負債表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        'BALANCE',
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getBalanceSheet(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'BALANCE',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync balance sheet for $symbol', e);
    }
  }

  /// 同步現金流量表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> syncCashFlowStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        'CASHFLOW',
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await _client.getCashFlowsStatement(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return FinancialDataCompanion.insert(
          symbol: item.stockId,
          date: _parseQuarterDate(item.date),
          statementType: 'CASHFLOW',
          dataType: item.type,
          value: Value(item.value),
          originName: Value(item.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync cash flow for $symbol', e);
    }
  }

  /// 取得特定財務指標
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    int quarters = 8,
  }) async {
    final startDate = DateTime.now().subtract(
      Duration(days: quarters * 90 + 30),
    );
    return _db.getFinancialMetrics(
      symbol,
      dataTypes: dataTypes,
      startDate: startDate,
    );
  }

  // ============================================
  // 還原股價
  // ============================================

  /// 取得還原股價歷史資料
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    int days = 120,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getAdjustedPriceHistory(symbol, startDate: startDate);
  }

  /// 同步還原股價資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有目標日期資料則跳過。
  Future<int> syncAdjustedPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final targetDate = endDate ?? DateTime.now();
      final latestDate = await _db.getLatestAdjustedPriceDate(symbol);
      if (latestDate != null && _isSameDay(latestDate, targetDate)) {
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
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync adjusted prices for $symbol', e);
    }
  }

  // ============================================
  // 週K線
  // ============================================

  /// 取得週K線歷史資料
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    int weeks = 52,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: weeks * 7 + 30));
    return _db.getWeeklyPriceHistory(symbol, startDate: startDate);
  }

  /// 同步週K線資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若已有本週資料則跳過。
  Future<int> syncWeeklyPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final latestDate = await _db.getLatestWeeklyPriceDate(symbol);
      if (latestDate != null && _isSameWeek(latestDate, DateTime.now())) {
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
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync weekly prices for $symbol', e);
    }
  }

  /// 取得 52 週最高/最低價
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
