/// Chip (籌碼) strength analysis result.
///
/// Computed from institutional flow, foreign shareholding,
/// margin trading, day trading, holding distribution, and insider data.
class ChipStrengthResult {
  const ChipStrengthResult({
    required this.score,
    required this.rating,
    required this.attitude,
    this.details = const [],
  });

  /// Overall chip strength score (0-100).
  final int score;

  /// Rating category derived from score.
  final ChipRating rating;

  /// Institutional attitude summary.
  final InstitutionalAttitude attitude;

  /// Human-readable breakdown of score components.
  final List<String> details;
}

/// Chip strength rating levels.
///
/// 基底分為 0，評級邊界配合 0-based 分佈調整。
enum ChipRating {
  strong, // 70-100
  bullish, // 50-69
  neutral, // 25-49
  bearish, // 10-24
  weak; // 0-9

  String get i18nKey => switch (this) {
    ChipRating.strong => 'chip.ratingStrong',
    ChipRating.bullish => 'chip.ratingBullish',
    ChipRating.neutral => 'chip.ratingNeutral',
    ChipRating.bearish => 'chip.ratingBearish',
    ChipRating.weak => 'chip.ratingWeak',
  };

  static ChipRating fromScore(int score) {
    if (score >= 70) return ChipRating.strong;
    if (score >= 50) return ChipRating.bullish;
    if (score >= 25) return ChipRating.neutral;
    if (score >= 10) return ChipRating.bearish;
    return ChipRating.weak;
  }
}

/// Institutional attitude derived from recent buy/sell patterns.
enum InstitutionalAttitude {
  aggressiveBuy,
  moderateBuy,
  neutral,
  moderateSell,
  aggressiveSell;

  String get i18nKey => switch (this) {
    InstitutionalAttitude.aggressiveBuy => 'chip.attitudeAggressiveBuy',
    InstitutionalAttitude.moderateBuy => 'chip.attitudeModerateBuy',
    InstitutionalAttitude.neutral => 'chip.attitudeNeutral',
    InstitutionalAttitude.moderateSell => 'chip.attitudeModerateSell',
    InstitutionalAttitude.aggressiveSell => 'chip.attitudeAggressiveSell',
  };
}
