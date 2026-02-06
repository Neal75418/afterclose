/// 籌碼強度分析結果
///
/// 綜合法人進出、外資持股比例、融資融券、當沖比例、
/// 持股集中度、內部人持股等面向計算。
class ChipStrengthResult {
  const ChipStrengthResult({
    required this.score,
    required this.rating,
    required this.attitude,
    this.details = const [],
  });

  /// 籌碼強度總分（0-100）
  final int score;

  /// 依分數判定的評級
  final ChipRating rating;

  /// 法人態度摘要
  final InstitutionalAttitude attitude;

  /// 各評分項目的文字說明
  final List<String> details;
}

/// 籌碼強度評級
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

/// 法人態度：根據近期買賣超模式判定
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
