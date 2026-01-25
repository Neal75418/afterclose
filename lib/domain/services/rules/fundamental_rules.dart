import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
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
    if (history == null || history.isEmpty) {
      return null;
    }

    final today = history.last;
    final todayNet = today.foreignNet ?? 0.0;

    // 提高門檻以減少雜訊：最低 1000 張
    if (todayNet.abs() < 1000) return null;

    // 若有足夠資料則計算先前平均方向
    double prevAvg = 0;
    final hasHistory = history.length >= 4;

    if (hasHistory) {
      final prevEntries = history.reversed.skip(1).take(5).toList();
      if (prevEntries.isNotEmpty) {
        double prevNetSum = 0;
        for (var e in prevEntries) {
          prevNetSum += (e.foreignNet ?? 0.0);
        }
        prevAvg = prevNetSum / prevEntries.length;
      }
    }

    // 手動計算價格變動與當前收盤價
    double priceChange = 0;
    double todayClose = 0;
    double priceChangePercent = 0;

    if (data.prices.isNotEmpty) {
      final todayPrice = data.prices.last;
      todayClose = todayPrice.close ?? 0;

      if (data.prices.length >= 2) {
        final prevPrice = data.prices[data.prices.length - 2];
        if (todayPrice.close != null && prevPrice.close != null) {
          priceChange = todayPrice.close! - prevPrice.close!;
          priceChangePercent = priceChange / prevPrice.close!;
        }
      }
    }

    bool triggered = false;
    String description = '';

    // 取得今日成交量以供比率檢查
    double todayVolume = 0;
    if (data.prices.isNotEmpty) {
      todayVolume = data.prices.last.volume ?? 0;
    }

    // 單位換算：1 張 = 1000 股
    const int sheetToShares = 1000;

    // 若收盤價為 0/無效或成交量過低（< 2000 張）則忽略
    if (todayClose <= 0 || todayVolume < 2000 * sheetToShares) return null;

    // 提高比率門檻以提升精準度
    const double significantRatio = 0.35; // 佔總成交量 35%
    const double explosiveRatio = 0.50; // 佔總成交量 50%

    // 計算比率 - 重要：先將 todayNet 從張轉換為股！
    // todayNet 單位為張，todayVolume 單位為股
    // 1 張 = 1000 股
    final todayNetShares = todayNet.abs() * sheetToShares;
    final ratio = todayNetShares / todayVolume;

    // 依歷史資料判斷的訊號（反轉 / 加速）
    if (hasHistory) {
      // 情境 1：反轉（賣轉買）- 提高門檻
      if (prevAvg < -100 * sheetToShares &&
          todayNet > 500 * sheetToShares &&
          priceChange > todayClose * 0.015 &&
          ratio > significantRatio) {
        triggered = true;
        description = '外資由賣轉買 (佈局)';
      }
      // 情境 2：反轉（買轉賣）- 提高門檻
      else if (prevAvg > 100 * sheetToShares &&
          todayNet < -500 * sheetToShares &&
          priceChange < -todayClose * 0.015 &&
          ratio > significantRatio) {
        triggered = true;
        description = '外資由買轉賣 (獲利)';
      }
      // 情境 3：加速（買超擴大）- 提高門檻
      else if (prevAvg > 100 * sheetToShares &&
          todayNet > prevAvg * 2.0 &&
          todayNet > 1000 * sheetToShares &&
          ratio > explosiveRatio) {
        triggered = true;
        description = '外資買超擴大 (搶進)';
      }
      // 情境 4：加速（賣超擴大）- 提高門檻
      else if (prevAvg < -100 * sheetToShares &&
          todayNet < prevAvg * 2.0 &&
          todayNet < -1000 * sheetToShares &&
          ratio > explosiveRatio) {
        triggered = true;
        description = '外資賣超擴大 (出脫)';
      }
    }

    // 通用捕捉：顯著單日動作（若未被歷史邏輯觸發）
    // 提高門檻並要求價格配合
    if (!triggered) {
      // 情境 5：顯著買超（> 5000 張且 > 35% 且價格上漲 > 1%）
      if (todayNet > 5000 * sheetToShares &&
          ratio > significantRatio &&
          priceChangePercent > 0.01) {
        triggered = true;
        description = '外資顯著買超 (${(todayNet / sheetToShares).round()}張)';
      }
      // 情境 6：顯著賣超（< -5000 張且 > 35% 且價格下跌 > 1%）
      else if (todayNet < -5000 * sheetToShares &&
          ratio > significantRatio &&
          priceChangePercent < -0.01) {
        triggered = true;
        description = '外資顯著賣超 (${(todayNet.abs() / sheetToShares).round()}張)';
      }
    }

    if (triggered) {
      return TriggeredReason(
        type: todayNet > 0
            ? ReasonType.institutionalBuy
            : ReasonType.institutionalSell,
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
    final news = data.news;
    if (news == null || news.isEmpty) return null;

    // 分析今日新聞（或驗證非常近期的新聞）
    final now = DateTime.now();
    final recentNews = news.where((n) {
      final age = now.difference(n.publishedAt).inHours;
      return age < 120; // 5 日內的新聞（120 小時）
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
