/// Rule Engine Parameters v1
/// These are fixed values for v1, will be configurable in v2
abstract final class RuleParams {
  /// Analysis window in days
  static const int lookbackPrice = 120;

  /// Moving average days for volume calculation
  static const int volMa = 20;

  /// Days for range (support/resistance) detection
  static const int rangeLookback = 60;

  /// Window for Swing High/Low detection
  static const int swingWindow = 20;

  /// Price spike threshold percentage
  static const double priceSpikePercent = 5.0;

  /// Volume spike multiplier (vs 20-day average)
  static const double volumeSpikeMult = 2.0;

  /// Breakout buffer tolerance (0 ~ 0.5%)
  static const double breakoutBuffer = 0.005;

  /// Cooldown days for repeated recommendations
  static const int cooldownDays = 2;

  /// Cooldown score multiplier
  static const double cooldownMultiplier = 0.7;

  /// Maximum reasons per stock
  static const int maxReasonsPerStock = 2;

  /// Daily top N recommendations
  static const int dailyTopN = 10;

  /// Maximum stocks per industry in daily recommendations (v2)
  static const int maxPerIndustry = 3;
}

/// Rule scores for each recommendation type
abstract final class RuleScores {
  static const int reversalW2S = 35;
  static const int reversalS2W = 35;
  static const int techBreakout = 25;
  static const int techBreakdown = 25;
  static const int volumeSpike = 18;
  static const int priceSpike = 15;
  static const int institutionalShift = 12;
  static const int newsRelated = 8;

  /// Bonus: BREAKOUT + VOLUME_SPIKE
  static const int breakoutVolumeBonus = 6;

  /// Bonus: REVERSAL_* + VOLUME_SPIKE
  static const int reversalVolumeBonus = 6;
}

/// Reason types enum
enum ReasonType {
  reversalW2S('REVERSAL_W2S', '弱轉強'),
  reversalS2W('REVERSAL_S2W', '強轉弱'),
  techBreakout('TECH_BREAKOUT', '技術突破'),
  techBreakdown('TECH_BREAKDOWN', '技術跌破'),
  volumeSpike('VOLUME_SPIKE', '放量異常'),
  priceSpike('PRICE_SPIKE', '價格異常'),
  institutionalShift('INSTITUTIONAL_SHIFT', '法人異常'),
  newsRelated('NEWS_RELATED', '新聞關聯');

  const ReasonType(this.code, this.label);

  final String code;
  final String label;

  int get score => switch (this) {
    ReasonType.reversalW2S => RuleScores.reversalW2S,
    ReasonType.reversalS2W => RuleScores.reversalS2W,
    ReasonType.techBreakout => RuleScores.techBreakout,
    ReasonType.techBreakdown => RuleScores.techBreakdown,
    ReasonType.volumeSpike => RuleScores.volumeSpike,
    ReasonType.priceSpike => RuleScores.priceSpike,
    ReasonType.institutionalShift => RuleScores.institutionalShift,
    ReasonType.newsRelated => RuleScores.newsRelated,
  };
}

/// Trend state for analysis
enum TrendState {
  up('UP', '上升'),
  down('DOWN', '下跌'),
  range('RANGE', '盤整');

  const TrendState(this.code, this.label);

  final String code;
  final String label;
}

/// Reversal state for analysis
enum ReversalState {
  none('NONE', '無'),
  weakToStrong('W2S', '弱轉強'),
  strongToWeak('S2W', '強轉弱');

  const ReversalState(this.code, this.label);

  final String code;
  final String label;
}

/// News category
enum NewsCategory {
  earnings('EARNINGS', '財報'),
  policy('POLICY', '政策'),
  industry('INDUSTRY', '產業'),
  companyEvent('COMPANY_EVENT', '公司事件'),
  other('OTHER', '其他');

  const NewsCategory(this.code, this.label);

  final String code;
  final String label;
}

/// Update run status
enum UpdateStatus {
  success('SUCCESS'),
  failed('FAILED'),
  partial('PARTIAL');

  const UpdateStatus(this.code);

  final String code;
}

/// Stock market type
enum StockMarket {
  twse('TWSE', '上市'),
  tpex('TPEx', '上櫃');

  const StockMarket(this.code, this.label);

  final String code;
  final String label;
}
