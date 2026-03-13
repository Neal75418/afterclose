import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

// ==================================================
// 第 3 階段：技術訊號規則
// ==================================================

/// 計算價格歷史期間內的累計現金股利
///
/// 遍歷 [StockData.dividendHistory]，篩選除息日落在價格資料起始日之後的股利，
/// 回傳累計現金股利金額。用於調整 52 週新高/新低的歷史價格基準。
double _sumDividendsInPeriod(StockData data) {
  final dividends = data.dividendHistory;
  if (dividends == null || dividends.isEmpty || data.prices.isEmpty) {
    return 0;
  }

  final lookbackStart = data.prices.first.date;
  double total = 0;
  for (final div in dividends) {
    if (div.exDividendDate == null) continue;
    final exDate = DateTime.tryParse(div.exDividendDate!);
    if (exDate != null && exDate.isAfter(lookbackStart)) {
      total += div.cashDividend;
    }
  }
  return total;
}

/// 52 週新高/新低的方向
enum _Week52Direction { high, low }

/// 52 週新高/新低規則的共用基底類別
///
/// 將 [Week52HighRule] 與 [Week52LowRule] 的共同邏輯抽取至此，
/// 透過 [_direction] 參數化兩者之間的差異（極值初始值、比較方向、
/// 門檻計算、evidence key 等）。
abstract class _Week52RuleBase extends StockRule {
  const _Week52RuleBase({
    required _Week52Direction direction,
    required String ruleId,
    required String ruleName,
    required ReasonType reasonType,
    required int ruleScore,
    required double threshold,
  }) : _direction = direction,
       _ruleId = ruleId,
       _ruleName = ruleName,
       _reasonType = reasonType,
       _ruleScore = ruleScore,
       _threshold = threshold;

  final _Week52Direction _direction;
  final String _ruleId;
  final String _ruleName;
  final ReasonType _reasonType;
  final int _ruleScore;
  final double _threshold;

  @override
  String get id => _ruleId;

  @override
  String get name => _ruleName;

  /// 子類別可覆寫以加入額外過濾條件（例如 MA 空頭確認）。
  /// 回傳 true 表示應過濾掉（不觸發）。
  bool additionalFilter(
    AnalysisContext context,
    StockData data,
    double close,
  ) => false;

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final isHigh = _direction == _Week52Direction.high;

    // 診斷：資料不足時記錄
    if (data.prices.length < IndicatorParams.week52Days) {
      if (data.prices.length >= 200) {
        AppLogger.debug(
          _ruleName,
          '${data.symbol}: 資料不足 (${data.prices.length}/${IndicatorParams.week52Days})',
        );
      }
      return null;
    }

    final today = data.prices.last;
    final close = today.close;
    if (close == null) return null;

    // 從「過去」的價格歷史計算 52 週極值（排除今日）
    // 避免前瞻偏差
    double extreme = isHigh ? 0 : double.infinity;
    int validCount = 0;
    for (int i = 0; i < data.prices.length - 1; i++) {
      final p = data.prices[i];
      final value = isHigh ? (p.high ?? p.close) : (p.low ?? p.close);
      if (value == null || value <= 0) continue;
      validCount++;
      if (isHigh ? value > extreme : value < extreme) extreme = value;
    }

    // 需要足夠有效資料才有意義
    final isExtremeInvalid = isHigh
        ? extreme <= 0
        : (extreme == double.infinity || extreme <= 0);
    if (isExtremeInvalid || validCount < 20) return null;

    // 除息調整：歷史極值需調降以反映除息影響
    final totalDividend = _sumDividendsInPeriod(data);
    final adjusted = extreme - totalDividend;
    if (adjusted <= 0) return null;

    // 檢查當前收盤是否處於或接近 52 週極值（在門檻範圍內）
    final thresholdPrice = isHigh
        ? adjusted * (1 - _threshold)
        : adjusted * (1 + _threshold);
    final isInRange = isHigh
        ? close >= thresholdPrice
        : close <= thresholdPrice;

    if (isInRange) {
      final isNew = isHigh ? close >= adjusted : close <= adjusted;

      // 子類別額外過濾（例如 Week52Low 的 MA 空頭趨勢確認）
      if (additionalFilter(context, data, close)) return null;

      final extremeLabel = isHigh ? '高' : '低';
      AppLogger.debug(
        _ruleName,
        '${data.symbol}: 收盤=${close.toStringAsFixed(2)}, '
        '52週$extremeLabel=${extreme.toStringAsFixed(2)}, '
        '除息調整=${adjusted.toStringAsFixed(2)}, '
        '新$extremeLabel=$isNew',
      );
      return TriggeredReason(
        type: _reasonType,
        score: _ruleScore,
        description: isNew ? '創 52 週新$extremeLabel' : '接近 52 週新$extremeLabel',
        evidence: {
          'close': close,
          if (isHigh) 'week52High': extreme else 'week52Low': extreme,
          if (isHigh) 'adjustedHigh': adjusted else 'adjustedLow': adjusted,
          'dividendAdjustment': totalDividend,
          if (isHigh) 'isNewHigh': isNew else 'isNewLow': isNew,
        },
      );
    }

    return null;
  }
}

/// 規則：52 週新高偵測
///
/// 當收盤價處於或接近 52 週高點時觸發
class Week52HighRule extends _Week52RuleBase {
  const Week52HighRule()
    : super(
        direction: _Week52Direction.high,
        ruleId: 'week_52_high',
        ruleName: '52週新高',
        reasonType: ReasonType.week52High,
        ruleScore: RuleScores.week52High,
        threshold: IndicatorParams.week52HighThreshold,
      );
}

/// 規則：52 週新低偵測
///
/// 當收盤價處於或接近 52 週低點時觸發
class Week52LowRule extends _Week52RuleBase {
  const Week52LowRule()
    : super(
        direction: _Week52Direction.low,
        ruleId: 'week_52_low',
        ruleName: '52週新低',
        reasonType: ReasonType.week52Low,
        ruleScore: RuleScores.week52Low,
        threshold: IndicatorParams.week52LowThreshold,
      );

  /// 精準度過濾：確認近期確實處於下跌趨勢
  /// 避免長期盤整在低檔區的股票誤觸發
  @override
  bool additionalFilter(AnalysisContext context, StockData data, double close) {
    final ma20 = context.indicators?.ma20;
    final ma60 = context.indicators?.ma60;

    // 過濾條件：收盤價 < MA20 且 MA20 < MA60（空頭趨勢確認）
    if (ma20 != null && ma60 != null) {
      if (close >= ma20 || ma20 >= ma60) {
        AppLogger.debug(
          name,
          '${data.symbol}: 過濾（未確認空頭趨勢 close=$close, MA20=$ma20, MA60=$ma60）',
        );
        return true;
      }
    }
    return false;
  }
}

/// 規則：均線多頭排列
///
/// 當 MA5 > MA10 > MA20 > MA60 時觸發
class MAAlignmentBullishRule extends StockRule {
  const MAAlignmentBullishRule();

  @override
  String get id => 'ma_alignment_bullish';

  @override
  String get name => '多頭排列';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // 至少需要最大均線週期的資料
    final maxPeriod = IndicatorParams.maAlignmentPeriods.reduce(
      (a, b) => a > b ? a : b,
    );
    if (data.prices.length < maxPeriod) return null;

    final ma5 = context.indicators?.ma5;
    final ma10 = context.indicators?.ma10;
    final ma20 = context.indicators?.ma20;
    final ma60 = context.indicators?.ma60;

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // 檢查多頭排列：MA5 > MA10 > MA20 > MA60
    // 並檢查最小間距
    const minSep = IndicatorParams.maMinSeparation;
    if (ma5 > ma10 * (1 + minSep) &&
        ma10 > ma20 * (1 + minSep) &&
        ma20 > ma60 * (1 + minSep)) {
      // 過濾條件：收盤 > MA5 且乖離率不超過門檻
      // 備註：台股常有「量縮上漲」現象
      final today = data.prices.last;
      final close = today.close;
      final vol = today.volume;
      if (close == null || vol == null) return null;

      if (close <= ma5) return null;
      if ((close - ma5) / ma5 >= IndicatorParams.maDeviationThreshold) {
        return null;
      }

      final volMA20 = context.indicators?.volumeMA20 ?? 0;
      if (vol <= volMA20 * IndicatorParams.maAlignmentVolumeMultiplier) {
        return null;
      }

      return TriggeredReason(
        type: ReasonType.maAlignmentBullish,
        score: RuleScores.maAlignmentBullish,
        description: '均線多頭排列 (5>10>20>60)',
        evidence: {'ma5': ma5, 'ma10': ma10, 'ma20': ma20, 'ma60': ma60},
      );
    }

    return null;
  }
}

/// 規則：均線空頭排列
///
/// 當 MA5 < MA10 < MA20 < MA60 時觸發
class MAAlignmentBearishRule extends StockRule {
  const MAAlignmentBearishRule();

  @override
  String get id => 'ma_alignment_bearish';

  @override
  String get name => '空頭排列';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // 至少需要最大均線週期的資料
    final maxPeriod = IndicatorParams.maAlignmentPeriods.reduce(
      (a, b) => a > b ? a : b,
    );
    if (data.prices.length < maxPeriod) return null;

    final ma5 = context.indicators?.ma5;
    final ma10 = context.indicators?.ma10;
    final ma20 = context.indicators?.ma20;
    final ma60 = context.indicators?.ma60;

    if (ma5 == null || ma10 == null || ma20 == null || ma60 == null) {
      return null;
    }

    // 檢查空頭排列：MA5 < MA10 < MA20 < MA60
    const minSep = IndicatorParams.maMinSeparation;
    if (ma5 < ma10 * (1 - minSep) &&
        ma10 < ma20 * (1 - minSep) &&
        ma20 < ma60 * (1 - minSep)) {
      // 移除成交量過濾，讓更多股票能觸發
      final today = data.prices.last;
      final close = today.close;
      if (close == null) return null;

      if (close >= ma5) return null;
      if ((close - ma5) / ma5 <= -IndicatorParams.maDeviationThreshold) {
        return null;
      }

      return TriggeredReason(
        type: ReasonType.maAlignmentBearish,
        score: RuleScores.maAlignmentBearish,
        description: '均線空頭排列 (5<10<20<60)',
        evidence: {'ma5': ma5, 'ma10': ma10, 'ma20': ma20, 'ma60': ma60},
      );
    }

    return null;
  }
}

/// 規則：RSI 極度超買
///
/// 當 RSI >= 80 時觸發（高風險警示）
class RSIExtremeOverboughtRule extends StockRule {
  const RSIExtremeOverboughtRule();

  @override
  String get id => 'rsi_extreme_overbought';

  @override
  String get name => 'RSI極度超買';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < IndicatorParams.rsiPeriod + 1) return null;

    final rsi = TechnicalIndicatorService.latestRSI(
      data.prices,
      period: IndicatorParams.rsiPeriod,
    );
    if (rsi == null) return null;

    if (rsi >= IndicatorParams.rsiExtremeOverbought) {
      AppLogger.debug(
        'RSIExtremeOverbought',
        '${data.symbol}: RSI=${rsi.toStringAsFixed(1)} >= ${IndicatorParams.rsiExtremeOverbought}',
      );
      return TriggeredReason(
        type: ReasonType.rsiExtremeOverbought,
        score: RuleScores.rsiExtremeOverboughtSignal,
        description: 'RSI 極度超買 (${rsi.toStringAsFixed(1)})',
        evidence: {
          'rsi': rsi,
          'threshold': IndicatorParams.rsiExtremeOverbought,
        },
      );
    }

    return null;
  }
}

/// 規則：RSI 極度超賣
///
/// 當 RSI <= 25 時觸發（潛在反彈機會）
class RSIExtremeOversoldRule extends StockRule {
  const RSIExtremeOversoldRule();

  @override
  String get id => 'rsi_extreme_oversold';

  @override
  String get name => 'RSI極度超賣';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < IndicatorParams.rsiPeriod + 1) return null;

    final rsi = TechnicalIndicatorService.latestRSI(
      data.prices,
      period: IndicatorParams.rsiPeriod,
    );
    if (rsi == null) return null;

    if (rsi <= IndicatorParams.rsiExtremeOversold) {
      AppLogger.debug(
        'RSIExtremeOversold',
        '${data.symbol}: RSI=${rsi.toStringAsFixed(1)} <= ${IndicatorParams.rsiExtremeOversold}',
      );
      return TriggeredReason(
        type: ReasonType.rsiExtremeOversold,
        score: RuleScores.rsiExtremeOversoldSignal,
        description: 'RSI 極度超賣 (${rsi.toStringAsFixed(1)})',
        evidence: {'rsi': rsi, 'threshold': IndicatorParams.rsiExtremeOversold},
      );
    }

    return null;
  }
}

/// 規則：KD 黃金交叉
///
/// 當 K 線向上穿越 D 線時觸發，最佳情況為超賣區
class KDGoldenCrossRule extends StockRule {
  const KDGoldenCrossRule();

  @override
  String get id => 'kd_golden_cross';

  @override
  String get name => 'KD 黃金交叉';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final ind = context.indicators;
    if (ind == null ||
        ind.kdK == null ||
        ind.kdD == null ||
        ind.prevKdK == null ||
        ind.prevKdD == null) {
      return null;
    }

    final k = ind.kdK!;
    final d = ind.kdD!;
    final prevK = ind.prevKdK!;
    final prevD = ind.prevKdD!;

    // 黃金交叉：昨日 K < D，今日 K > D
    if (prevK < prevD && k > d) {
      // 過濾 1：僅在低檔區觸發
      if (prevK >= IndicatorParams.kdGoldenCrossZone) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 使用 PriceCalculator 統一計算，排除今日以正確比較
      if (!PriceCalculator.isVolumeAboveAverage(data.prices, days: 5)) {
        return null;
      }

      // 過濾 3：價格強度
      // 確認黃金交叉有實際價格動能支撐
      if (data.prices.length >= 2) {
        final today = data.prices.last;
        final prev = data.prices[data.prices.length - 2];
        if (today.close != null && prev.close != null && prev.close! > 0) {
          final changePct = (today.close! - prev.close!) / prev.close!;
          if (changePct < IndicatorParams.kdCrossPriceChangeThreshold) {
            return null;
          }
        }
      }

      final isOversold = prevK < IndicatorParams.kdOversold;

      return TriggeredReason(
        type: ReasonType.kdGoldenCross,
        score: RuleScores.kdGoldenCross,
        description: isOversold ? '低檔 KD 黃金交叉 (量增價漲)' : 'KD 黃金交叉 (低檔量增價漲)',
        evidence: {'k': k, 'd': d, 'prevK': prevK, 'prevD': prevD},
      );
    }

    return null;
  }
}

/// 規則：KD 死亡交叉
class KDDeathCrossRule extends StockRule {
  const KDDeathCrossRule();

  @override
  String get id => 'kd_death_cross';

  @override
  String get name => 'KD 死亡交叉';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final ind = context.indicators;
    if (ind == null ||
        ind.kdK == null ||
        ind.kdD == null ||
        ind.prevKdK == null ||
        ind.prevKdD == null) {
      return null;
    }

    final k = ind.kdK!;
    final d = ind.kdD!;
    final prevK = ind.prevKdK!;
    final prevD = ind.prevKdD!;

    // 死亡交叉：昨日 K > D，今日 K < D
    if (prevK > prevD && k < d) {
      // 過濾 1：僅在高檔區觸發
      if (prevK <= IndicatorParams.kdDeathCrossZone) return null;

      // 過濾 2：成交量確認（今日 > 5 日均量）
      // 使用 PriceCalculator 統一計算，排除今日以正確比較
      if (!PriceCalculator.isVolumeAboveAverage(data.prices, days: 5)) {
        return null;
      }

      final isOverbought = prevK > IndicatorParams.kdOverbought;

      return TriggeredReason(
        type: ReasonType.kdDeathCross,
        score: RuleScores.kdDeathCross,
        description: isOverbought ? '高檔 KD 死亡交叉 (量增)' : 'KD 死亡交叉 (高檔量增)',
        evidence: {'k': k, 'd': d, 'prevK': prevK, 'prevD': prevD},
      );
    }
    return null;
  }
}
