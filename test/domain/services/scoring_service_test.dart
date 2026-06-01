import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/price_data_generators.dart';

/// ScoringService 單元測試
///
/// 測試評分服務的流動性過濾邏輯與評分流程。
/// 使用 Mocktail 模擬依賴服務。

/// Mock 分析服務
class MockAnalysisService extends Mock implements AnalysisService {}

/// Mock 規則引擎
class MockRuleEngine extends Mock implements RuleEngine {}

/// Mock 分析資料庫
class MockAnalysisRepository extends Mock implements AnalysisRepository {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}

void main() {
  late ScoringService scoringService;
  late MockAnalysisService mockAnalysisService;
  late MockRuleEngine mockRuleEngine;
  late MockAnalysisRepository mockAnalysisRepository;

  setUp(() {
    mockAnalysisService = MockAnalysisService();
    mockRuleEngine = MockRuleEngine();
    mockAnalysisRepository = MockAnalysisRepository();

    scoringService = ScoringService(
      analysisService: mockAnalysisService,
      ruleEngine: mockRuleEngine,
      analysisRepository: mockAnalysisRepository,
    );

    // Default mocks
    registerFallbackValue(const AnalysisContext(trendState: TrendState.range));
    registerFallbackValue(const StockData(symbol: 'TEST', prices: []));
    registerFallbackValue(
      const AnalysisResult(
        trendState: TrendState.range,
        reversalState: ReversalState.none,
        supportLevel: 0,
        resistanceLevel: 0,
      ),
    );
    registerFallbackValue(<TriggeredReason>[]);
    // Stage 5b dual-horizon：calculateScore 新增 horizon + calibratedScores
    registerFallbackValue(Horizon.short);
    registerFallbackValue(CalibratedScoreContext.empty);
    registerFallbackValue(<DailyPriceEntry>[]);
    registerFallbackValue(<NewsItemEntry>[]);
    registerFallbackValue(<DailyInstitutionalEntry>[]);
    registerFallbackValue(<MonthlyRevenueEntry>[]);

    // Default mocks to prevent Null type errors
    when(() => mockRuleEngine.getTopReasons(any())).thenAnswer(
      (invocation) =>
          invocation.positionalArguments[0] as List<TriggeredReason>,
    );
    // H-1 fix: scoring_service 改成顯式呼 applyMutexGroups 在 calculateScore
    // 之前。Mock 預設行為：原樣回傳（不過濾 mutex） — 既有測試斷言的 score
    // 數值對應「不過濾」語意，保持一致。需要驗證 mutex 行為的個別測試自行
    // override。
    when(() => mockRuleEngine.applyMutexGroups(any(), any())).thenAnswer(
      (invocation) =>
          invocation.positionalArguments[0] as List<TriggeredReason>,
    );
    // Types that might be nullable in arguments but needed for any()
    registerFallbackValue(
      MonthlyRevenueEntry(
        symbol: 'TEST',
        date: DateTime(2025, 6, 15),
        revenueYear: 2023,
        revenueMonth: 1,
        revenue: 0,
        momGrowth: 0,
        yoyGrowth: 0,
      ),
    );
    registerFallbackValue(
      StockValuationEntry(
        symbol: 'TEST',
        date: DateTime(2025, 6, 15),
        per: 0,
        pbr: 0,
        dividendYield: 0,
      ),
    );
  });

  group('ScoringService Liquidity Filters', () {
    test('skip stocks with low volume', () async {
      // Arrange
      // Volume = 100K shares (Fail < 200K min)
      final prices = [
        ...generatePricesWithVolumeSpike(
          days: 30,
          normalVolume: 1000,
          spikeVolume: 5000,
        ),
        DailyPriceEntry(
          symbol: 'LOW_VOL',
          date: DateTime(2025, 6, 15),
          open: 100,
          high: 105,
          low: 95,
          close: 100,
          volume: 100000, // 100K shares < 200K min
        ),
      ];

      final pricesMap = {'LOW_VOL': prices};
      // Sufficient history > 20 days
      expect(prices.length, greaterThan(RuleParams.swingWindow));

      // Act
      final result = await scoringService.scoreStocks(
        candidates: ['LOW_VOL'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: pricesMap, newsMap: {}),
      );

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('skip stocks with low turnover', () async {
      // Arrange
      // Volume = 500K shares (OK > 200K)
      // Price = 5
      // Turnover = 2.5M (Fail < 20M)
      final prices = [
        ...generatePricesWithVolumeSpike(
          days: 30,
          normalVolume: 1000,
          spikeVolume: 5000,
        ),
        DailyPriceEntry(
          symbol: 'LOW_TURN',
          date: DateTime(2025, 6, 15),
          open: 5,
          high: 6,
          low: 4,
          close: 5,
          volume: 500000, // 500K shares, turnover = 5*500K = 2.5M < 20M
        ),
      ];

      final pricesMap = {'LOW_TURN': prices};

      // Act
      final result = await scoringService.scoreStocks(
        candidates: ['LOW_TURN'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: pricesMap, newsMap: {}),
      );

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('process stocks with high volume and turnover', () async {
      // Arrange
      // Volume = 3M shares (OK > 200K)
      // Price = 150
      // Turnover = 450M (OK > 20M)
      final prices = [
        ...generatePricesWithVolumeSpike(
          days: 30,
          normalVolume: 1000,
          spikeVolume: 5000,
        ),
        DailyPriceEntry(
          symbol: 'GOOD',
          date: DateTime(2025, 6, 15),
          open: 148,
          high: 152,
          low: 149,
          close: 150,
          volume: 3000000,
        ),
      ];

      final pricesMap = {'GOOD': prices};

      // Mock dependencies
      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 140,
          resistanceLevel: 160,
        ),
      );

      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 80,
          description: 'Test Breakout',
        ),
      ]);

      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).thenReturn(80);

      when(() => mockRuleEngine.getTopReasons(any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 80,
          description: 'Test Breakout',
        ),
      ]);

      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          reversalState: any(named: 'reversalState'),
          supportLevel: any(named: 'supportLevel'),
          resistanceLevel: any(named: 'resistanceLevel'),
          scoreShort: any(named: 'scoreShort'),
          scoreLong: any(named: 'scoreLong'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await scoringService.scoreStocks(
        candidates: ['GOOD'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: pricesMap, newsMap: {}),
      );

      // Assert
      expect(result, isNotEmpty);
      expect(result.first.symbol, 'GOOD');
      expect(result.first.scoreShort, 80);
    });

    test('sort candidates by score descending', () async {
      // Arrange
      final pricesMap = {
        'HIGH_SCORE': [
          ...generatePricesWithVolumeSpike(
            days: 30,
            normalVolume:
                2000000, // Increase to pass turnover filter (2M * 100 = 200M > 20M)
            spikeVolume: 5000000,
          ),
        ],
        'LOW_SCORE': [
          ...generatePricesWithVolumeSpike(
            days: 30,
            normalVolume: 2000000,
            spikeVolume: 5000000,
          ),
        ],
      };

      const highReason = TriggeredReason(
        type: ReasonType.volumeSpike,
        score: 80, // High score reason
        description: 'High',
      );
      const lowReason = TriggeredReason(
        type: ReasonType.volumeSpike,
        score: 40, // Low score reason
        description: 'Low',
      );

      // Unified mock for evaluateStock using thenAnswer to handle dispatch
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenAnswer((
        invocation,
      ) {
        final data = invocation.positionalArguments[1] as StockData;
        final symbol = data.symbol;
        if (symbol == 'HIGH_SCORE') return [highReason];
        if (symbol == 'LOW_SCORE') return [lowReason];
        return [];
      });

      // Mock calculateScore to return score based on input reasons
      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).thenAnswer((invocation) {
        final reasons =
            invocation.positionalArguments[0] as List<TriggeredReason>;
        if (reasons.contains(highReason)) return 80;
        if (reasons.contains(lowReason)) return 40;
        return 0;
      });

      // Mock analysis service dependencies for both
      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 100,
          resistanceLevel: 120,
        ),
      );
      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          scoreShort: any(named: 'scoreShort'),
          scoreLong: any(named: 'scoreLong'),
          reversalState: any(named: 'reversalState'),
          supportLevel: any(named: 'supportLevel'),
          resistanceLevel: any(named: 'resistanceLevel'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});

      // Act
      // Pass in reverse order to ensure sorting works
      final result = await scoringService.scoreStocks(
        candidates: ['LOW_SCORE', 'HIGH_SCORE'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: pricesMap, newsMap: {}),
      );

      // Assert
      expect(result.length, 2);
      expect(result.first.symbol, 'HIGH_SCORE');
      expect(result.last.symbol, 'LOW_SCORE');
    });

    test('apply cooldown penalty for recently recommended stocks', () async {
      // Arrange
      final pricesMap = {
        'COOLDOWN': [
          ...generatePricesWithVolumeSpike(
            days: 30,
            normalVolume: 2000000,
            spikeVolume: 5000000,
          ),
        ],
      };

      // Mock DB to return true for wasRecommended
      when(
        () => mockAnalysisRepository.wasRecentlyRecommended(
          'COOLDOWN',
          days: any(
            named: 'days',
          ), // Argument is named 'days', not startDate/endDate
        ),
      ).thenAnswer((_) async => true);

      // Mock Analysis Service
      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 100,
          resistanceLevel: 120,
        ),
      );
      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      // Mock Rule Engine
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 10,
          description: 'Dummy',
        ),
      ]);

      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: true,
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).thenReturn(80);

      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          scoreShort: any(named: 'scoreShort'),
          scoreLong: any(named: 'scoreLong'),
          reversalState: any(named: 'reversalState'),
          supportLevel: any(named: 'supportLevel'),
          resistanceLevel: any(named: 'resistanceLevel'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});

      // Act
      await scoringService.scoreStocks(
        candidates: ['COOLDOWN'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: pricesMap, newsMap: {}),
        recentlyRecommended: {'COOLDOWN'},
      );

      // Assert
      // Stage 5b dual-horizon：calculateScore 每支股票呼叫兩次
      // （Horizon.short 一次、Horizon.long 一次），兩次都應帶 cooldown 旗標。
      verify(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: true,
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).called(2);
    });
  });

  // ==========================================
  // Group 2: 空值與早期回傳
  // ==========================================

  group('ScoringService Empty/Null Input', () {
    test('return empty list when candidates list is empty', () async {
      final result = await scoringService.scoreStocks(
        candidates: [],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: const {}, newsMap: const {}),
      );

      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('skip stocks with no price data in pricesMap', () async {
      final result = await scoringService.scoreStocks(
        candidates: ['MISSING'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: const {}, newsMap: const {}),
      );

      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('skip stocks with insufficient price history', () async {
      final prices = generateConstantPrices(
        days: 5, // < RuleParams.swingWindow (20)
        basePrice: 100.0,
        volume: 3000000,
      );

      final result = await scoringService.scoreStocks(
        candidates: ['SHORT'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: {'SHORT': prices}, newsMap: {}),
      );

      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });
  });

  // ==========================================
  // Group 3: 分析失敗路徑
  // ==========================================

  group('ScoringService Analysis Failure Paths', () {
    /// 建立通過流動性門檻的有效價格資料
    List<DailyPriceEntry> validPrices(String symbol) {
      return generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 2000000,
        spikeVolume: 5000000,
        symbol: symbol,
      );
    }

    test('skip stock when analyzeStock returns null', () async {
      final prices = validPrices('NULL_ANALYSIS');

      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(null);

      final result = await scoringService.scoreStocks(
        candidates: ['NULL_ANALYSIS'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(
          pricesMap: {'NULL_ANALYSIS': prices},
          newsMap: {},
        ),
      );

      expect(result, isEmpty);
      verify(() => mockAnalysisService.analyzeStock(any())).called(1);
      verifyNever(() => mockRuleEngine.evaluateStock(any(), any()));
    });

    test('skip stock when rule engine returns empty reasons', () async {
      final prices = validPrices('EMPTY_REASONS');

      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 100,
          resistanceLevel: 120,
        ),
      );
      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn([]);

      final result = await scoringService.scoreStocks(
        candidates: ['EMPTY_REASONS'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(
          pricesMap: {'EMPTY_REASONS': prices},
          newsMap: {},
        ),
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      );
    });
  });

  // ==========================================
  // Group 4: 分數過濾
  // ==========================================

  group('ScoringService Score Filtering', () {
    /// 設定完整的 mock pipeline 讓候選通過所有檢查直到分數計算
    void setupFullPipeline({
      required int returnScore,
      String symbol = 'STOCK',
    }) {
      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 100,
          resistanceLevel: 120,
        ),
      );
      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 20,
          description: 'Test',
        ),
      ]);

      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).thenReturn(returnScore);

      when(() => mockRuleEngine.getTopReasons(any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 20,
          description: 'Test',
        ),
      ]);

      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          scoreShort: any(named: 'scoreShort'),
          scoreLong: any(named: 'scoreLong'),
          reversalState: any(named: 'reversalState'),
          supportLevel: any(named: 'supportLevel'),
          resistanceLevel: any(named: 'resistanceLevel'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});
    }

    List<DailyPriceEntry> validPrices(String symbol) {
      return generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 2000000,
        spikeVolume: 5000000,
        symbol: symbol,
      );
    }

    test('skip stock when score is below minScoreThreshold', () async {
      final prices = validPrices('LOW');
      setupFullPipeline(returnScore: RuleParams.minScoreThreshold - 1); // 24

      final result = await scoringService.scoreStocks(
        candidates: ['LOW'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: {'LOW': prices}, newsMap: {}),
      );

      expect(result, isEmpty);
    });

    test('include stock when score equals minScoreThreshold', () async {
      final prices = validPrices('BOUNDARY');
      setupFullPipeline(returnScore: RuleParams.minScoreThreshold); // 25

      final result = await scoringService.scoreStocks(
        candidates: ['BOUNDARY'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(
          pricesMap: {'BOUNDARY': prices},
          newsMap: {},
        ),
      );

      expect(result, isNotEmpty);
      expect(result.first.scoreShort, RuleParams.minScoreThreshold);
    });
  });

  // ==========================================
  // Group 5: 選用功能
  // ==========================================

  group('ScoringService Optional Features', () {
    List<DailyPriceEntry> validPrices(String symbol) {
      return generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 2000000,
        spikeVolume: 5000000,
        symbol: symbol,
      );
    }

    test('call onProgress callback for each candidate', () async {
      final progressCalls = <(int, int)>[];
      final prices = validPrices('A');

      // analyzeStock returns null → all skipped, but onProgress still called
      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(null);

      await scoringService.scoreStocks(
        candidates: ['A', 'B', 'C'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(
          pricesMap: {'A': prices, 'B': prices, 'C': prices},
          newsMap: {},
        ),
        onProgress: (current, total) => progressCalls.add((current, total)),
      );

      expect(progressCalls, [(1, 3), (2, 3), (3, 3)]);
    });

    test('call marketDataBuilder and pass result to buildContext', () async {
      final prices = validPrices('MKT');
      const marketData = MarketDataContext(foreignSharesRatio: 30.0);

      when(() => mockAnalysisService.analyzeStock(any())).thenReturn(
        const AnalysisResult(
          trendState: TrendState.up,
          reversalState: ReversalState.none,
          supportLevel: 100,
          resistanceLevel: 120,
        ),
      );
      when(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: any(named: 'marketData'),
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 30,
          description: 'Test',
        ),
      ]);
      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
          horizon: any(named: 'horizon'),
          calibratedScores: any(named: 'calibratedScores'),
        ),
      ).thenReturn(30);
      when(() => mockRuleEngine.getTopReasons(any())).thenReturn([
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 30,
          description: 'Test',
        ),
      ]);
      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          scoreShort: any(named: 'scoreShort'),
          scoreLong: any(named: 'scoreLong'),
          reversalState: any(named: 'reversalState'),
          supportLevel: any(named: 'supportLevel'),
          resistanceLevel: any(named: 'resistanceLevel'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});

      var builderCalled = false;
      await scoringService.scoreStocks(
        candidates: ['MKT'],
        date: DateTime(2025, 6, 15),
        batchData: ScoringBatchData(pricesMap: {'MKT': prices}, newsMap: {}),
        marketDataBuilder: (symbol) async {
          builderCalled = true;
          expect(symbol, 'MKT');
          return marketData;
        },
      );

      expect(builderCalled, isTrue);
      // Verify buildContext was called with the marketData
      verify(
        () => mockAnalysisService.buildContext(
          any(),
          priceHistory: any(named: 'priceHistory'),
          marketData: marketData,
          evaluationTime: any(named: 'evaluationTime'),
        ),
      ).called(1);
    });
  });

  // ==========================================
  // Group 6: ScoredStock.compareByWeightedScore 排序邏輯
  // ==========================================

  group('ScoredStock.compareByWeightedScore', () {
    test('rank higher score first', () {
      const a = ScoredStock(
        symbol: '2330',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 100000000,
      );
      const b = ScoredStock(
        symbol: '2317',
        scoreShort: 50,
        scoreLong: 50,
        turnover: 100000000,
      );

      // a should rank first (comparator returns negative for descending)
      expect(
        ScoredStock.compareByWeightedScoreFor(Horizon.short)(a, b),
        lessThan(0),
      );
    });

    test('add liquidity bonus (2 per 100M, max 20)', () {
      // A: score=50, turnover=1B → bonus=20, total=70
      // B: score=60, turnover=50M → bonus=1, total=61
      const a = ScoredStock(
        symbol: '2330',
        scoreShort: 50,
        scoreLong: 50,
        turnover: 1000000000, // 1B
      );
      const b = ScoredStock(
        symbol: '2317',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 50000000, // 50M
      );

      // A (70) should rank before B (61)
      expect(
        ScoredStock.compareByWeightedScoreFor(Horizon.short)(a, b),
        lessThan(0),
      );
    });

    test('cap liquidity bonus at 20', () {
      // A: score=50, turnover=2B → bonus=min(40,20)=20, total=70
      // B: score=50, turnover=1B → bonus=20, total=70
      // Tied on total → break by turnover (A > B)
      const a = ScoredStock(
        symbol: '2330',
        scoreShort: 50,
        scoreLong: 50,
        turnover: 2000000000, // 2B
      );
      const b = ScoredStock(
        symbol: '2317',
        scoreShort: 50,
        scoreLong: 50,
        turnover: 1000000000, // 1B
      );

      // Both total=70, A has higher turnover → A ranks first
      expect(
        ScoredStock.compareByWeightedScoreFor(Horizon.short)(a, b),
        lessThan(0),
      );
    });

    test('break ties by turnover descending', () {
      const a = ScoredStock(
        symbol: '2330',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 500000000, // 500M
      );
      const b = ScoredStock(
        symbol: '2317',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 300000000, // 300M
      );

      // Same score, A has higher turnover → A ranks first
      expect(
        ScoredStock.compareByWeightedScoreFor(Horizon.short)(a, b),
        lessThan(0),
      );
    });

    test('break final ties by symbol ascending', () {
      const a = ScoredStock(
        symbol: '1234',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 500000000,
      );
      const b = ScoredStock(
        symbol: '5678',
        scoreShort: 60,
        scoreLong: 60,
        turnover: 500000000,
      );

      // Same score, same turnover → "1234" < "5678" → A ranks first
      expect(
        ScoredStock.compareByWeightedScoreFor(Horizon.short)(a, b),
        lessThan(0),
      );
    });
  });
}
