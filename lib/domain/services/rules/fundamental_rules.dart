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
    if (history == null || history.isEmpty) {
      return null;
    }

    final today = history.last;
    final todayNet = today.foreignNet ?? 0.0;

    if (todayNet.abs() < 50) return null; // 忽略小波動（< 50 張）

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

    if (data.prices.isNotEmpty) {
      final todayPrice = data.prices.last;
      todayClose = todayPrice.close ?? 0;

      if (data.prices.length >= 2) {
        final prevPrice = data.prices[data.prices.length - 2];
        if (todayPrice.close != null && prevPrice.close != null) {
          priceChange = todayPrice.close! - prevPrice.close!;
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

    // 若收盤價為 0/無效或成交量過低（< 1000 張）則忽略
    // 從 5000 降低以符合新的流動性要求
    if (todayClose <= 0 || todayVolume < 1000 * sheetToShares) return null;

    // 使用較低比率判斷顯著性
    const double significantRatio = 0.25; // 佔總成交量 25%
    const double explosiveRatio = 0.30; // 佔總成交量 30%

    // 計算比率 - 重要：先將 todayNet 從張轉換為股！
    // todayNet 單位為張，todayVolume 單位為股
    // 1 張 = 1000 股
    final todayNetShares = todayNet.abs() * sheetToShares;
    final ratio = todayNetShares / todayVolume;

    // 依歷史資料判斷的訊號（反轉 / 加速）
    if (hasHistory) {
      // 情境 1：反轉（賣轉買）
      if (prevAvg < -50 * sheetToShares &&
          todayNet > 200 * sheetToShares &&
          priceChange > todayClose * 0.01 &&
          ratio > significantRatio) {
        triggered = true;
        description = '外資由賣轉買 (佈局)';
      }
      // 情境 2：反轉（買轉賣）
      else if (prevAvg > 50 * sheetToShares &&
          todayNet < -200 * sheetToShares &&
          priceChange < -todayClose * 0.01 &&
          ratio > significantRatio) {
        triggered = true;
        description = '外資由買轉賣 (獲利)';
      }
      // 情境 3：加速（買超擴大）
      else if (prevAvg > 50 * sheetToShares &&
          todayNet > prevAvg * 1.5 &&
          todayNet > 500 * sheetToShares &&
          ratio > explosiveRatio) {
        triggered = true;
        description = '外資買超擴大 (搶進)';
      }
      // 情境 4：加速（賣超擴大）
      else if (prevAvg < -50 * sheetToShares &&
          todayNet < prevAvg * 1.5 &&
          todayNet < -500 * sheetToShares &&
          ratio > explosiveRatio) {
        triggered = true;
        description = '外資賣超擴大 (出脫)';
      }
    }

    // 通用捕捉：顯著單日動作（若未被歷史邏輯觸發）
    if (!triggered) {
      // 情境 5：顯著買超（> 2500 張且 > 25%）
      if (todayNet > 2500 * sheetToShares && ratio > significantRatio) {
        triggered = true;
        description = '外資顯著買超 (${(todayNet / sheetToShares).round()}張)';
      }
      // 情境 6：顯著賣超（< -2500 張且 > 25%）
      else if (todayNet < -2500 * sheetToShares && ratio > significantRatio) {
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
    if (data.news == null || data.news!.isEmpty) return null;

    // 分析今日新聞（或驗證非常近期的新聞）
    final now = DateTime.now();
    final recentNews = data.news!.where((n) {
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
