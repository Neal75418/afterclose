import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==================================================
// 第 4 階段：法人連續買賣規則
// ==================================================

/// 規則：法人連買
///
/// 當外資連續 N 日買超時觸發
class InstitutionalBuyStreakRule extends StockRule {
  const InstitutionalBuyStreakRule();

  @override
  String get id => 'institutional_buy_streak';

  @override
  String get name => '法人連買';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.institutional;
    if (history == null ||
        history.length < RuleParams.institutionalStreakDays) {
      return null;
    }

    // 檢查連續買超日 - 掃描整個歷史以取得完整連續天數
    // 注意：資料單位為「股」，1張 = 1000股
    int streakDays = 0;
    double totalForeignNet = 0;
    double totalTrustNet = 0;
    int significantDays = 0; // 單日淨買超 > 300張（300000股）的天數

    // 從最近日期往回檢查直到連續中斷
    for (int i = history.length - 1; i >= 0; i--) {
      final entry = history[i];
      final foreignNet = entry.foreignNet ?? 0;
      final trustNet = entry.investmentTrustNet ?? 0;
      final combinedNet = foreignNet + trustNet;

      // 考量合併的法人動向（外資 + 投信）
      // 需要淨買超 > 100張（100,000股）才算有效買超日（過濾微量波動）
      if (combinedNet > RuleParams.institutionalMinDailyNetShares) {
        streakDays++;
        totalForeignNet += foreignNet;
        totalTrustNet += trustNet;
        if (combinedNet > RuleParams.institutionalSignificantDailyNetShares) {
          significantDays++;
        }
      } else {
        break; // 連續中斷 - 必須是真正連續
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      final totalNet = totalForeignNet + totalTrustNet;
      final dailyAvg = totalNet / streakDays;

      // 診斷日誌：記錄達到連續天數門檻的股票
      AppLogger.debug(
        'InstBuyRule',
        '${data.symbol}: 連續 $streakDays 日買超, 總量=${totalNet.round()}股, '
            '日均=${dailyAvg.round()}股, 顯著天數=$significantDays',
      );

      // 過濾條件 1：總淨買超須 > 5000張（5,000,000股）
      if (totalNet <= RuleParams.institutionalBuyTotalThresholdShares) {
        return null;
      }

      // 過濾條件 2：日均淨買超須 > 700張（700,000股）
      if (dailyAvg <= RuleParams.institutionalBuyDailyAvgThresholdShares) {
        return null;
      }

      // 過濾條件 3：至少一半的天數有顯著買超（> 300張/日）
      if (significantDays < streakDays / 2) return null;

      // 轉換為張顯示（1張 = 1000股）
      final foreignSheets = (totalForeignNet / 1000).round();
      final trustSheets = (totalTrustNet / 1000).round();

      // 投信主導加分：投信為主動型法人，買超更具意圖性
      final isTrustDominant =
          totalTrustNet > 0 && totalTrustNet > totalForeignNet;
      final score = isTrustDominant
          ? RuleScores.institutionalBuyStreak + 5
          : RuleScores.institutionalBuyStreak;

      return TriggeredReason(
        type: ReasonType.institutionalBuyStreak,
        score: score,
        description:
            '法人連續買超 $streakDays 日 (外資 $foreignSheets 張, 投信 $trustSheets 張)',
        evidence: {
          'streakDays': streakDays,
          'foreignNet': totalForeignNet,
          'trustNet': totalTrustNet,
          'totalNet': totalNet,
          'dailyAvg': dailyAvg.round(),
          'trustDominant': isTrustDominant,
        },
      );
    }

    return null;
  }
}

/// 規則：法人連賣
///
/// 當外資連續 N 日賣超時觸發
class InstitutionalSellStreakRule extends StockRule {
  const InstitutionalSellStreakRule();

  @override
  String get id => 'institutional_sell_streak';

  @override
  String get name => '法人連賣';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.institutional;
    if (history == null ||
        history.length < RuleParams.institutionalStreakDays) {
      return null;
    }

    // 檢查連續賣超日 - 掃描整個歷史以取得完整連續天數
    // 注意：資料單位為「股」，1張 = 1000股
    int streakDays = 0;
    double totalForeignNet = 0;
    double totalTrustNet = 0;
    int significantDays = 0; // 單日淨賣超 < -300張（-300000股）的天數

    for (int i = history.length - 1; i >= 0; i--) {
      final entry = history[i];
      final foreignNet = entry.foreignNet ?? 0;
      final trustNet = entry.investmentTrustNet ?? 0;
      final combinedNet = foreignNet + trustNet;

      // 考量合併的法人賣壓
      // 需要淨賣超 < -100張（-100,000股）才算有效賣超日（過濾微量波動）
      if (combinedNet < -RuleParams.institutionalMinDailyNetShares) {
        streakDays++;
        totalForeignNet += foreignNet;
        totalTrustNet += trustNet;
        if (combinedNet < -RuleParams.institutionalSignificantDailyNetShares) {
          significantDays++;
        }
      } else {
        break; // 連續中斷
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      final totalNet = totalForeignNet + totalTrustNet;
      final dailyAvg = totalNet / streakDays;

      // 診斷日誌：記錄達到連續天數門檻的股票
      AppLogger.debug(
        'InstSellRule',
        '${data.symbol}: 連續 $streakDays 日賣超, 總量=${totalNet.round()}股, '
            '日均=${dailyAvg.round()}股, 顯著天數=$significantDays',
      );

      // 過濾條件 1：總淨賣超須 < -15000張（-15,000,000股）
      if (totalNet >= RuleParams.institutionalSellTotalThresholdShares) {
        AppLogger.debug(
          'InstSellRule',
          '${data.symbol}: 未達總量門檻 ${RuleParams.institutionalSellTotalThresholdShares} 股',
        );
        return null;
      }

      // 過濾條件 2：日均淨賣超須 < -2000張（-2,000,000股）
      if (dailyAvg >= RuleParams.institutionalSellDailyAvgThresholdShares) {
        AppLogger.debug(
          'InstSellRule',
          '${data.symbol}: 未達日均門檻 ${RuleParams.institutionalSellDailyAvgThresholdShares} 股',
        );
        return null;
      }

      // 過濾條件 3：至少一半的天數有顯著賣超（< -300張/日）
      if (significantDays < streakDays / 2) return null;

      // 轉換為張顯示（1張 = 1000股）
      final foreignSheets = (totalForeignNet.abs() / 1000).round();
      final trustSheets = (totalTrustNet.abs() / 1000).round();

      // 投信主導賣超更負面：投信為主動型法人，賣超更具意圖性
      final isTrustDominant =
          totalTrustNet < 0 && totalTrustNet.abs() > totalForeignNet.abs();
      final score = isTrustDominant
          ? RuleScores.institutionalSellStreak - 5
          : RuleScores.institutionalSellStreak;

      return TriggeredReason(
        type: ReasonType.institutionalSellStreak,
        score: score,
        description:
            '法人連續賣超 $streakDays 日 (外資 $foreignSheets 張, 投信 $trustSheets 張)',
        evidence: {
          'streakDays': streakDays,
          'foreignNet': totalForeignNet,
          'trustNet': totalTrustNet,
          'totalNet': totalNet,
          'dailyAvg': dailyAvg.round(),
          'trustDominant': isTrustDominant,
        },
      );
    }

    return null;
  }
}
