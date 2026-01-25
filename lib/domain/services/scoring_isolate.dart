import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// Isolate 評分輸入資料
///
/// 包含評分所需的所有批次載入資料
class ScoringIsolateInput {
  const ScoringIsolateInput({
    required this.candidates,
    required this.pricesMap,
    required this.newsMap,
    required this.institutionalMap,
    this.revenueMap,
    this.valuationMap,
    this.revenueHistoryMap,
    this.recentlyRecommended,
  });

  final List<String> candidates;
  final Map<String, List<Map<String, dynamic>>> pricesMap;
  final Map<String, List<Map<String, dynamic>>> newsMap;
  final Map<String, List<Map<String, dynamic>>> institutionalMap;
  final Map<String, Map<String, dynamic>>? revenueMap;
  final Map<String, Map<String, dynamic>>? valuationMap;
  final Map<String, List<Map<String, dynamic>>>? revenueHistoryMap;
  final Set<String>? recentlyRecommended;

  Map<String, dynamic> toMap() => {
    'candidates': candidates,
    'pricesMap': pricesMap,
    'newsMap': newsMap,
    'institutionalMap': institutionalMap,
    'revenueMap': revenueMap,
    'valuationMap': valuationMap,
    'revenueHistoryMap': revenueHistoryMap,
    'recentlyRecommended': recentlyRecommended?.toList(),
  };

  factory ScoringIsolateInput.fromMap(Map<String, dynamic> map) {
    return ScoringIsolateInput(
      candidates: List<String>.from(map['candidates']),
      pricesMap: _castPricesMap(map['pricesMap']),
      newsMap: _castNewsMap(map['newsMap']),
      institutionalMap: _castInstitutionalMap(map['institutionalMap']),
      revenueMap: map['revenueMap'] != null
          ? Map<String, Map<String, dynamic>>.from(map['revenueMap'])
          : null,
      valuationMap: map['valuationMap'] != null
          ? Map<String, Map<String, dynamic>>.from(map['valuationMap'])
          : null,
      revenueHistoryMap: map['revenueHistoryMap'] != null
          ? _castRevenueHistoryMap(map['revenueHistoryMap'])
          : null,
      recentlyRecommended: map['recentlyRecommended'] != null
          ? Set<String>.from(map['recentlyRecommended'])
          : null,
    );
  }

  static Map<String, List<Map<String, dynamic>>> _castPricesMap(dynamic map) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in (map as Map).entries) {
      result[entry.key as String] = List<Map<String, dynamic>>.from(
        (entry.value as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> _castNewsMap(dynamic map) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in (map as Map).entries) {
      result[entry.key as String] = List<Map<String, dynamic>>.from(
        (entry.value as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> _castInstitutionalMap(
    dynamic map,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in (map as Map).entries) {
      result[entry.key as String] = List<Map<String, dynamic>>.from(
        (entry.value as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> _castRevenueHistoryMap(
    dynamic map,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in (map as Map).entries) {
      result[entry.key as String] = List<Map<String, dynamic>>.from(
        (entry.value as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return result;
  }
}

/// Isolate 評分輸出結果
class ScoringIsolateOutput {
  const ScoringIsolateOutput({
    required this.symbol,
    required this.score,
    required this.turnover,
    required this.trendState,
    required this.reversalState,
    this.supportLevel,
    this.resistanceLevel,
    required this.reasons,
  });

  final String symbol;
  final int score;
  final double turnover;
  final String trendState;
  final String reversalState;
  final double? supportLevel;
  final double? resistanceLevel;
  final List<Map<String, dynamic>> reasons;

  Map<String, dynamic> toMap() => {
    'symbol': symbol,
    'score': score,
    'turnover': turnover,
    'trendState': trendState,
    'reversalState': reversalState,
    'supportLevel': supportLevel,
    'resistanceLevel': resistanceLevel,
    'reasons': reasons,
  };

  factory ScoringIsolateOutput.fromMap(Map<String, dynamic> map) {
    return ScoringIsolateOutput(
      symbol: map['symbol'] as String,
      score: map['score'] as int,
      turnover: map['turnover'] as double,
      trendState: map['trendState'] as String,
      reversalState: map['reversalState'] as String,
      supportLevel: map['supportLevel'] as double?,
      resistanceLevel: map['resistanceLevel'] as double?,
      reasons: List<Map<String, dynamic>>.from(
        (map['reasons'] as List).map((e) => Map<String, dynamic>.from(e)),
      ),
    );
  }
}

/// 批次評分結果
class ScoringBatchResult {
  const ScoringBatchResult({
    required this.outputs,
    required this.skippedNoData,
    required this.skippedInsufficientData,
    required this.skippedLowLiquidity,
    required this.skippedLowScore,
  });

  final List<ScoringIsolateOutput> outputs;
  final int skippedNoData;
  final int skippedInsufficientData;
  final int skippedLowLiquidity;
  final int skippedLowScore;

  Map<String, dynamic> toMap() => {
    'outputs': outputs.map((o) => o.toMap()).toList(),
    'skippedNoData': skippedNoData,
    'skippedInsufficientData': skippedInsufficientData,
    'skippedLowLiquidity': skippedLowLiquidity,
    'skippedLowScore': skippedLowScore,
  };

  factory ScoringBatchResult.fromMap(Map<String, dynamic> map) {
    return ScoringBatchResult(
      outputs: (map['outputs'] as List)
          .map(
            (e) => ScoringIsolateOutput.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList(),
      skippedNoData: map['skippedNoData'] as int,
      skippedInsufficientData: map['skippedInsufficientData'] as int,
      skippedLowLiquidity: map['skippedLowLiquidity'] as int,
      skippedLowScore: map['skippedLowScore'] as int,
    );
  }
}

/// 在背景 Isolate 中執行批量評分
///
/// 所有運算（分析、規則評估、分數計算）都在背景執行，
/// 不會阻塞 UI 執行緒
Future<ScoringBatchResult> evaluateStocksInIsolate(
  ScoringIsolateInput input,
) async {
  final resultMap = await compute(_evaluateStocksIsolated, input.toMap());
  return ScoringBatchResult.fromMap(resultMap);
}

/// 在 Isolate 中執行的純運算函數
///
/// 此函數不能存取資料庫或 Provider，只能使用傳入的資料
Map<String, dynamic> _evaluateStocksIsolated(Map<String, dynamic> inputMap) {
  final input = ScoringIsolateInput.fromMap(inputMap);

  // 在 Isolate 中建立服務（它們是無狀態的）
  const analysisService = AnalysisService();
  final ruleEngine = RuleEngine();

  final outputs = <ScoringIsolateOutput>[];
  var skippedNoData = 0;
  var skippedInsufficientData = 0;
  var skippedLowLiquidity = 0;
  var skippedLowScore = 0;

  final recentSet = input.recentlyRecommended ?? <String>{};

  for (final symbol in input.candidates) {
    // 取得價格資料
    final pricesMaps = input.pricesMap[symbol];
    if (pricesMaps == null || pricesMaps.isEmpty) {
      skippedNoData++;
      continue;
    }

    // 轉換為 DailyPriceEntry
    final prices = pricesMaps.map(_mapToDailyPriceEntry).toList();

    if (prices.length < RuleParams.swingWindow) {
      skippedInsufficientData++;
      continue;
    }

    // 流動性檢查
    final latest = prices.last;
    if (latest.close == null || latest.volume == null) {
      skippedNoData++;
      continue;
    }

    if (latest.volume! < RuleParams.minCandidateVolumeShares) {
      skippedLowLiquidity++;
      continue;
    }

    final turnover = latest.close! * latest.volume!;
    if (turnover < RuleParams.minCandidateTurnover) {
      skippedLowLiquidity++;
      continue;
    }

    // 執行分析
    final analysisResult = analysisService.analyzeStock(prices);
    if (analysisResult == null) continue;

    // 建立上下文（無 marketData，在 Isolate 中無法取得）
    final context = analysisService.buildContext(
      analysisResult,
      priceHistory: prices,
    );

    // 轉換法人資料
    List<DailyInstitutionalEntry>? institutionalHistory;
    final instMaps = input.institutionalMap[symbol];
    if (instMaps != null && instMaps.isNotEmpty) {
      institutionalHistory = instMaps
          .map(_mapToDailyInstitutionalEntry)
          .toList();
    }

    // 轉換新聞資料
    List<NewsItemEntry>? recentNews;
    final newsMaps = input.newsMap[symbol];
    if (newsMaps != null && newsMaps.isNotEmpty) {
      recentNews = newsMaps.map(_mapToNewsItemEntry).toList();
    }

    // 轉換營收資料
    MonthlyRevenueEntry? latestRevenue;
    final revenueMap = input.revenueMap?[symbol];
    if (revenueMap != null) {
      latestRevenue = _mapToMonthlyRevenueEntry(revenueMap);
    }

    // 轉換估值資料
    StockValuationEntry? latestValuation;
    final valuationMap = input.valuationMap?[symbol];
    if (valuationMap != null) {
      latestValuation = _mapToStockValuationEntry(valuationMap);
    }

    // 轉換營收歷史
    List<MonthlyRevenueEntry>? revenueHistory;
    final revenueHistoryMaps = input.revenueHistoryMap?[symbol];
    if (revenueHistoryMaps != null && revenueHistoryMaps.isNotEmpty) {
      revenueHistory = revenueHistoryMaps
          .map(_mapToMonthlyRevenueEntry)
          .toList();
    }

    // 執行規則引擎
    final reasons = ruleEngine.evaluateStock(
      priceHistory: prices,
      context: context,
      institutionalHistory: institutionalHistory,
      recentNews: recentNews,
      symbol: symbol,
      latestRevenue: latestRevenue,
      latestValuation: latestValuation,
      revenueHistory: revenueHistory,
    );

    if (reasons.isEmpty) continue;

    // 計算分數
    final wasRecent = recentSet.contains(symbol);
    final score = ruleEngine.calculateScore(
      reasons,
      wasRecentlyRecommended: wasRecent,
    );

    if (score < RuleParams.minScoreThreshold) {
      skippedLowScore++;
      continue;
    }

    // 取得前幾個原因
    final topReasons = ruleEngine.getTopReasons(reasons);

    outputs.add(
      ScoringIsolateOutput(
        symbol: symbol,
        score: score,
        turnover: turnover,
        trendState: analysisResult.trendState.code,
        reversalState: analysisResult.reversalState.code,
        supportLevel: analysisResult.supportLevel,
        resistanceLevel: analysisResult.resistanceLevel,
        reasons: topReasons.map(_reasonToMap).toList(),
      ),
    );
  }

  return ScoringBatchResult(
    outputs: outputs,
    skippedNoData: skippedNoData,
    skippedInsufficientData: skippedInsufficientData,
    skippedLowLiquidity: skippedLowLiquidity,
    skippedLowScore: skippedLowScore,
  ).toMap();
}

// =============================================
// 資料轉換輔助函數
// =============================================

DailyPriceEntry _mapToDailyPriceEntry(Map<String, dynamic> map) {
  return DailyPriceEntry(
    symbol: map['symbol'] as String,
    date: DateTime.parse(map['date'] as String),
    open: map['open'] as double?,
    high: map['high'] as double?,
    low: map['low'] as double?,
    close: map['close'] as double?,
    volume: map['volume'] as double?,
  );
}

Map<String, dynamic> dailyPriceEntryToMap(DailyPriceEntry entry) {
  return {
    'symbol': entry.symbol,
    'date': entry.date.toIso8601String(),
    'open': entry.open,
    'high': entry.high,
    'low': entry.low,
    'close': entry.close,
    'volume': entry.volume,
  };
}

DailyInstitutionalEntry _mapToDailyInstitutionalEntry(
  Map<String, dynamic> map,
) {
  return DailyInstitutionalEntry(
    symbol: map['symbol'] as String,
    date: DateTime.parse(map['date'] as String),
    foreignNet: map['foreignNet'] as double?,
    investmentTrustNet: map['investmentTrustNet'] as double?,
    dealerNet: map['dealerNet'] as double?,
  );
}

Map<String, dynamic> dailyInstitutionalEntryToMap(
  DailyInstitutionalEntry entry,
) {
  return {
    'symbol': entry.symbol,
    'date': entry.date.toIso8601String(),
    'foreignNet': entry.foreignNet,
    'investmentTrustNet': entry.investmentTrustNet,
    'dealerNet': entry.dealerNet,
  };
}

NewsItemEntry _mapToNewsItemEntry(Map<String, dynamic> map) {
  return NewsItemEntry(
    id: map['id'] as String,
    source: map['source'] as String,
    title: map['title'] as String,
    url: map['url'] as String,
    category: map['category'] as String,
    publishedAt: DateTime.parse(map['publishedAt'] as String),
    fetchedAt: DateTime.parse(map['fetchedAt'] as String),
  );
}

Map<String, dynamic> newsItemEntryToMap(NewsItemEntry entry) {
  return {
    'id': entry.id,
    'source': entry.source,
    'title': entry.title,
    'url': entry.url,
    'category': entry.category,
    'publishedAt': entry.publishedAt.toIso8601String(),
    'fetchedAt': entry.fetchedAt.toIso8601String(),
  };
}

MonthlyRevenueEntry _mapToMonthlyRevenueEntry(Map<String, dynamic> map) {
  return MonthlyRevenueEntry(
    symbol: map['symbol'] as String,
    date: DateTime.parse(map['date'] as String),
    revenueYear: map['revenueYear'] as int,
    revenueMonth: map['revenueMonth'] as int,
    revenue: (map['revenue'] as num).toDouble(),
    momGrowth: map['momGrowth'] as double?,
    yoyGrowth: map['yoyGrowth'] as double?,
  );
}

Map<String, dynamic> monthlyRevenueEntryToMap(MonthlyRevenueEntry entry) {
  return {
    'symbol': entry.symbol,
    'date': entry.date.toIso8601String(),
    'revenueYear': entry.revenueYear,
    'revenueMonth': entry.revenueMonth,
    'revenue': entry.revenue,
    'momGrowth': entry.momGrowth,
    'yoyGrowth': entry.yoyGrowth,
  };
}

StockValuationEntry _mapToStockValuationEntry(Map<String, dynamic> map) {
  return StockValuationEntry(
    symbol: map['symbol'] as String,
    date: DateTime.parse(map['date'] as String),
    per: map['per'] as double?,
    pbr: map['pbr'] as double?,
    dividendYield: map['dividendYield'] as double?,
  );
}

Map<String, dynamic> stockValuationEntryToMap(StockValuationEntry entry) {
  return {
    'symbol': entry.symbol,
    'date': entry.date.toIso8601String(),
    'per': entry.per,
    'pbr': entry.pbr,
    'dividendYield': entry.dividendYield,
  };
}

Map<String, dynamic> _reasonToMap(TriggeredReason reason) {
  return {
    'type': reason.type.code,
    'score': reason.score,
    'description': reason.description,
    'evidenceJson': reason.evidenceJson != null
        ? jsonEncode(reason.evidenceJson)
        : '{}',
  };
}
