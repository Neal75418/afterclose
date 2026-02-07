import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/portfolio_data_builders.dart';

void main() {
  const service = PortfolioAnalyticsService();

  // ==========================================
  // calculatePerformance — 總報酬
  // ==========================================
  group('calculatePerformance', () {
    test('returns empty for no transactions and no positions', () {
      final result = service.calculatePerformance(
        transactions: [],
        positions: [],
        currentPrices: {},
        stocksMap: {},
      );

      expect(result.totalReturn, equals(0));
      expect(result.totalMarketValue, equals(0));
      expect(result.totalCostBasis, equals(0));
    });

    test('calculates total return correctly', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: '2330',
          quantity: 1000,
          avgCost: 500.0,
          totalDividendReceived: 10000,
          realizedPnl: 5000,
        ),
      ];
      final transactions = [
        createTestPortfolioTransaction(
          symbol: '2330',
          txType: 'BUY',
          quantity: 1000,
          price: 500.0,
          date: DateTime.now().subtract(const Duration(days: 100)),
        ),
      ];

      final result = service.calculatePerformance(
        transactions: transactions,
        positions: positions,
        currentPrices: {'2330': 600.0},
        stocksMap: {},
      );

      // totalCost = 500 * 1000 = 500000
      // totalMarketValue = 600 * 1000 = 600000
      // totalReturn = (600000 + 10000 + 5000 - 500000) / 500000 * 100 = 23%
      expect(result.totalReturn, closeTo(23.0, 0.1));
      expect(result.totalMarketValue, equals(600000.0));
      expect(result.totalCostBasis, equals(500000.0));
    });

    test('returns 0 total return when costBasis is 0', () {
      final result = service.calculatePerformance(
        transactions: [
          createTestPortfolioTransaction(
            txType: 'SELL',
            date: DateTime.now().subtract(const Duration(days: 10)),
          ),
        ],
        positions: [], // no positions = no cost
        currentPrices: {},
        stocksMap: {},
      );

      expect(result.totalReturn, equals(0));
    });

    test('uses avgCost as fallback when currentPrice missing', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: '2330',
          quantity: 1000,
          avgCost: 500.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {}, // no current price → uses avgCost
        stocksMap: {},
      );

      // marketValue = 500 * 1000 = costBasis → totalReturn = 0
      expect(result.totalReturn, equals(0));
      expect(result.totalMarketValue, equals(500000.0));
    });

    test('totalPnl getter works correctly', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 100,
          avgCost: 100.0,
          totalDividendReceived: 500,
          realizedPnl: 1000,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 120.0},
        stocksMap: {},
      );

      // totalPnl = marketValue - costBasis + dividends + realizedPnl
      // = 12000 - 10000 + 500 + 1000 = 3500
      expect(result.totalPnl, closeTo(3500.0, 0.1));
    });
  });

  // ==========================================
  // _calculatePeriodReturns
  // ==========================================
  group('periodReturns', () {
    test('returns empty for no transactions', () {
      final result = service.calculatePerformance(
        transactions: [],
        positions: [createTestPortfolioPosition(symbol: 'A', quantity: 100)],
        currentPrices: {'A': 110.0},
        stocksMap: {},
      );

      expect(result.periodReturns.daily, equals(0));
      expect(result.periodReturns.yearly, equals(0));
    });

    test('returns empty when totalInvested <= 0', () {
      // Only SELL transactions → totalInvested negative
      final result = service.calculatePerformance(
        transactions: [
          createTestPortfolioTransaction(
            txType: 'SELL',
            quantity: 100,
            price: 100.0,
            fee: 14,
            tax: 30,
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        positions: [],
        currentPrices: {},
        stocksMap: {},
      );

      expect(result.periodReturns.daily, equals(0));
    });

    test('calculates daily and linearized returns', () {
      final buyDate = DateTime.now().subtract(const Duration(days: 100));
      final transactions = [
        createTestPortfolioTransaction(
          symbol: 'A',
          txType: 'BUY',
          quantity: 1000,
          price: 100.0,
          fee: 143,
          date: buyDate,
        ),
      ];
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: transactions,
        positions: positions,
        currentPrices: {'A': 110.0},
        stocksMap: {},
      );

      // totalInvested = 1000*100 + 143 = 100143
      // currentValue = 110 * 1000 = 110000
      // totalReturn = (110000-100143)/100143 * 100 ≈ 9.84%
      // dailyReturn = totalReturn / 100 ≈ 0.098
      expect(result.periodReturns.daily, isNot(equals(0)));
      expect(result.periodReturns.weekly, isNot(equals(0)));
      expect(result.periodReturns.monthly, isNot(equals(0)));
    });

    test('yearly return uses compound formula and is clamped', () {
      // Very short holding period with large gain → high annualized return
      final buyDate = DateTime.now().subtract(const Duration(days: 5));
      final transactions = [
        createTestPortfolioTransaction(
          symbol: 'A',
          txType: 'BUY',
          quantity: 1000,
          price: 100.0,
          fee: 0,
          date: buyDate,
        ),
      ];
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: transactions,
        positions: positions,
        currentPrices: {'A': 150.0}, // 50% gain in 5 days
        stocksMap: {},
      );

      // Yearly should be clamped to 1000.0 max
      expect(result.periodReturns.yearly, equals(1000.0));
    });

    test('returns empty when daysSinceStart is 0 (same day)', () {
      final today = DateTime.now();
      final transactions = [
        createTestPortfolioTransaction(
          symbol: 'A',
          txType: 'BUY',
          quantity: 1000,
          price: 100.0,
          date: today,
        ),
      ];
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: transactions,
        positions: positions,
        currentPrices: {'A': 110.0},
        stocksMap: {},
      );

      // daysSinceStart = 0 → returns empty
      expect(result.periodReturns.daily, equals(0));
    });
  });

  // ==========================================
  // _calculateMaxDrawdown
  // ==========================================
  group('maxDrawdown', () {
    test('returns 0 for no transactions', () {
      final result = service.calculatePerformance(
        transactions: [],
        positions: [],
        currentPrices: {},
        stocksMap: {},
      );

      expect(result.maxDrawdown, equals(0));
    });

    test('returns 0 when currentValue >= peak', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: [
          createTestPortfolioTransaction(
            symbol: 'A',
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        positions: positions,
        currentPrices: {'A': 120.0}, // above cost
        stocksMap: {},
      );

      // peak = max(100000, 120000) = 120000
      // currentValue = 120000 → no drawdown
      expect(result.maxDrawdown, equals(0));
    });

    test('calculates drawdown when currentValue < peak', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: [
          createTestPortfolioTransaction(
            symbol: 'A',
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        positions: positions,
        currentPrices: {'A': 80.0}, // below cost
        stocksMap: {},
      );

      // peak = max(100000, 80000) = 100000
      // drawdown = (100000 - 80000) / 100000 * 100 = 20%
      expect(result.maxDrawdown, closeTo(20.0, 0.1));
    });
  });

  // ==========================================
  // _calculateIndustryAllocation
  // ==========================================
  group('industryAllocation', () {
    test('returns empty for no positions', () {
      final result = service.calculatePerformance(
        transactions: [],
        positions: [],
        currentPrices: {},
        stocksMap: {},
      );

      expect(result.industryAllocation, isEmpty);
    });

    test('calculates single industry at 100%', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
      ];
      final stocksMap = {
        'A': createTestStockMaster(symbol: 'A', industry: '半導體'),
      };

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 100.0},
        stocksMap: stocksMap,
      );

      expect(result.industryAllocation.length, equals(1));
      expect(result.industryAllocation['半導體']!.percentage, closeTo(100.0, 0.1));
      expect(result.industryAllocation['半導體']!.symbols, equals(['A']));
    });

    test('calculates multiple industries correctly', () {
      final positions = [
        createTestPortfolioPosition(
          id: 1,
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
        createTestPortfolioPosition(
          id: 2,
          symbol: 'B',
          quantity: 500,
          avgCost: 200.0,
        ),
      ];
      final stocksMap = {
        'A': createTestStockMaster(symbol: 'A', industry: '半導體'),
        'B': createTestStockMaster(symbol: 'B', industry: '金融'),
      };

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 100.0, 'B': 200.0},
        stocksMap: stocksMap,
      );

      // A = 100*1000 = 100000, B = 200*500 = 100000, total = 200000
      expect(result.industryAllocation['半導體']!.percentage, closeTo(50.0, 0.1));
      expect(result.industryAllocation['金融']!.percentage, closeTo(50.0, 0.1));
    });

    test('skips positions with quantity <= 0', () {
      final positions = [
        createTestPortfolioPosition(
          id: 1,
          symbol: 'A',
          quantity: 1000,
          avgCost: 100.0,
        ),
        createTestPortfolioPosition(
          id: 2,
          symbol: 'B',
          quantity: 0,
          avgCost: 200.0,
        ),
      ];
      final stocksMap = {
        'A': createTestStockMaster(symbol: 'A', industry: '半導體'),
        'B': createTestStockMaster(symbol: 'B', industry: '金融'),
      };

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 100.0, 'B': 200.0},
        stocksMap: stocksMap,
      );

      expect(result.industryAllocation.length, equals(1));
      expect(result.industryAllocation.containsKey('半導體'), isTrue);
    });

    test('uses 其他 when stock not in stocksMap', () {
      final positions = [
        createTestPortfolioPosition(
          symbol: 'UNKNOWN',
          quantity: 100,
          avgCost: 50.0,
        ),
      ];

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'UNKNOWN': 50.0},
        stocksMap: {}, // not in map
      );

      expect(result.industryAllocation.containsKey('其他'), isTrue);
      expect(result.industryAllocation['其他']!.percentage, closeTo(100.0, 0.1));
    });

    test('groups multiple stocks in same industry', () {
      final positions = [
        createTestPortfolioPosition(
          id: 1,
          symbol: 'A',
          quantity: 500,
          avgCost: 100.0,
        ),
        createTestPortfolioPosition(
          id: 2,
          symbol: 'B',
          quantity: 500,
          avgCost: 100.0,
        ),
      ];
      final stocksMap = {
        'A': createTestStockMaster(symbol: 'A', industry: '半導體'),
        'B': createTestStockMaster(symbol: 'B', industry: '半導體'),
      };

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 100.0, 'B': 100.0},
        stocksMap: stocksMap,
      );

      expect(result.industryAllocation.length, equals(1));
      expect(
        result.industryAllocation['半導體']!.symbols,
        containsAll(['A', 'B']),
      );
      expect(result.industryAllocation['半導體']!.percentage, closeTo(100.0, 0.1));
    });

    test('uses 其他 when industry is null', () {
      final positions = [
        createTestPortfolioPosition(symbol: 'A', quantity: 100, avgCost: 100.0),
      ];
      final stocksMap = {
        'A': createTestStockMaster(symbol: 'A', industry: null),
      };

      final result = service.calculatePerformance(
        transactions: [],
        positions: positions,
        currentPrices: {'A': 100.0},
        stocksMap: stocksMap,
      );

      expect(result.industryAllocation.containsKey('其他'), isTrue);
    });
  });
}
