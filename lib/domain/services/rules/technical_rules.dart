import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 反轉規則
// ==========================================

class WeakToStrongRule extends StockRule {
  const WeakToStrongRule();

  @override
  String get id => 'reversal_w2s';

  @override
  String get name => '弱轉強';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (context.reversalState == ReversalState.weakToStrong) {
      return TriggeredReason(
        type: ReasonType.reversalW2S,
        score: RuleScores.reversalW2S,
        description: '底部型態確立 / 突破區間整理',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
  }
}

class StrongToWeakRule extends StockRule {
  const StrongToWeakRule();

  @override
  String get id => 'reversal_s2w';

  @override
  String get name => '強轉弱';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // 注意：MA20 過濾已在 detectReversalState._hasLowerHigh() 中處理
    // 這裡不再重複檢查，避免雙重過濾導致觸發次數過少
    if (context.reversalState == ReversalState.strongToWeak) {
      return TriggeredReason(
        type: ReasonType.reversalS2W,
        score: RuleScores.reversalS2W,
        description: '頭部型態確立 / 跌破支撐',
        evidence: {'trend': context.trendState.toString()},
      );
    }
    return null;
  }
}

// ==========================================
// 突破/跌破規則
// ==========================================

class BreakoutRule extends StockRule {
  const BreakoutRule();

  @override
  String get id => 'tech_breakout';

  @override
  String get name => '向上突破';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    if (context.resistanceLevel != null) {
      // 使用突破緩衝區（1%）
      final breakoutLevel =
          context.resistanceLevel! * (1 + RuleParams.breakoutBuffer);
      if (close > breakoutLevel) {
        // MA20 過濾：需站上 MA20 才確認有效突破
        final ma20 = _calculateMA20(data.prices);
        if (ma20 != null && close < ma20) return null;

        // 成交量確認：需有量能配合
        if (!_hasBreakoutVolume(data.prices)) return null;

        return TriggeredReason(
          type: ReasonType.techBreakout,
          score: RuleScores.techBreakout,
          description: '突破關鍵壓力位',
          evidence: {
            'close': close,
            'resistance': context.resistanceLevel,
            'breakoutLevel': breakoutLevel,
          },
        );
      }
    }
    return null;
  }
}

class BreakdownRule extends StockRule {
  const BreakdownRule();

  @override
  String get id => 'tech_breakdown';

  @override
  String get name => '向下跌破';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    if (context.supportLevel != null) {
      // 使用跌破緩衝區（1%）
      final breakdownLevel =
          context.supportLevel! * (1 - RuleParams.breakdownBuffer);
      if (close < breakdownLevel) {
        // MA20 過濾：需跌破 MA20 才確認有效跌破
        final ma20 = _calculateMA20(data.prices);
        if (ma20 != null && close > ma20) return null;

        // 成交量確認：需有量能配合
        if (!_hasBreakoutVolume(data.prices)) return null;

        return TriggeredReason(
          type: ReasonType.techBreakdown,
          score: RuleScores.techBreakdown,
          description: '跌破關鍵支撐位',
          evidence: {
            'close': close,
            'support': context.supportLevel,
            'breakdownLevel': breakdownLevel,
          },
        );
      }
    }
    return null;
  }
}

// ==========================================
// 輔助方法
// ==========================================

/// 計算 MA20
double? _calculateMA20(List<DailyPriceEntry> prices) {
  if (prices.length < 20) return null;

  double sum = 0;
  int count = 0;

  for (var i = prices.length - 1; i >= prices.length - 20; i--) {
    final close = prices[i].close;
    if (close != null) {
      sum += close;
      count++;
    }
  }

  if (count < 20) return null;
  return sum / count;
}

/// 檢查是否有突破/跌破所需的成交量
///
/// 今日成交量需達 20 日均量的 1.2 倍
bool _hasBreakoutVolume(List<DailyPriceEntry> prices) {
  if (prices.length < 21) return true; // 資料不足則放行

  final todayVolume = prices.last.volume;
  if (todayVolume == null || todayVolume <= 0) return false;

  // 計算前 20 日平均成交量
  double sum = 0;
  int count = 0;

  for (var i = prices.length - 2; i >= prices.length - 21 && i >= 0; i--) {
    final vol = prices[i].volume;
    if (vol != null && vol > 0) {
      sum += vol;
      count++;
    }
  }

  if (count == 0) return true; // 無歷史資料則放行

  final avgVolume = sum / count;
  return todayVolume >= avgVolume * RuleParams.reversalVolumeConfirm;
}
