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
class MockAnalysisRepository extends Mock implements AnalysisRepository {}

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
    registerFallbackValue(<DailyPriceEntry>[]);
    registerFallbackValue(<NewsItemEntry>[]);
    registerFallbackValue(<DailyInstitutionalEntry>[]);
    registerFallbackValue(<MonthlyRevenueEntry>[]);

    // Default mocks to prevent Null type errors
    when(() => mockRuleEngine.getTopReasons(any())).thenAnswer(
      (invocation) =>
          invocation.positionalArguments[0] as List<TriggeredReason>,
    );
    // Types that might be nullable in arguments but needed for any()
    registerFallbackValue(
      MonthlyRevenueEntry(
        symbol: 'TEST',
        date: DateTime.now(),
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
        date: DateTime.now(),
        per: 0,
        pbr: 0,
        dividendYield: 0,
      ),
    );
  });

  group('ScoringService Liquidity Filters', () {
    test('should skip stocks with low volume', () async {
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
          date: DateTime.now(),
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
        date: DateTime.now(),
        pricesMap: pricesMap,
        newsMap: {},
      );

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('should skip stocks with low turnover', () async {
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
          date: DateTime.now(),
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
        date: DateTime.now(),
        pricesMap: pricesMap,
        newsMap: {},
      );

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockAnalysisService.analyzeStock(any()));
    });

    test('should process stocks with high volume and turnover', () async {
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
          date: DateTime.now(),
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
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(
        () => mockRuleEngine.evaluateStock(
          priceHistory: any(named: 'priceHistory'),
          context: any(named: 'context'),
          recentNews: any(named: 'recentNews'),
          symbol: any(named: 'symbol'),
          institutionalHistory: any(named: 'institutionalHistory'),
          latestRevenue: any(named: 'latestRevenue'),
          latestValuation: any(named: 'latestValuation'),
          revenueHistory: any(named: 'revenueHistory'),
        ),
      ).thenReturn([
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
          score: any(named: 'score'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalysisRepository.saveReasons(any(), any(), any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await scoringService.scoreStocks(
        candidates: ['GOOD'],
        date: DateTime.now(),
        pricesMap: pricesMap,
        newsMap: {},
      );

      // Assert
      expect(result, isNotEmpty);
      expect(result.first.symbol, 'GOOD');
      expect(result.first.score, 80);
    });

    test('should sort candidates by score descending', () async {
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
      when(
        () => mockRuleEngine.evaluateStock(
          priceHistory: any(named: 'priceHistory'),
          context: any(named: 'context'),
          symbol: any(named: 'symbol'),
          recentNews: null,
          institutionalHistory: null,
          latestRevenue: null,
          latestValuation: null,
          revenueHistory: null,
        ),
      ).thenAnswer((invocation) {
        final symbol = invocation.namedArguments[#symbol] as String;
        if (symbol == 'HIGH_SCORE') return [highReason];
        if (symbol == 'LOW_SCORE') return [lowReason];
        return [];
      });

      // Mock calculateScore to return score based on input reasons
      when(
        () => mockRuleEngine.calculateScore(
          any(),
          wasRecentlyRecommended: any(named: 'wasRecentlyRecommended'),
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
        ),
      ).thenReturn(const AnalysisContext(trendState: TrendState.up));

      when(
        () => mockAnalysisRepository.saveAnalysis(
          symbol: any(named: 'symbol'),
          date: any(named: 'date'),
          trendState: any(named: 'trendState'),
          score: any(named: 'score'),
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
        date: DateTime.now(),
        pricesMap: pricesMap,
        newsMap: {},
      );

      // Assert
      expect(result.length, 2);
      expect(result.first.symbol, 'HIGH_SCORE');
      expect(result.last.symbol, 'LOW_SCORE');
    });

    test(
      'should apply cooldown penalty for recently recommended stocks',
      () async {
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
          ),
        ).thenReturn(const AnalysisContext(trendState: TrendState.up));

        // Mock Rule Engine
        when(
          () => mockRuleEngine.evaluateStock(
            priceHistory: any(named: 'priceHistory'),
            context: any(named: 'context'),
            symbol: 'COOLDOWN',
            recentNews: null,
            institutionalHistory: null,
            latestRevenue: null,
            latestValuation: null,
            revenueHistory: null,
          ),
        ).thenReturn([
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
          ),
        ).thenReturn(80);

        when(
          () => mockAnalysisRepository.saveAnalysis(
            symbol: any(named: 'symbol'),
            date: any(named: 'date'),
            trendState: any(named: 'trendState'),
            score: any(named: 'score'),
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
          date: DateTime.now(),
          pricesMap: pricesMap,
          newsMap: {},
          recentlyRecommended: {'COOLDOWN'},
        );

        // Assert
        // Verify calculateScore was called with wasRecentlyRecommended: true
        verify(
          () => mockRuleEngine.calculateScore(
            any(),
            wasRecentlyRecommended: true,
          ),
        ).called(1);
      },
    );
  });
}
