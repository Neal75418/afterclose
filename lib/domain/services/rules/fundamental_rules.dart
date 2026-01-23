import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

class InstitutionalShiftRule extends StockRule {
  const InstitutionalShiftRule();

  @override
  String get id => 'institutional_shift';

  @override
  String get name => '法人動向';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.institutional;
    // Reduced from institutionalLookbackDays+1 (11) to 4 days
    // to work with the 5-day backfill in UpdateService
    if (history == null || history.length < 4) {
      return null;
    }

    final today = history.last;
    // Foreign investors are most influential in TW market
    final todayNet = today.foreignNet ?? 0.0;

    if (todayNet.abs() < 50) return null; // Ignore small noise (< 50 sheets)

    // Calculate previous average direction
    final prevEntries = history.reversed.skip(1).take(5).toList();
    if (prevEntries.isEmpty) return null;

    double prevNetSum = 0;
    for (var e in prevEntries) {
      prevNetSum += (e.foreignNet ?? 0.0);
    }
    final prevAvg = prevNetSum / prevEntries.length;

    bool triggered = false;
    String description = '';

    // Case 1: Reversal (Sell -> Buy)
    // Lowered thresholds: prevAvg < -50 (was -200), todayNet > 100 (was 500)
    if (prevAvg < -50 && todayNet > 100) {
      triggered = true;
      description = '外資由賣轉買';
    }
    // Case 2: Reversal (Buy -> Sell)
    // Lowered thresholds: prevAvg > 50 (was 200), todayNet < -100 (was -500)
    else if (prevAvg > 50 && todayNet < -100) {
      triggered = true;
      description = '外資由買轉賣';
    }
    // Case 3: Acceleration (Buy -> Strong Buy)
    // Lowered thresholds: prevAvg > 50 (was 100), todayNet > 300 (was 1000)
    else if (prevAvg > 50 && todayNet > prevAvg * 3 && todayNet > 300) {
      triggered = true;
      description = '外資買超擴大';
    }
    // Case 4: Acceleration (Sell -> Strong Sell)
    // Lowered thresholds: prevAvg < -50 (was -100), todayNet < -300 (was -1000)
    else if (prevAvg < -50 && todayNet < prevAvg * 3 && todayNet < -300) {
      triggered = true;
      description = '外資賣超擴大';
    }

    if (triggered) {
      return TriggeredReason(
        type: ReasonType.institutionalShift,
        score: RuleScores.institutionalShift,
        description: description,
        evidence: {
          'todayNet': todayNet,
          'prevAvg': prevAvg,
          'type': todayNet > 0 ? 'BUY' : 'SELL',
        },
      );
    }

    return null;
  }
}

class NewsRule extends StockRule {
  const NewsRule();

  @override
  String get id => 'news_related';

  @override
  String get name => '新聞熱度';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.news == null || data.news!.isEmpty) return null;

    // Analyze today's news (or verify very recent news)
    final now = DateTime.now();
    final recentNews = data.news!.where((n) {
      final age = now.difference(n.publishedAt).inHours;
      return age < 24; // Only news within 24 hours
    }).toList();

    if (recentNews.isEmpty) return null;

    int score = 0;
    final relevantNews = <String>[];

    for (final item in recentNews) {
      final title = item.title;
      bool matched = false;

      for (final kw in RuleParams.newsPositiveKeywords) {
        if (title.contains(kw)) {
          score++;
          matched = true;
        }
      }

      for (final kw in RuleParams.newsNegativeKeywords) {
        if (title.contains(kw)) {
          score--;
          matched = true;
        }
      }

      if (matched) relevantNews.add(title);
    }

    if (score.abs() >= 1) {
      return TriggeredReason(
        type: ReasonType.newsRelated,
        score: RuleScores.newsRelated,
        description: score > 0 ? '近期利多新聞頻發' : '近期利空新聞影響',
        evidence: {'sentiment': score, 'titles': relevantNews.take(3).toList()},
      );
    }

    return null;
  }
}
