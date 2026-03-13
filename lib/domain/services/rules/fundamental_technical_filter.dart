import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

/// Mixin providing common MA-based technical filters for fundamental rules.
mixin FundamentalTechnicalFilter on StockRule {
  /// Check if price is above specified MA with sufficient momentum (changePct > threshold).
  /// Returns (close, ma, changePct) or null if conditions fail.
  ({double close, double ma, double changePct})? checkAboveMAWithMomentum({
    required AnalysisContext context,
    required StockData data,
    required double? Function(TechnicalIndicators) maSelector,
    double priceChangeThreshold = TrendParams.minPriceChangeForVolume,
  }) {
    final indicators = context.indicators;
    if (indicators == null) return null;
    final ma = maSelector(indicators);
    if (ma == null) return null;

    final today = data.prices.isNotEmpty ? data.prices.last : null;
    final prev = data.prices.length >= 2
        ? data.prices[data.prices.length - 2]
        : null;
    if (today == null ||
        prev == null ||
        prev.close == null ||
        prev.close! <= 0) {
      return null;
    }

    final close = today.close ?? 0;
    final prevClose = prev.close!;
    final changePct = (close - prevClose) / prevClose;

    if (close > ma && changePct > priceChangeThreshold) {
      return (close: close, ma: ma, changePct: changePct);
    }
    return null;
  }

  /// Simplified check: price above MA (no changePct requirement).
  ({double close, double ma})? checkAboveMA({
    required AnalysisContext context,
    required StockData data,
    required double? Function(TechnicalIndicators) maSelector,
  }) {
    final indicators = context.indicators;
    if (indicators == null) return null;
    final ma = maSelector(indicators);
    if (ma == null) return null;

    final today = data.prices.isNotEmpty ? data.prices.last : null;
    if (today == null || today.close == null) return null;

    final close = today.close!;
    if (close <= ma) return null;
    return (close: close, ma: ma);
  }
}
