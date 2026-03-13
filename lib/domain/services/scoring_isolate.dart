import 'dart:convert';
import 'dart:isolate';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/liquidity_checker.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/isolate_map_extensions.dart';
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
    this.date,
    this.dayTradingMap,
    this.shareholdingMap,
    this.warningMap,
    this.insiderMap,
    this.epsHistoryMap,
    this.roeHistoryMap,
    this.dividendHistoryMap,
    this.maxHistoricalRevenueMap,
  });

  final List<String> candidates;
  final Map<String, List<Map<String, dynamic>>> pricesMap;
  final Map<String, List<Map<String, dynamic>>> newsMap;
  final Map<String, List<Map<String, dynamic>>> institutionalMap;
  final Map<String, Map<String, dynamic>>? revenueMap;
  final Map<String, Map<String, dynamic>>? valuationMap;
  final Map<String, List<Map<String, dynamic>>>? revenueHistoryMap;
  final Set<String>? recentlyRecommended;

  /// 評估目標日期（供規則判斷資料新鮮度）
  final DateTime? date;

  /// 當沖資料 Map（symbol -> dayTradingRatio）
  final Map<String, double>? dayTradingMap;

  /// 外資持股資料（symbol → 持股資料）
  final Map<String, ShareholdingData>? shareholdingMap;

  /// 警示資料（symbol → 警示上下文）
  final Map<String, WarningDataContext>? warningMap;

  /// 董監持股資料（symbol → 董監上下文）
  final Map<String, InsiderDataContext>? insiderMap;

  /// EPS 歷史資料 Map（symbol -> 最近 8 季 EPS，降序）
  final Map<String, List<Map<String, dynamic>>>? epsHistoryMap;

  /// ROE 歷史資料 Map（symbol -> 最近 8 季 ROE，降序）
  final Map<String, List<Map<String, dynamic>>>? roeHistoryMap;

  /// 股利歷史資料 Map（symbol -> 歷年股利，降序）
  final Map<String, List<Map<String, dynamic>>>? dividendHistoryMap;

  /// 歷史最高月營收 Map（symbol -> maxRevenue）
  final Map<String, double>? maxHistoricalRevenueMap;

  Map<String, dynamic> toMap() => {
    'candidates': candidates,
    'pricesMap': pricesMap,
    'newsMap': newsMap,
    'institutionalMap': institutionalMap,
    'revenueMap': revenueMap,
    'valuationMap': valuationMap,
    'revenueHistoryMap': revenueHistoryMap,
    'recentlyRecommended': recentlyRecommended?.toList(),
    'date': date?.millisecondsSinceEpoch,
    'dayTradingMap': dayTradingMap,
    'shareholdingMap': shareholdingMap?.map((k, v) => MapEntry(k, v.toMap())),
    'warningMap': warningMap?.map((k, v) => MapEntry(k, v.toMap())),
    'insiderMap': insiderMap?.map((k, v) => MapEntry(k, v.toMap())),
    'epsHistoryMap': epsHistoryMap,
    'roeHistoryMap': roeHistoryMap,
    'dividendHistoryMap': dividendHistoryMap,
    'maxHistoricalRevenueMap': maxHistoricalRevenueMap,
  };

  factory ScoringIsolateInput.fromMap(Map<String, dynamic> map) {
    return ScoringIsolateInput(
      candidates: List<String>.from(map['candidates']),
      pricesMap: _castMapOfLists(map['pricesMap'], 'pricesMap'),
      newsMap: _castMapOfLists(map['newsMap'], 'newsMap'),
      institutionalMap: _castMapOfLists(
        map['institutionalMap'],
        'institutionalMap',
      ),
      revenueMap: map['revenueMap'] != null
          ? Map<String, Map<String, dynamic>>.from(map['revenueMap'])
          : null,
      valuationMap: map['valuationMap'] != null
          ? Map<String, Map<String, dynamic>>.from(map['valuationMap'])
          : null,
      revenueHistoryMap: map['revenueHistoryMap'] != null
          ? _castMapOfLists(map['revenueHistoryMap'], 'revenueHistoryMap')
          : null,
      recentlyRecommended: map['recentlyRecommended'] != null
          ? Set<String>.from(map['recentlyRecommended'])
          : null,
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : null,
      dayTradingMap: map['dayTradingMap'] != null
          ? Map<String, double>.from(map['dayTradingMap'])
          : null,
      shareholdingMap: map['shareholdingMap'] != null
          ? _castTypedMap(
              map['shareholdingMap'],
              (m) => ShareholdingData.fromMap(m),
            )
          : null,
      warningMap: map['warningMap'] != null
          ? _castTypedMap(
              map['warningMap'],
              (m) => WarningDataContext.fromMap(m),
            )
          : null,
      insiderMap: map['insiderMap'] != null
          ? _castTypedMap(
              map['insiderMap'],
              (m) => InsiderDataContext.fromMap(m),
            )
          : null,
      epsHistoryMap: map['epsHistoryMap'] != null
          ? _castMapOfLists(map['epsHistoryMap'], 'epsHistoryMap')
          : null,
      roeHistoryMap: map['roeHistoryMap'] != null
          ? _castMapOfLists(map['roeHistoryMap'], 'roeHistoryMap')
          : null,
      dividendHistoryMap: map['dividendHistoryMap'] != null
          ? _castMapOfLists(map['dividendHistoryMap'], 'dividendHistoryMap')
          : null,
      maxHistoricalRevenueMap: map['maxHistoricalRevenueMap'] != null
          ? Map<String, double>.from(map['maxHistoricalRevenueMap'])
          : null,
    );
  }

  /// Isolate 邊界型別轉換：symbol → list of maps
  ///
  /// Isolate 傳輸會遺失泛型資訊，需逐層手動轉型。
  /// [fieldName] 用於錯誤日誌識別。
  static Map<String, List<Map<String, dynamic>>> _castMapOfLists(
    dynamic map,
    String fieldName,
  ) {
    if (map is! Map) return {};
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in map.entries) {
      try {
        result[entry.key as String] = List<Map<String, dynamic>>.from(
          (entry.value as List).map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (_) {
        // 靜默跳過無法轉型的 entry（Isolate 內無法使用 AppLogger）
      }
    }
    return result;
  }

  /// Isolate 邊界型別轉換：symbol → typed DTO
  static Map<String, T> _castTypedMap<T>(
    dynamic map,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    if (map is! Map) return {};
    final result = <String, T>{};
    for (final entry in map.entries) {
      try {
        result[entry.key as String] = fromMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      } catch (_) {
        // 靜默跳過無法轉型的 entry（Isolate 內無法使用 AppLogger）
      }
    }
    return result;
  }
}

/// Isolate 通訊邊界的 reason 型別安全封裝
///
/// 替代 `Map<String, dynamic>`，在 isolate 邊界提供編譯期型別檢查
class IsolateReasonOutput {
  const IsolateReasonOutput({
    required this.type,
    required this.score,
    required this.description,
    required this.evidenceJson,
  });

  final String type;
  final int score;
  final String description;
  final String evidenceJson;

  Map<String, dynamic> toMap() => {
    'type': type,
    'score': score,
    'description': description,
    'evidenceJson': evidenceJson,
  };

  factory IsolateReasonOutput.fromMap(Map<String, dynamic> map) {
    return IsolateReasonOutput(
      type: map['type'] as String,
      score: map['score'] as int,
      description: map['description'] as String,
      evidenceJson: map['evidenceJson'] as String,
    );
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
  final List<IsolateReasonOutput> reasons;

  Map<String, dynamic> toMap() => {
    'symbol': symbol,
    'score': score,
    'turnover': turnover,
    'trendState': trendState,
    'reversalState': reversalState,
    'supportLevel': supportLevel,
    'resistanceLevel': resistanceLevel,
    'reasons': reasons.map((r) => r.toMap()).toList(),
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
      reasons: (map['reasons'] as List)
          .map((e) => IsolateReasonOutput.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
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
  final resultMap = await Isolate.run(
    () => _evaluateStocksIsolated(input.toMap()),
  );
  return ScoringBatchResult.fromMap(resultMap);
}

/// 在 Isolate 中執行的純運算函數
///
/// 此函數不能存取資料庫或 Provider，只能使用傳入的資料
Map<String, dynamic> _evaluateStocksIsolated(Map<String, dynamic> inputMap) {
  final input = ScoringIsolateInput.fromMap(inputMap);

  // 在 Isolate 中建立服務（它們是無狀態的）
  final analysisService = AnalysisService();
  final ruleEngine = RuleEngine();

  final outputs = <ScoringIsolateOutput>[];
  var skippedNoData = 0;
  var skippedInsufficientData = 0;
  var skippedLowLiquidity = 0;
  var skippedLowScore = 0;

  final recentSet = input.recentlyRecommended ?? <String>{};

  for (final symbol in input.candidates) {
    // 1. 取得並驗證價格資料
    final pricesMaps = input.pricesMap[symbol];
    if (pricesMaps == null || pricesMaps.isEmpty) {
      skippedNoData++;
      continue;
    }

    final prices = pricesMaps.map(IsolateMappers.dailyPrice).toList();
    if (prices.length < RuleParams.swingWindow) {
      skippedInsufficientData++;
      continue;
    }

    // 2. 流動性過濾
    final latest = prices.last;
    final liquidityResult = LiquidityChecker.checkCandidateLiquidity(latest);
    if (liquidityResult != null) {
      if (liquidityResult == 'MISSING_DATA') {
        skippedNoData++;
      } else {
        skippedLowLiquidity++;
      }
      continue;
    }
    final turnover = latest.close! * latest.volume!;

    // 3. 技術分析
    final analysisResult = analysisService.analyzeStock(prices);
    if (analysisResult == null) continue;

    // 4. 建立市場資料上下文
    final marketData = _buildMarketDataContext(input, symbol);

    // 5. 建立分析上下文
    final context = analysisService.buildContext(
      analysisResult,
      priceHistory: prices,
      marketData: marketData,
      evaluationTime: input.date ?? DateTime.now(),
    );

    // 6. 轉換批次資料並執行規則引擎
    final batchData = _convertBatchData(input, symbol);
    final reasons = ruleEngine.evaluateStock(
      priceHistory: prices,
      context: context,
      institutionalHistory: batchData.institutionalHistory,
      recentNews: batchData.recentNews,
      symbol: symbol,
      latestRevenue: batchData.latestRevenue,
      latestValuation: batchData.latestValuation,
      revenueHistory: batchData.revenueHistory,
      epsHistory: batchData.epsHistory,
      roeHistory: batchData.roeHistory,
      dividendHistory: batchData.dividendHistory,
      maxHistoricalRevenue: batchData.maxHistoricalRevenue,
    );

    if (reasons.isEmpty) continue;

    // 7. 計算分數並過濾
    final wasRecent = recentSet.contains(symbol);
    final score = ruleEngine.calculateScore(
      reasons,
      wasRecentlyRecommended: wasRecent,
    );

    if (score < RuleParams.minScoreThreshold) {
      skippedLowScore++;
      continue;
    }

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
        reasons: topReasons.map(_reasonToOutput).toList(),
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

/// 從 input 建立市場資料上下文（警示、董監、外資、當沖）
MarketDataContext? _buildMarketDataContext(
  ScoringIsolateInput input,
  String symbol,
) {
  final dayTradingRatio = input.dayTradingMap?[symbol];
  final shareholding = input.shareholdingMap?[symbol];
  final warning = input.warningMap?[symbol];
  final insider = input.insiderMap?[symbol];

  if (dayTradingRatio == null &&
      shareholding == null &&
      warning == null &&
      insider == null) {
    return null;
  }

  return MarketDataContext(
    dayTradingRatio: dayTradingRatio,
    foreignSharesRatio: shareholding?.foreignSharesRatio,
    foreignSharesRatioChange: shareholding?.foreignSharesRatioChange,
    concentrationRatio: shareholding?.concentrationRatio,
    warningData: warning,
    insiderData: insider,
  );
}

/// 轉換各項批次資料（法人、新聞、營收、估值、EPS、ROE、股利）
({
  List<DailyInstitutionalEntry>? institutionalHistory,
  List<NewsItemEntry>? recentNews,
  MonthlyRevenueEntry? latestRevenue,
  StockValuationEntry? latestValuation,
  List<MonthlyRevenueEntry>? revenueHistory,
  List<FinancialDataEntry>? epsHistory,
  List<FinancialDataEntry>? roeHistory,
  List<DividendHistoryEntry>? dividendHistory,
  double? maxHistoricalRevenue,
})
_convertBatchData(ScoringIsolateInput input, String symbol) {
  final instMaps = input.institutionalMap[symbol];
  final newsMaps = input.newsMap[symbol];
  final revenueMap = input.revenueMap?[symbol];
  final valuationMap = input.valuationMap?[symbol];
  final revenueHistoryMaps = input.revenueHistoryMap?[symbol];
  final epsHistoryMaps = input.epsHistoryMap?[symbol];
  final roeHistoryMaps = input.roeHistoryMap?[symbol];
  final dividendHistoryMaps = input.dividendHistoryMap?[symbol];

  return (
    institutionalHistory: instMaps != null && instMaps.isNotEmpty
        ? instMaps.map(IsolateMappers.dailyInstitutional).toList()
        : null,
    recentNews: newsMaps != null && newsMaps.isNotEmpty
        ? newsMaps.map(IsolateMappers.newsItem).toList()
        : null,
    latestRevenue: revenueMap != null
        ? IsolateMappers.monthlyRevenue(revenueMap)
        : null,
    latestValuation: valuationMap != null
        ? IsolateMappers.stockValuation(valuationMap)
        : null,
    revenueHistory: revenueHistoryMaps != null && revenueHistoryMaps.isNotEmpty
        ? revenueHistoryMaps.map(IsolateMappers.monthlyRevenue).toList()
        : null,
    epsHistory: epsHistoryMaps != null && epsHistoryMaps.isNotEmpty
        ? epsHistoryMaps.map(IsolateMappers.financialData).toList()
        : null,
    roeHistory: roeHistoryMaps != null && roeHistoryMaps.isNotEmpty
        ? roeHistoryMaps.map(IsolateMappers.financialData).toList()
        : null,
    dividendHistory:
        dividendHistoryMaps != null && dividendHistoryMaps.isNotEmpty
        ? dividendHistoryMaps.map(IsolateMappers.dividendHistory).toList()
        : null,
    maxHistoricalRevenue: input.maxHistoricalRevenueMap?[symbol],
  );
}

IsolateReasonOutput _reasonToOutput(TriggeredReason reason) {
  return IsolateReasonOutput(
    type: reason.type.code,
    score: reason.score,
    description: reason.description,
    evidenceJson: reason.evidenceJson != null
        ? jsonEncode(reason.evidenceJson)
        : '{}',
  );
}
