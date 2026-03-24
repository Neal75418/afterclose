import 'dart:math' as math;

import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 市場情緒分數等級
enum SentimentLevel {
  extremeFear, // 0-20
  fear, // 20-40
  neutral, // 40-60
  greed, // 60-80
  extremeGreed, // 80-100
}

/// 市場情緒計算結果
class MarketSentiment {
  const MarketSentiment({
    required this.score,
    required this.level,
    required this.subScores,
  });

  /// 綜合分數 0-100
  final double score;

  /// 情緒等級
  final SentimentLevel level;

  /// 各子指標分數 (key → 0~100)
  final Map<String, double> subScores;

  static const _empty = MarketSentiment(
    score: 50,
    level: SentimentLevel.neutral,
    subScores: {},
  );
}

/// 市場情緒計算服務
///
/// 綜合 6 項市場指標計算單一情緒分數 (0-100)。
/// 純計算，無 IO 依賴，易於單元測試。
class MarketSentimentService {
  const MarketSentimentService._();

  /// 計算市場情緒分數
  ///
  /// 所有 history 參數為 oldest→newest 時序排列。
  static MarketSentiment calculate({
    required AdvanceDecline advanceDecline,
    required List<double> institutionalNetHistory,
    required List<double> turnoverHistory,
    required List<double> marginBalanceHistory,
    LimitUpDown? limitUpDown,
    List<IndustrySummary> industries = const [],
  }) {
    final subScores = <String, double>{};

    // 1. 漲跌比 (25%) — advance / total 線性映射
    final adTotal = advanceDecline.total;
    if (adTotal > 0) {
      final ratio = advanceDecline.advance / adTotal;
      subScores['advanceRatio'] = _linearMap(ratio, 0.2, 0.8);
    }

    // 2. 法人動向 (25%) — 近10日淨額 Z-score → 0-100
    if (institutionalNetHistory.length >= 5) {
      final recent10 = institutionalNetHistory.length >= 10
          ? institutionalNetHistory.sublist(institutionalNetHistory.length - 10)
          : institutionalNetHistory;
      subScores['institutional'] = _zScoreToScore(recent10);
    }

    // 3. 成交量動能 (15%) — 今日量 / 5日均量
    if (turnoverHistory.length >= 2) {
      final today = turnoverHistory.last;
      final histDays = turnoverHistory.length >= 6
          ? turnoverHistory.sublist(
              turnoverHistory.length - 6,
              turnoverHistory.length - 1,
            )
          : turnoverHistory.sublist(0, turnoverHistory.length - 1);
      final avg = histDays.fold<double>(0, (s, v) => s + v) / histDays.length;
      if (avg > 0) {
        final volumeRatio = today / avg;
        // 0.5→0, 1.0→50, 2.0→100
        subScores['volumeMomentum'] = _linearMap(volumeRatio, 0.5, 2.0);
      }
    }

    // 4. 融資變化 (15%) — 近5日融資餘額變動方向+幅度
    if (marginBalanceHistory.length >= 2) {
      final recent5 = marginBalanceHistory.length >= 5
          ? marginBalanceHistory.sublist(marginBalanceHistory.length - 5)
          : marginBalanceHistory;
      final change = recent5.last - recent5.first;
      final base = recent5.first.abs();
      if (base > 0) {
        final changePct = change / base;
        // -5%→0, 0→50, +5%→100
        subScores['marginChange'] = _linearMap(changePct, -0.05, 0.05);
      }
    }

    // 5. 漲停跌停比 (10%)
    if (limitUpDown != null) {
      final luTotal = limitUpDown.limitUp + limitUpDown.limitDown;
      if (luTotal > 0) {
        final ratio = limitUpDown.limitUp / luTotal;
        subScores['limitRatio'] = ratio * 100;
      }
    }

    // 6. 產業廣度 (10%) — 上漲產業數/總產業數
    if (industries.isNotEmpty) {
      final upCount = industries.where((i) => i.avgChangePct > 0).length;
      subScores['industryBreadth'] = upCount / industries.length * 100;
    }

    // 加權計算
    if (subScores.isEmpty) return MarketSentiment._empty;

    const weights = {
      'advanceRatio': 0.25,
      'institutional': 0.25,
      'volumeMomentum': 0.15,
      'marginChange': 0.15,
      'limitRatio': 0.10,
      'industryBreadth': 0.10,
    };

    double totalWeight = 0;
    double weightedSum = 0;
    for (final entry in subScores.entries) {
      final w = weights[entry.key] ?? 0;
      weightedSum += entry.value * w;
      totalWeight += w;
    }

    // 有效權重正規化（某些指標可能缺失）
    final score = totalWeight > 0
        ? (weightedSum / totalWeight).clamp(0.0, 100.0)
        : 50.0;

    return MarketSentiment(
      score: score,
      level: _scoreToLevel(score),
      subScores: subScores,
    );
  }

  /// 計算歷史情緒分數序列（供趨勢 sparkline）
  ///
  /// 利用 30 日歷史資料回溯計算每日情緒分數。
  /// 歷史日缺少 limitUpDown 和 industries（合計權重 20%），
  /// 已有指標的權重會自動正規化，趨勢形狀仍正確。
  ///
  /// 所有 history 參數為 oldest→newest。
  static List<double> calculateHistoricalScores({
    required List<double> advanceRatioHistory,
    required List<double> institutionalNetHistory,
    required List<double> turnoverHistory,
    required List<double> marginBalanceHistory,
  }) {
    final minLen = [
      advanceRatioHistory.length,
      institutionalNetHistory.length,
      turnoverHistory.length,
      marginBalanceHistory.length,
    ].reduce(math.min);

    // Z-score 至少需要 5 天資料
    if (minLen < 5) return [];

    final scores = <double>[];

    for (int i = 4; i < minLen; i++) {
      final ratio = advanceRatioHistory[i].clamp(0.0, 1.0);
      final syntheticAd = AdvanceDecline(
        advance: (ratio * 1000).round(),
        decline: ((1 - ratio) * 1000).round(),
      );

      final result = calculate(
        advanceDecline: syntheticAd,
        institutionalNetHistory: institutionalNetHistory.sublist(0, i + 1),
        turnoverHistory: turnoverHistory.sublist(0, i + 1),
        marginBalanceHistory: marginBalanceHistory.sublist(0, i + 1),
      );

      scores.add(result.score);
    }

    return scores;
  }

  /// 線性映射 [low, high] → [0, 100]
  static double _linearMap(double value, double low, double high) {
    if (high <= low) return 50;
    return ((value - low) / (high - low) * 100).clamp(0.0, 100.0);
  }

  /// Z-score 轉 0-100 分數
  ///
  /// 使用 CDF 近似，均值→50，+2σ→~98，-2σ→~2
  static double _zScoreToScore(List<double> values) {
    if (values.isEmpty) return 50;

    final mean = values.fold<double>(0, (s, v) => s + v) / values.length;
    final variance =
        values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
        values.length;
    final std = math.sqrt(variance);

    if (std == 0) return values.last > 0 ? 75 : (values.last < 0 ? 25 : 50);

    final z = (values.last - mean) / std;
    // 簡化 CDF: z ∈ [-3, 3] → [0, 100]
    return _linearMap(z, -2.5, 2.5);
  }

  static SentimentLevel _scoreToLevel(double score) {
    if (score < 20) return SentimentLevel.extremeFear;
    if (score < 40) return SentimentLevel.fear;
    if (score < 60) return SentimentLevel.neutral;
    if (score < 80) return SentimentLevel.greed;
    return SentimentLevel.extremeGreed;
  }
}
