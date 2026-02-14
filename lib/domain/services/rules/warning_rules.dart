import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==================================================
// Killer Features：注意/處置股票規則
// ==================================================

/// 規則：注意股票
///
/// 當股票被列入注意股票時觸發（風險警示）
class TradingWarningAttentionRule extends StockRule {
  const TradingWarningAttentionRule();

  @override
  String get id => 'trading_warning_attention';

  @override
  String get name => '注意股票';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final warningData = context.marketData?.warningData;
    if (warningData == null) return null;

    // 當股票被列入注意股票時觸發
    if (warningData.isAttention && !warningData.isDisposal) {
      return TriggeredReason(
        type: ReasonType.tradingWarningAttention,
        score: RuleScores.tradingWarningAttention,
        description: warningData.reasonDescription ?? '被列入注意股票',
        evidence: {
          'warningType': warningData.warningType,
          'reason': warningData.reasonDescription,
        },
      );
    }

    return null;
  }
}

/// 規則：處置股票
///
/// 當股票被列入處置股票時觸發（高風險，大幅扣分）
class TradingWarningDisposalRule extends StockRule {
  const TradingWarningDisposalRule();

  @override
  String get id => 'trading_warning_disposal';

  @override
  String get name => '處置股票';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final warningData = context.marketData?.warningData;
    if (warningData == null) return null;

    // 當股票被列入處置股票時觸發（-50 分確保不進入推薦）
    if (warningData.isDisposal) {
      final description = StringBuffer('被列入處置股票');
      if (warningData.disposalMeasures != null) {
        description.write('（${warningData.disposalMeasures}）');
      }
      if (warningData.disposalEndDate != null) {
        final endDate = warningData.disposalEndDate!;
        description.write(
          '，處置期限至 ${endDate.year}/${endDate.month}/${endDate.day}',
        );
      }

      return TriggeredReason(
        type: ReasonType.tradingWarningDisposal,
        score: RuleScores.tradingWarningDisposal,
        description: description.toString(),
        evidence: {
          'warningType': warningData.warningType,
          'reason': warningData.reasonDescription,
          'measures': warningData.disposalMeasures,
          'endDate': warningData.disposalEndDate?.toIso8601String(),
        },
      );
    }

    return null;
  }
}
