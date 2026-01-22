import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// Repository for extended market data (Phase 1)
///
/// Handles: Shareholding, DayTrading, Financial Statements,
/// Adjusted Price, Weekly Price, and Holding Distribution
class MarketDataRepository {
  MarketDataRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  // ============================================
  // Shareholding (外資持股)
  // ============================================

  /// Get shareholding history for a stock
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    int days = 60,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getShareholdingHistory(symbol, startDate: startDate);
  }

  /// Get latest shareholding for a stock
  Future<ShareholdingEntry?> getLatestShareholding(String symbol) {
    return _db.getLatestShareholding(symbol);
  }

  /// Sync shareholding data from FinMind
  Future<int> syncShareholding(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getShareholding(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return ShareholdingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignRemainingShares: Value(item.foreignInvestmentRemainingShares),
          foreignSharesRatio: Value(item.foreignInvestmentSharesRatio),
          foreignUpperLimitRatio: Value(item.foreignInvestmentUpperLimitRatio),
          sharesIssued: Value(item.numberOfSharesIssued),
        );
      }).toList();

      await _db.insertShareholdingData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync shareholding for $symbol', e);
    }
  }

  /// Check if foreign shareholding is increasing
  Future<bool> isForeignShareholdingIncreasing(
    String symbol, {
    int days = 5,
  }) async {
    final history = await getShareholdingHistory(symbol, days: days + 10);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.foreignSharesRatio ?? 0;
    final last = recent.first.foreignSharesRatio ?? 0;

    return last > first;
  }

  // ============================================
  // Day Trading (當沖)
  // ============================================

  /// Get day trading history for a stock
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 10));
    return _db.getDayTradingHistory(symbol, startDate: startDate);
  }

  /// Get latest day trading data
  Future<DayTradingEntry?> getLatestDayTrading(String symbol) {
    return _db.getLatestDayTrading(symbol);
  }

  /// Sync day trading data from FinMind
  Future<int> syncDayTrading(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getDayTrading(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return DayTradingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          buyVolume: Value(item.buyDayTradingVolume),
          sellVolume: Value(item.sellDayTradingVolume),
          dayTradingRatio: Value(item.dayTradingRatio),
          tradeVolume: Value(item.tradeVolume),
        );
      }).toList();

      await _db.insertDayTradingData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync day trading for $symbol', e);
    }
  }

  /// Check if day trading ratio is high (>30%)
  Future<bool> isHighDayTradingStock(String symbol) async {
    final latest = await getLatestDayTrading(symbol);
    if (latest == null) return false;
    return (latest.dayTradingRatio ?? 0) > 30;
  }

  /// Get average day trading ratio
  Future<double?> getAverageDayTradingRatio(String symbol, {int days = 5}) async {
    final history = await getDayTradingHistory(symbol, days: days + 5);
    if (history.isEmpty) return null;

    final recent = history.reversed.take(days).toList();
    if (recent.isEmpty) return null;

    double sum = 0;
    int count = 0;
    for (final entry in recent) {
      if (entry.dayTradingRatio != null) {
        sum += entry.dayTradingRatio!;
        count++;
      }
    }

    return count > 0 ? sum / count : null;
  }

  // ============================================
  // Financial Data (財務報表)
  // ============================================

  /// Sync income statement data
  Future<int> syncIncomeStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getFinancialStatements(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
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

  /// Sync balance sheet data
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getBalanceSheet(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
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

  /// Sync cash flow statement data
  Future<int> syncCashFlowStatement(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getCashFlowsStatement(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
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

  /// Get specific financial metrics
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    int quarters = 8,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: quarters * 90 + 30));
    return _db.getFinancialMetrics(
      symbol,
      dataTypes: dataTypes,
      startDate: startDate,
    );
  }

  /// Parse quarter date string (e.g., "2024-Q1" or "2024-01-01")
  DateTime _parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      // Format: 2024-Q1
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
  }

  // ============================================
  // Adjusted Price (還原股價)
  // ============================================

  /// Get adjusted price history
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    int days = 120,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getAdjustedPriceHistory(symbol, startDate: startDate);
  }

  /// Sync adjusted price data
  Future<int> syncAdjustedPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getAdjustedPrices(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
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
  // Weekly Price (週K線)
  // ============================================

  /// Get weekly price history
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    int weeks = 52,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: weeks * 7 + 30));
    return _db.getWeeklyPriceHistory(symbol, startDate: startDate);
  }

  /// Sync weekly price data
  Future<int> syncWeeklyPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getWeeklyPrices(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
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

  /// Get 52-week high/low
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

  // ============================================
  // Holding Distribution (股權分散)
  // ============================================

  /// Get latest holding distribution
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) {
    return _db.getLatestHoldingDistribution(symbol);
  }

  /// Sync holding distribution data
  Future<int> syncHoldingDistribution(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getHoldingSharesPer(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return HoldingDistributionCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          level: item.holdingSharesLevel,
          shareholders: Value(item.people),
          percent: Value(item.percent),
          shares: Value(item.unit),
        );
      }).toList();

      await _db.insertHoldingDistribution(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync holding distribution for $symbol',
        e,
      );
    }
  }

  /// Calculate concentration ratio (大戶持股比例)
  ///
  /// Returns the percentage of shares held by shareholders with
  /// more than [threshold] shares
  Future<double?> getConcentrationRatio(
    String symbol, {
    int thresholdLevel = 400, // 400張 = 40萬股
  }) async {
    final distribution = await getLatestHoldingDistribution(symbol);
    if (distribution.isEmpty) return null;

    double largeHolderPercent = 0;

    for (final entry in distribution) {
      // Parse level to get minimum shares
      // Levels like "400-600", "600-800", "800-1000", "1000以上"
      final level = entry.level;
      final minShares = _parseMinSharesFromLevel(level);

      if (minShares >= thresholdLevel) {
        largeHolderPercent += entry.percent ?? 0;
      }
    }

    return largeHolderPercent;
  }

  /// Parse minimum shares from level string
  int _parseMinSharesFromLevel(String level) {
    // Handle "1000以上" or "over 1000"
    if (level.contains('以上') || level.toLowerCase().contains('over')) {
      final numStr = level.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    // Handle "400-600" format
    final parts = level.split('-');
    if (parts.isNotEmpty) {
      final numStr = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    return 0;
  }
}
