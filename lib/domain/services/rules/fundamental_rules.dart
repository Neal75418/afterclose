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

    // 提高門檻以減少雜訊：最低 1000 張（資料單位為股，1 張 = 1000 股）
    if (todayNet.abs() < RuleParams.institutionalMinVolumeShares) return null;

    // 若有足夠資料則計算先前平均方向
    double prevAvg = 0;
    final hasHistory = history.length >= 4;

    if (hasHistory) {
      final prevEntries = history.reversed
          .skip(1)
          .take(RuleParams.institutionalDirectionSampleSize)
          .toList();
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

    // 若收盤價為 0/無效或成交量過低（< 2000 張）則忽略
    if (todayClose <= 0 ||
        todayVolume < RuleParams.institutionalValidVolumeShares) {
      return null;
    }

    // 計算比率 - todayNet 與 todayVolume 單位皆為股
    final ratio = todayNet.abs() / todayVolume;

    // 依歷史資料判斷的訊號（反轉 / 加速）
    if (hasHistory) {
      // 情境 1：反轉（賣轉買）- 提高門檻
      if (prevAvg < -RuleParams.institutionalSmallShares &&
          todayNet > RuleParams.institutionalReversalShares &&
          priceChange > todayClose * RuleParams.minPriceChangeForVolume &&
          ratio > RuleParams.institutionalSignificantRatio) {
        triggered = true;
        description = '外資由賣轉買 (佈局)';
      }
      // 情境 2：反轉（買轉賣）- 提高門檻
      else if (prevAvg > RuleParams.institutionalSmallShares &&
          todayNet < -RuleParams.institutionalReversalShares &&
          priceChange < -todayClose * RuleParams.minPriceChangeForVolume &&
          ratio > RuleParams.institutionalSignificantRatio) {
        triggered = true;
        description = '外資由買轉賣 (獲利)';
      }
      // 情境 3：加速（買超擴大）- 提高門檻
      else if (prevAvg > RuleParams.institutionalSmallShares &&
          todayNet > prevAvg * RuleParams.institutionalAccelerationMult &&
          todayNet > RuleParams.institutionalAccelerationMinShares &&
          ratio > RuleParams.institutionalExplosiveRatio) {
        triggered = true;
        description = '外資買超擴大 (搶進)';
      }
      // 情境 4：加速（賣超擴大）- 提高門檻
      else if (prevAvg < -RuleParams.institutionalSmallShares &&
          todayNet < prevAvg * RuleParams.institutionalAccelerationMult &&
          todayNet < -RuleParams.institutionalAccelerationMinShares &&
          ratio > RuleParams.institutionalExplosiveRatio) {
        triggered = true;
        description = '外資賣超擴大 (出脫)';
      }
    }

    // 通用捕捉：顯著單日動作（若未被歷史邏輯觸發）
    // 提高門檻並要求價格配合
    if (!triggered) {
      // 情境 5：顯著買超（> 5000 張且 > 35% 且價格上漲 > 1%）
      if (todayNet > RuleParams.institutionalLargeSignalShares &&
          ratio > RuleParams.institutionalSignificantRatio &&
          priceChangePercent > RuleParams.institutionalSignificantPriceChange) {
        triggered = true;
        description =
            '外資顯著買超 (${(todayNet / RuleParams.sheetToShares).round()}張)';
      }
      // 情境 6：顯著賣超（< -5000 張且 > 35% 且價格下跌 > 1%）
      else if (todayNet < -RuleParams.institutionalLargeSignalShares &&
          ratio > RuleParams.institutionalSignificantRatio &&
          priceChangePercent <
              -RuleParams.institutionalSignificantPriceChange) {
        triggered = true;
        description =
            '外資顯著賣超 (${(todayNet.abs() / RuleParams.sheetToShares).round()}張)';
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
      return age < RuleParams.newsLookbackHours;
    }).toList();

    if (recentNews.isEmpty) return null;

    int score = 0;
    final relevantNews = <String>[];

    for (final item in recentNews) {
      final title = item.title;
      // 合併標題和內文進行關鍵字匹配（內文可能為空）
      final content = item.content ?? '';
      final text = '$title $content';
      bool matched = false;

      for (final kw in RuleParams.newsPositiveKeywords) {
        if (text.contains(kw)) {
          // 否定詞前綴檢測：若關鍵字前方有否定詞，反轉極性
          if (_hasNegationPrefix(text, kw)) {
            score--;
          } else {
            score++;
          }
          matched = true;
        }
      }

      for (final kw in RuleParams.newsNegativeKeywords) {
        if (text.contains(kw)) {
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

  /// 否定詞前綴檢測
  ///
  /// 檢查 [keyword] 在 [text] 中出現的位置前方 4 個字內是否有否定詞。
  /// 例：「訂單取消」→ keyword「訂單」前方無否定詞，但「取消訂單」→ 有。
  static bool _hasNegationPrefix(String text, String keyword) {
    const negationWords = ['取消', '失去', '下滑', '衰退', '減少', '流失', '不再', '未能'];
    final index = text.indexOf(keyword);
    if (index <= 0) return false;

    // 取關鍵字前方最多 4 個字的文本
    final prefixStart = (index - 4).clamp(0, index);
    final prefix = text.substring(prefixStart, index);

    for (final neg in negationWords) {
      if (prefix.contains(neg)) return true;
    }

    // 也檢查關鍵字後方的否定詞（如「訂單取消」）
    final suffixEnd = (index + keyword.length + 4).clamp(0, text.length);
    final suffix = text.substring(index + keyword.length, suffixEnd);

    for (final neg in negationWords) {
      if (suffix.contains(neg)) return true;
    }

    return false;
  }
}
