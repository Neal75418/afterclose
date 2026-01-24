import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
// Unused import removed
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/price_data_generators.dart';

class MockAnalysisService extends Mock implements AnalysisService {}

class MockRuleEngine extends Mock implements RuleEngine {}

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
  });
}
