import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_scores.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/domain/models/analysis_context.dart';
import 'package:afterclose/domain/models/triggered_reason.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

/// MA 穿越事件規則(2026-07-31)。
///
/// 站回月線/季線=**修復期領先者偵測**:V 轉後率先修復的股票 60D 報酬
/// 多半還是負的、進不了 Mode B(強勢),又不是超跌反彈訊號(Mode A)——
/// 正好落在 A/B 之間的縫隙,這兩條就是為那個縫隙生的。跌破=持股風控
/// 對稱版。
///
/// **設計取捨**:
/// - **不加多頭 regime gate**(與回檔規則相反):修復期偵測器的主場
///   正是大盤 regime 未翻多時;跌破警示則在轉空時最需要。回檔規則要
///   gate 是因為「空頭回檔=接刀」,穿越事件沒有這個語意。
/// - **穿越判定用今日 MA 近似**(昨收與今收都對今日 MA 比):MA 日變化
///   遠小於價格穿越幅度,省下重算昨日 MA 的成本,誤差僅影響壓線邊界。
/// - **neutral ±8 起步**:零歷史紀錄的訊號不進 3-tab 計分,先落
///   daily_reason 供掃描與 rule_accuracy 累積,一季後由校準實證判決
///   升格或歸零——分數唯一正確的制定方式是實證管道。
/// - **ETF guard**:與回檔規則同判斷,平滑走勢的穿越是雜訊。
class ReclaimMa20Rule extends StockRule {
  const ReclaimMa20Rule();

  @override
  String get id => 'reclaim_ma20';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) =>
      _evaluateCross(
        context,
        data,
        maSelector: (ind) => ind.ma20,
        maKey: 'ma20',
        reclaim: true,
        type: ReasonType.reclaimMa20,
        score: RuleScores.reclaimMa20,
        description: '站回月線 (MA20)',
      );
}

class ReclaimMa60Rule extends StockRule {
  const ReclaimMa60Rule();

  @override
  String get id => 'reclaim_ma60';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) =>
      _evaluateCross(
        context,
        data,
        maSelector: (ind) => ind.ma60,
        maKey: 'ma60',
        reclaim: true,
        type: ReasonType.reclaimMa60,
        score: RuleScores.reclaimMa60,
        description: '站回季線 (MA60)',
      );
}

class BreakMa20Rule extends StockRule {
  const BreakMa20Rule();

  @override
  String get id => 'break_ma20';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) =>
      _evaluateCross(
        context,
        data,
        maSelector: (ind) => ind.ma20,
        maKey: 'ma20',
        reclaim: false,
        type: ReasonType.breakMa20,
        score: RuleScores.breakMa20,
        description: '跌破月線 (MA20)',
      );
}

class BreakMa60Rule extends StockRule {
  const BreakMa60Rule();

  @override
  String get id => 'break_ma60';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) =>
      _evaluateCross(
        context,
        data,
        maSelector: (ind) => ind.ma60,
        maKey: 'ma60',
        reclaim: false,
        type: ReasonType.breakMa60,
        score: RuleScores.breakMa60,
        description: '跌破季線 (MA60)',
      );
}

TriggeredReason? _evaluateCross(
  AnalysisContext context,
  StockData data, {
  required double? Function(dynamic ind) maSelector,
  required String maKey,
  required bool reclaim,
  required ReasonType type,
  required int score,
  required String description,
}) {
  if (StockPatterns.isEtfCode(data.symbol)) return null;

  final ind = context.indicators;
  if (ind == null) return null;
  final ma = maSelector(ind);
  if (ma == null) return null;

  if (data.prices.length < 2) return null;
  final close = data.prices.last.close;
  final prevClose = data.prices[data.prices.length - 2].close;
  if (close == null || prevClose == null) return null;

  final crossed = reclaim
      ? (prevClose <= ma && close > ma)
      : (prevClose >= ma && close < ma);
  if (!crossed) return null;

  return TriggeredReason(
    type: type,
    score: score,
    description: description,
    evidence: {
      maKey: ma,
      'close': close,
      'prevClose': prevClose,
      'distancePct': (close - ma) / ma * 100,
    },
  );
}
