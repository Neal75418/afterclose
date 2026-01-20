import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// Repository for daily price data
class PriceRepository {
  PriceRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Get price history for analysis
  ///
  /// Returns at least [RuleParams.lookbackPrice] days if available
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

  /// Get latest price for a stock
  Future<DailyPriceEntry?> getLatestPrice(String symbol) {
    return _db.getLatestPrice(symbol);
  }

  /// Sync prices for a single stock
  Future<int> syncStockPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final prices = await _client.getDailyPrices(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = prices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.stockId,
          date: DateTime.parse(price.date),
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      await _db.insertPrices(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync prices for $symbol', e);
    }
  }

  /// Sync today's prices for all stocks (batch mode)
  ///
  /// Alias for [syncAllPricesForDate] with default date
  Future<int> syncTodayPrices({DateTime? date}) {
    return syncAllPricesForDate(date ?? DateTime.now());
  }

  /// Sync all prices for a date (batch mode)
  ///
  /// More efficient than fetching each stock individually
  Future<int> syncAllPricesForDate(DateTime date) async {
    try {
      final dateStr = _dateFormat.format(date);
      final prices = await _client.getAllDailyPrices(
        startDate: dateStr,
        endDate: dateStr,
      );

      final entries = prices.map((price) {
        return DailyPriceCompanion.insert(
          symbol: price.stockId,
          date: DateTime.parse(price.date),
          open: Value(price.open),
          high: Value(price.high),
          low: Value(price.low),
          close: Value(price.close),
          volume: Value(price.volume),
        );
      }).toList();

      await _db.insertPrices(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync prices for date', e);
    }
  }

  /// Get price change percentage
  Future<double?> getPriceChange(String symbol) async {
    final history = await getPriceHistory(symbol, days: 2);
    if (history.length < 2) return null;

    final today = history.last;
    final yesterday = history[history.length - 2];

    if (today.close == null || yesterday.close == null) return null;
    if (yesterday.close == 0) return null;

    return ((today.close! - yesterday.close!) / yesterday.close!) * 100;
  }

  /// Get 20-day volume moving average
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
}
