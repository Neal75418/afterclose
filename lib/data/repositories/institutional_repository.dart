import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// Repository for institutional investor trading data
class InstitutionalRepository {
  InstitutionalRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final FinMindClient _client;
  final TwseClient _twseClient;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Get institutional data history for analysis
  ///
  /// Returns data for [RuleParams.lookbackPrice] days if available
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    int? days,
  }) async {
    final lookback = days ?? RuleParams.lookbackPrice;
    final startDate = DateTime.now().subtract(Duration(days: lookback + 30));

    return _db.getInstitutionalHistory(symbol, startDate: startDate);
  }

  /// Get latest institutional data for a stock
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol) {
    return _db.getLatestInstitutional(symbol);
  }

  /// Sync institutional data for a single stock
  Future<int> syncInstitutionalData(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getInstitutionalData(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return DailyInstitutionalCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: Value(item.foreignNet),
          investmentTrustNet: Value(item.investmentTrustNet),
          dealerNet: Value(item.dealerNet),
        );
      }).toList();

      await _db.insertInstitutionalData(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync institutional data for $symbol',
        e,
      );
    }
  }

  /// Sync institutional data for ALL stocks on a specific date
  ///
  /// Uses TWSE T86 API (free, full market).
  /// This allows us to analyze institutional activity for non-watchlist stocks.
  Future<int> syncAllMarketInstitutional(DateTime date) async {
    try {
      // TWSE API (T86) returns data for a specific date
      // Note: T86 API usually takes date parameter in request,
      // but TwseClient.getAllInstitutionalData currently hits the endpoint without date param
      // which defaults to "latest trading day".
      // TODO: If TwseClient doesn't support date param for T86, we can only sync TODAY.
      // Let's check logic: TwseClient.getAllInstitutionalData() hardcodes '/rwd/zh/fund/T86'.
      // Only query param is response=json. It fetches LATEST data.

      // WAIT: We need to support fetching historical T86 if we want to backfill.
      // TWSE T86 endpoint DOES support 'date' parameter (YYYYMMDD).
      // I will assume I need to modify TwseClient later to support date,
      // OR I implement the fetch here if I can't change TwseClient easily (I can).

      // Let's assume for now we only sync LATEST/Target Date.
      // If the date passed is not "today/latest", we might need to be careful.
      // But typically we run this for "today's update".

      final data = await _twseClient.getAllInstitutionalData(date: date);

      if (data.isEmpty) return 0;

      // Filter out invalid or zero-volume entries to save DB space
      final validData = data
          .where(
            (item) =>
                item.totalNet != 0 ||
                item.foreignNet != 0 ||
                item.investmentTrustNet != 0,
          )
          .toList();

      final entries = validData.map((item) {
        return DailyInstitutionalCompanion.insert(
          symbol: item.code,
          date: item.date,
          foreignNet: Value(item.foreignNet),
          investmentTrustNet: Value(item.investmentTrustNet),
          dealerNet: Value(item.dealerNet),
        );
      }).toList();

      await _db.insertInstitutionalData(entries);

      return entries.length;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync all institutional data', e);
    }
  }

  /// Check if institutional data shows direction reversal
  ///
  /// Returns true if the net buying direction has changed in recent days
  Future<bool> hasDirectionReversal(String symbol, {int days = 5}) async {
    final history = await getInstitutionalHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    // Calculate total net for recent period
    double recentNet = 0;
    for (final entry in recent) {
      recentNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    // Get previous period
    final previous = history.reversed.skip(days).take(days).toList();
    if (previous.isEmpty) return false;

    double previousNet = 0;
    for (final entry in previous) {
      previousNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    // Check for direction reversal (sign change)
    return (recentNet > 0 && previousNet < 0) ||
        (recentNet < 0 && previousNet > 0);
  }

  /// Get total institutional net buying for recent days
  Future<double?> getTotalNetBuying(String symbol, {int days = 5}) async {
    final history = await getInstitutionalHistory(symbol, days: days + 5);
    if (history.isEmpty) return null;

    final recent = history.reversed.take(days).toList();
    if (recent.isEmpty) return null;

    double totalNet = 0;
    for (final entry in recent) {
      totalNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    return totalNet;
  }
}
