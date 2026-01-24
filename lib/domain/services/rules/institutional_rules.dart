import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 第 4 階段：法人連續買賣規則
// ==========================================

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
    int streakDays = 0;
    double totalForeignNet = 0;
    double totalTrustNet = 0;

    // 從最近日期往回檢查直到連續中斷
    for (int i = history.length - 1; i >= 0; i--) {
      final entry = history[i];
      final foreignNet = entry.foreignNet ?? 0;
      final trustNet = entry.investmentTrustNet ?? 0;
      final combinedNet = foreignNet + trustNet;

      // 考量合併的法人動向（外資 + 投信）
      if (combinedNet > 0) {
        streakDays++;
        totalForeignNet += foreignNet;
        totalTrustNet += trustNet;
      } else {
        break; // 連續中斷 - 必須是真正連續
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      // 過濾條件：總淨買超須 > 3000 張
      // 備註：foreignNet/trustNet 已以張為單位儲存
      final totalNet = totalForeignNet + totalTrustNet;
      if (totalNet <= 3000) return null; // 最低 3000 張

      final foreignSheets = totalForeignNet.round();
      final trustSheets = totalTrustNet.round();

      return TriggeredReason(
        type: ReasonType.institutionalBuyStreak,
        score: RuleScores.institutionalBuyStreak,
        description:
            '法人連續買超 $streakDays 日 (外資 $foreignSheets 張, 投信 $trustSheets 張)',
        evidence: {
          'streakDays': streakDays,
          'foreignNet': totalForeignNet,
          'trustNet': totalTrustNet,
          'totalNet': totalNet,
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
    int streakDays = 0;
    double totalForeignNet = 0;
    double totalTrustNet = 0;

    for (int i = history.length - 1; i >= 0; i--) {
      final entry = history[i];
      final foreignNet = entry.foreignNet ?? 0;
      final trustNet = entry.investmentTrustNet ?? 0;
      final combinedNet = foreignNet + trustNet;

      // 考量合併的法人賣壓
      if (combinedNet < 0) {
        streakDays++;
        totalForeignNet += foreignNet;
        totalTrustNet += trustNet;
      } else {
        break; // 連續中斷
      }
    }

    if (streakDays >= RuleParams.institutionalStreakDays) {
      // 過濾條件：總淨賣超須 < -3000 張
      // 備註：foreignNet/trustNet 已以張為單位儲存
      final totalNet = totalForeignNet + totalTrustNet;
      if (totalNet >= -3000) return null; // 最低 -3000 張

      final foreignSheets = totalForeignNet.abs().round();
      final trustSheets = totalTrustNet.abs().round();

      return TriggeredReason(
        type: ReasonType.institutionalSellStreak,
        score: RuleScores.institutionalSellStreak,
        description:
            '法人連續賣超 $streakDays 日 (外資 $foreignSheets 張, 投信 $trustSheets 張)',
        evidence: {
          'streakDays': streakDays,
          'foreignNet': totalForeignNet,
          'trustNet': totalTrustNet,
          'totalNet': totalNet,
        },
      );
    }

    return null;
  }
}
