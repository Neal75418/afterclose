import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/chip_strength.dart';

/// Pure Dart service that computes a chip strength score (0-100)
/// from institutional, shareholding, margin, day trading,
/// holding distribution, and insider holding data.
class ChipAnalysisService {
  const ChipAnalysisService();

  ChipStrengthResult compute({
    required List<DailyInstitutionalEntry> institutionalHistory,
    required List<ShareholdingEntry> shareholdingHistory,
    required List<MarginTradingEntry> marginHistory,
    required List<DayTradingEntry> dayTradingHistory,
    required List<HoldingDistributionEntry> holdingDistribution,
    required List<InsiderHoldingEntry> insiderHistory,
  }) {
    int score = 50;

    // --- 1. Institutional buy/sell streak ---
    final instAdj = _institutionalAdjustment(institutionalHistory);
    score += instAdj;

    // --- 2. Foreign shareholding trend ---
    score += _shareholdingAdjustment(shareholdingHistory);

    // --- 3. Margin trading signal ---
    score += _marginAdjustment(marginHistory);

    // --- 4. Day trading ratio ---
    score += _dayTradingAdjustment(dayTradingHistory);

    // --- 5. Holding concentration ---
    score += _concentrationAdjustment(holdingDistribution);

    // --- 6. Insider holding ---
    score += _insiderAdjustment(insiderHistory);

    score = score.clamp(0, 100);

    final attitude = _deriveAttitude(institutionalHistory);

    return ChipStrengthResult(
      score: score,
      rating: ChipRating.fromScore(score),
      attitude: attitude,
    );
  }

  // ----- 1. Institutional -----

  int _institutionalAdjustment(List<DailyInstitutionalEntry> history) {
    if (history.isEmpty) return 0;

    // Sort by date ascending
    final sorted = List<DailyInstitutionalEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Take last 5 days
    final recent = sorted.length > 5
        ? sorted.sublist(sorted.length - 5)
        : sorted;

    int consecutiveBuy = 0;
    int consecutiveSell = 0;

    for (final entry in recent.reversed) {
      final netTotal =
          (entry.foreignNet ?? 0) + (entry.investmentTrustNet ?? 0);
      if (netTotal > 0) {
        consecutiveBuy++;
        if (consecutiveSell > 0) break;
      } else if (netTotal < 0) {
        consecutiveSell++;
        if (consecutiveBuy > 0) break;
      }
    }

    if (consecutiveBuy >= 4) return 20;
    if (consecutiveBuy >= 2) return 10;
    if (consecutiveSell >= 4) return -15;
    if (consecutiveSell >= 2) return -8;
    return 0;
  }

  // ----- 2. Foreign shareholding -----

  int _shareholdingAdjustment(List<ShareholdingEntry> history) {
    if (history.length < 2) return 0;

    final sorted = List<ShareholdingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final oldest = sorted.first.foreignSharesRatio ?? 0;
    final latest = sorted.last.foreignSharesRatio ?? 0;
    final diff = latest - oldest;

    if (diff >= 0.5) return 15;
    if (diff >= 0.2) return 8;
    if (diff <= -0.5) return -10;
    if (diff <= -0.2) return -5;
    return 0;
  }

  // ----- 3. Margin trading -----

  int _marginAdjustment(List<MarginTradingEntry> history) {
    if (history.length < 2) return 0;

    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Check margin balance trend (increasing = retail chasing = negative)
    int marginIncreasingDays = 0;
    int shortIncreasingDays = 0;

    for (int i = 1; i < sorted.length && i <= 5; i++) {
      final idx = sorted.length - 1 - i + 1;
      final prev = sorted[idx - 1];
      final curr = sorted[idx];
      if ((curr.marginBalance ?? 0) > (prev.marginBalance ?? 0)) {
        marginIncreasingDays++;
      }
      if ((curr.shortBalance ?? 0) > (prev.shortBalance ?? 0)) {
        shortIncreasingDays++;
      }
    }

    int adj = 0;
    // Margin balance continuously increasing = retail chasing = bearish signal
    if (marginIncreasingDays >= 4) adj -= 8;
    // Short balance continuously increasing = bearish sentiment but potential squeeze
    if (shortIncreasingDays >= 4) adj += 5;

    return adj;
  }

  // ----- 4. Day trading -----

  int _dayTradingAdjustment(List<DayTradingEntry> history) {
    if (history.isEmpty) return 0;

    final sorted = List<DayTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final latestRatio = sorted.last.dayTradingRatio ?? 0;

    // High day trading ratio = speculative = negative
    if (latestRatio >= 35) return -5;
    return 0;
  }

  // ----- 5. Holding concentration -----

  int _concentrationAdjustment(List<HoldingDistributionEntry> entries) {
    if (entries.isEmpty) return 0;

    // Sum percent for large holders (typically level >= "400-600" or shares >= 400張)
    // Levels with large share counts indicate institutional/large holder concentration
    double largeHolderPercent = 0;
    for (final entry in entries) {
      // Parse level: "1000以上" or numeric range like "800-999"
      final level = entry.level;
      if (_isLargeHolder(level)) {
        largeHolderPercent += entry.percent ?? 0;
      }
    }

    if (largeHolderPercent >= 60) return 12;
    if (largeHolderPercent >= 40) return 5;
    return 0;
  }

  bool _isLargeHolder(String level) {
    // Common TW holding distribution levels for large holders:
    // "400-600", "600-800", "800-1,000", "1,000以上"
    if (level.contains('以上')) return true;
    // Try to parse first number
    final match = RegExp(r'(\d+)').firstMatch(level.replaceAll(',', ''));
    if (match != null) {
      final num = int.tryParse(match.group(1)!) ?? 0;
      return num >= 400;
    }
    return false;
  }

  // ----- 6. Insider holding -----

  int _insiderAdjustment(List<InsiderHoldingEntry> history) {
    if (history.isEmpty) return 0;

    final sorted = List<InsiderHoldingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    int adj = 0;

    // Pledge ratio warning
    final pledge = latest.pledgeRatio ?? 0;
    if (pledge >= 30) adj -= 10;

    // Shares change
    final change = latest.sharesChange ?? 0;
    if (change > 0) {
      adj += 8; // Insider buying
    } else if (change < 0) {
      adj -= 8; // Insider selling
    }

    return adj;
  }

  // ----- Institutional attitude -----

  InstitutionalAttitude _deriveAttitude(List<DailyInstitutionalEntry> history) {
    if (history.isEmpty) return InstitutionalAttitude.neutral;

    final sorted = List<DailyInstitutionalEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent = sorted.length > 5
        ? sorted.sublist(sorted.length - 5)
        : sorted;

    double totalNet = 0;
    int buyDays = 0;
    int sellDays = 0;

    for (final entry in recent) {
      final net = (entry.foreignNet ?? 0) + (entry.investmentTrustNet ?? 0);
      totalNet += net;
      if (net > 0) buyDays++;
      if (net < 0) sellDays++;
    }

    if (buyDays >= 4 && totalNet > 0) {
      return InstitutionalAttitude.aggressiveBuy;
    }
    if (buyDays >= 3 && totalNet > 0) return InstitutionalAttitude.moderateBuy;
    if (sellDays >= 4 && totalNet < 0) {
      return InstitutionalAttitude.aggressiveSell;
    }
    if (sellDays >= 3 && totalNet < 0) {
      return InstitutionalAttitude.moderateSell;
    }
    return InstitutionalAttitude.neutral;
  }
}
