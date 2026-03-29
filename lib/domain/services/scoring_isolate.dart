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
  final Map<String, List<DailyPriceEntry>> pricesMap;
  final Map<String, List<NewsItemEntry>> newsMap;
  final Map<String, List<DailyInstitutionalEntry>> institutionalMap;
  final Map<String, MonthlyRevenueEntry>? revenueMap;
  final Map<String, StockValuationEntry>? valuationMap;
  final Map<String, List<MonthlyRevenueEntry>>? revenueHistoryMap;
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
  final Map<String, List<FinancialDataEntry>>? epsHistoryMap;

  /// ROE 歷史資料 Map（symbol -> 最近 8 季 ROE，降序）
  final Map<String, List<FinancialDataEntry>>? roeHistoryMap;

  /// 股利歷史資料 Map（symbol -> 歷年股利，降序）
  final Map<String, List<DividendHistoryEntry>>? dividendHistoryMap;

  /// 歷史最高月營收 Map（symbol -> maxRevenue）
  final Map<String, double>? maxHistoricalRevenueMap;

  Map<String, dynamic> toMap() => {
    'candidates': candidates,
    'pricesMap': pricesMap.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'newsMap': newsMap.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'institutionalMap': institutionalMap.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'revenueMap': revenueMap?.map((k, v) => MapEntry(k, v.toIsolateMap())),
    'valuationMap': valuationMap?.map((k, v) => MapEntry(k, v.toIsolateMap())),
    'revenueHistoryMap': revenueHistoryMap?.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'recentlyRecommended': recentlyRecommended?.toList(),
    'date': date?.millisecondsSinceEpoch,
    'dayTradingMap': dayTradingMap,
    'shareholdingMap': shareholdingMap?.map((k, v) => MapEntry(k, v.toMap())),
    'warningMap': warningMap?.map((k, v) => MapEntry(k, v.toMap())),
    'insiderMap': insiderMap?.map((k, v) => MapEntry(k, v.toMap())),
    'epsHistoryMap': epsHistoryMap?.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'roeHistoryMap': roeHistoryMap?.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'dividendHistoryMap': dividendHistoryMap?.map(
      (k, v) => MapEntry(k, v.map((e) => e.toIsolateMap()).toList()),
    ),
    'maxHistoricalRevenueMap': maxHistoricalRevenueMap,
  };

  factory ScoringIsolateInput.fromMap(Map<String, dynamic> map) {
    _resetDeserializationErrors();
    return ScoringIsolateInput(
      candidates: List<String>.from(map['candidates']),
      pricesMap: _deserializeListMap(
        map,
        'pricesMap',
        IsolateMappers.dailyPrice,
      ),
      newsMap: _deserializeListMap(map, 'newsMap', IsolateMappers.newsItem),
      institutionalMap: _deserializeListMap(
        map,
        'institutionalMap',
        IsolateMappers.dailyInstitutional,
      ),
      revenueMap: _deserializeSingleMap(
        map,
        'revenueMap',
        IsolateMappers.monthlyRevenue,
      ),
      valuationMap: _deserializeSingleMap(
        map,
        'valuationMap',
        IsolateMappers.stockValuation,
      ),
      revenueHistoryMap: _deserializeListMap<MonthlyRevenueEntry>(
        map,
        'revenueHistoryMap',
        IsolateMappers.monthlyRevenue,
      ).ifEmpty(null),
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
      epsHistoryMap: _deserializeListMap<FinancialDataEntry>(
        map,
        'epsHistoryMap',
        IsolateMappers.financialData,
      ).ifEmpty(null),
      roeHistoryMap: _deserializeListMap<FinancialDataEntry>(
        map,
        'roeHistoryMap',
        IsolateMappers.financialData,
      ).ifEmpty(null),
      dividendHistoryMap: _deserializeListMap<DividendHistoryEntry>(
        map,
        'dividendHistoryMap',
        IsolateMappers.dividendHistory,
      ).ifEmpty(null),
      maxHistoricalRevenueMap: map['maxHistoricalRevenueMap'] != null
          ? Map<String, double>.from(map['maxHistoricalRevenueMap'])
          : null,
    );
  }

  /// Isolate 邊界反序列化累計失敗數（跨所有欄位）
  ///
  /// 由 [_castMapOfLists] 和 [_castTypedMap] 累加，
  /// 最終回報在 [ScoringBatchResult.skippedDeserialization]。
  static int _deserializationErrors = 0;

  /// 重置反序列化錯誤計數器（每次 fromMap 前呼叫）
  static void _resetDeserializationErrors() => _deserializationErrors = 0;

  /// Isolate 邊界反序列化：symbol → typed List
  ///
  /// Isolate 傳輸會遺失泛型資訊，需逐層手動轉型後透過 [mapper] 建立 typed DTO。
  /// 轉型失敗的 entry 會累加至 [_deserializationErrors]。
  /// 若 [map] 中 key 不存在或為 null，回傳空 Map。
  static Map<String, List<T>> _deserializeListMap<T>(
    Map<String, dynamic> map,
    String key,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final raw = map[key];
    if (raw == null) return {};
    final result = <String, List<T>>{};
    for (final entry in (raw as Map).entries) {
      final list = <T>[];
      for (final item in entry.value as List) {
        try {
          list.add(mapper(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          _deserializationErrors++;
        }
      }
      result[entry.key.toString()] = list;
    }
    return result;
  }

  /// Isolate 邊界反序列化：symbol → T
  ///
  /// 轉型失敗的 entry 會累加至 [_deserializationErrors]。
  /// 若 [map] 中 key 不存在或為 null，回傳 null。
  static Map<String, T>? _deserializeSingleMap<T>(
    Map<String, dynamic> map,
    String key,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final raw = map[key];
    if (raw == null) return null;
    final result = <String, T>{};
    for (final entry in (raw as Map).entries) {
      try {
        result[entry.key.toString()] = mapper(
          Map<String, dynamic>.from(entry.value as Map),
        );
      } catch (_) {
        _deserializationErrors++;
      }
    }
    return result;
  }

  /// Isolate 邊界型別轉換：symbol → typed DTO
  ///
  /// 轉型失敗的 entry 會累加至 [_deserializationErrors]。
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
        _deserializationErrors++;
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
    this.skippedDeserialization = 0,
  });

  final List<ScoringIsolateOutput> outputs;
  final int skippedNoData;
  final int skippedInsufficientData;
  final int skippedLowLiquidity;
  final int skippedLowScore;

  /// Isolate 邊界反序列化失敗的 entry 數量
  final int skippedDeserialization;

  Map<String, dynamic> toMap() => {
    'outputs': outputs.map((o) => o.toMap()).toList(),
    'skippedNoData': skippedNoData,
    'skippedInsufficientData': skippedInsufficientData,
    'skippedLowLiquidity': skippedLowLiquidity,
    'skippedLowScore': skippedLowScore,
    'skippedDeserialization': skippedDeserialization,
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
      skippedDeserialization: (map['skippedDeserialization'] as int?) ?? 0,
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
    final prices = input.pricesMap[symbol];
    if (prices == null || prices.isEmpty) {
      skippedNoData++;
      continue;
    }

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
    skippedDeserialization: ScoringIsolateInput._deserializationErrors,
  ).toMap();
}

/// 從 input 建立市場資料上下文（警示、董監、外資、當沖）
MarketDataContext? _buildMarketDataContext(
  ScoringIsolateInput input,
  String symbol,
) {
  return MarketDataContext.fromComponents(
    dayTradingRatio: input.dayTradingMap?[symbol],
    shareholding: input.shareholdingMap?[symbol],
    warning: input.warningMap?[symbol],
    insider: input.insiderMap?[symbol],
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
  final institutional = input.institutionalMap[symbol];
  final news = input.newsMap[symbol];
  final revenueHistory = input.revenueHistoryMap?[symbol];
  final epsHistory = input.epsHistoryMap?[symbol];
  final roeHistory = input.roeHistoryMap?[symbol];
  final dividendHistory = input.dividendHistoryMap?[symbol];

  return (
    institutionalHistory: institutional != null && institutional.isNotEmpty
        ? institutional
        : null,
    recentNews: news != null && news.isNotEmpty ? news : null,
    latestRevenue: input.revenueMap?[symbol],
    latestValuation: input.valuationMap?[symbol],
    revenueHistory: revenueHistory != null && revenueHistory.isNotEmpty
        ? revenueHistory
        : null,
    epsHistory: epsHistory != null && epsHistory.isNotEmpty ? epsHistory : null,
    roeHistory: roeHistory != null && roeHistory.isNotEmpty ? roeHistory : null,
    dividendHistory: dividendHistory != null && dividendHistory.isNotEmpty
        ? dividendHistory
        : null,
    maxHistoricalRevenue: input.maxHistoricalRevenueMap?[symbol],
  );
}

/// 空 Map → null 轉換，用於 nullable 欄位的反序列化
extension _MapIfEmpty<K, V> on Map<K, V> {
  Map<K, V>? ifEmpty(Map<K, V>? fallback) => isEmpty ? fallback : this;
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
