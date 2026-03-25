import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

/// 提供基本面規則共用的均線技術篩選器 Mixin。
mixin FundamentalTechnicalFilter on StockRule {
  /// 檢查價格是否在指定均線之上且具備足夠動能（changePct > threshold）。
  /// 回傳 (close, ma, changePct)，條件不符時回傳 null。
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

  /// 簡化檢查：價格站上均線（不要求漲幅）
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
