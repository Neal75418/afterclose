import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';

/// Data object containing all necessary market data for rule evaluation
class StockData {
  const StockData({
    required this.symbol,
    required this.prices,
    this.institutional,
    this.news,
  });

  final String symbol;
  final List<DailyPriceEntry> prices;
  final List<DailyInstitutionalEntry>? institutional;
  final List<NewsItemEntry>? news;

  /// Get latest price entry, null if empty
  DailyPriceEntry? get latestPrice => prices.isEmpty ? null : prices.last;

  /// Get latest close, null if unavailable
  double? get latestClose => latestPrice?.close;

  /// Get previous price entry, null if less than 2 entries
  DailyPriceEntry? get previousPrice =>
      prices.length < 2 ? null : prices[prices.length - 2];

  /// Get previous close, null if unavailable
  double? get previousClose => previousPrice?.close;
}

/// Base interface for all stock analysis rules
abstract class StockRule {
  const StockRule();

  /// Unique identifier for the rule
  String get id;

  /// Human readable name
  String get name;

  /// Evaluate the rule against stock data
  ///
  /// Returns a [TriggeredReason] if the rule matches, otherwise null.
  TriggeredReason? evaluate(AnalysisContext context, StockData data);
}
