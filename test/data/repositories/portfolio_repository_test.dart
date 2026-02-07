import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/portfolio_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool? requireNew}) {
    return action();
  }
}

class FakePortfolioTransactionCompanion extends Fake
    implements PortfolioTransactionCompanion {}

class FakePortfolioPositionCompanion extends Fake
    implements PortfolioPositionCompanion {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePortfolioTransactionCompanion());
    registerFallbackValue(FakePortfolioPositionCompanion());
  });

  late MockAppDatabase mockDb;
  late PortfolioRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    repository = PortfolioRepository(database: mockDb);
  });

  // ==========================================
  // Static methods
  // ==========================================
  group('calculateFee', () {
    test('calculates standard brokerage fee', () {
      // 1000 shares * 100 NTD * 0.001425 = 142.5
      final fee = PortfolioRepository.calculateFee(1000, 100);
      expect(fee, closeTo(142.5, 0.01));
    });

    test('enforces minimum fee of 20 NTD', () {
      // 1 share * 100 NTD * 0.001425 = 0.1425 → min 20
      final fee = PortfolioRepository.calculateFee(1, 100);
      expect(fee, equals(20.0));
    });

    test('returns exactly 20 at boundary', () {
      // fee = qty * price * 0.001425 = 20 → qty * price = 14035.09
      // 100 shares * 140 NTD = 14000 * 0.001425 = 19.95 → min 20
      final fee = PortfolioRepository.calculateFee(100, 140);
      expect(fee, equals(20.0));
    });
  });

  group('calculateTax', () {
    test('calculates transaction tax at 0.3%', () {
      // 1000 shares * 100 NTD * 0.003 = 300
      final tax = PortfolioRepository.calculateTax(1000, 100);
      expect(tax, closeTo(300.0, 0.01));
    });
  });

  // ==========================================
  // addBuyTransaction
  // ==========================================
  group('addBuyTransaction', () {
    test('inserts BUY transaction and recalculates position', () async {
      when(() => mockDb.insertTransaction(any())).thenAnswer((_) async => 1);
      when(() => mockDb.getTransactionsForSymbol('2330')).thenAnswer(
        (_) async => [
          PortfolioTransactionEntry(
            id: 1,
            symbol: '2330',
            txType: 'BUY',
            date: DateTime(2025, 1, 15),
            quantity: 1000,
            price: 500,
            fee: 712.5,
            tax: 0,
            createdAt: DateTime(2025, 1, 15),
          ),
        ],
      );
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.upsertPortfolioPosition(any()),
      ).thenAnswer((_) async {});

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 15),
        quantity: 1000,
        price: 500,
      );

      // insertTransaction called once for the BUY + recalculate reads transactions
      final captured =
          verify(() => mockDb.insertTransaction(captureAny())).captured.single
              as PortfolioTransactionCompanion;
      expect(captured.txType.value, equals('BUY'));
      expect(captured.symbol.value, equals('2330'));
    });

    test('throws ArgumentError for zero quantity', () {
      expect(
        () => repository.addBuyTransaction(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          quantity: 0,
          price: 500,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative price', () {
      expect(
        () => repository.addBuyTransaction(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          quantity: 1000,
          price: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  // ==========================================
  // addSellTransaction
  // ==========================================
  group('addSellTransaction', () {
    test('throws StateError when selling more than held', () async {
      when(() => mockDb.getPortfolioPosition('2330')).thenAnswer(
        (_) async => PortfolioPositionEntry(
          id: 1,
          symbol: '2330',
          quantity: 500,
          avgCost: 500,
          realizedPnl: 0,
          totalDividendReceived: 0,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      );

      expect(
        () => repository.addSellTransaction(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          quantity: 1000,
          price: 600,
        ),
        throwsStateError,
      );
    });

    test('throws StateError when no position exists', () async {
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => null);

      expect(
        () => repository.addSellTransaction(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          quantity: 1000,
          price: 600,
        ),
        throwsStateError,
      );
    });

    test('throws ArgumentError for zero quantity', () {
      expect(
        () => repository.addSellTransaction(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          quantity: 0,
          price: 600,
        ),
        throwsArgumentError,
      );
    });
  });

  // ==========================================
  // addDividendTransaction
  // ==========================================
  group('addDividendTransaction', () {
    test('inserts cash dividend with DIVIDEND_CASH type', () async {
      when(() => mockDb.insertTransaction(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getTransactionsForSymbol('2330'),
      ).thenAnswer((_) async => []);
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => null);

      await repository.addDividendTransaction(
        symbol: '2330',
        date: DateTime(2025, 7, 15),
        amount: 3000,
        isCash: true,
      );

      final captured =
          verify(() => mockDb.insertTransaction(captureAny())).captured.single
              as PortfolioTransactionCompanion;
      expect(captured.txType.value, equals('DIVIDEND_CASH'));
      expect(captured.quantity.value, equals(3000));
      expect(captured.price.value, equals(0));
    });

    test('inserts stock dividend with DIVIDEND_STOCK type', () async {
      when(() => mockDb.insertTransaction(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getTransactionsForSymbol('2330'),
      ).thenAnswer((_) async => []);
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => null);

      await repository.addDividendTransaction(
        symbol: '2330',
        date: DateTime(2025, 7, 15),
        amount: 100,
        isCash: false,
      );

      final captured =
          verify(() => mockDb.insertTransaction(captureAny())).captured.single
              as PortfolioTransactionCompanion;
      expect(captured.txType.value, equals('DIVIDEND_STOCK'));
    });

    test('throws ArgumentError for zero amount', () {
      expect(
        () => repository.addDividendTransaction(
          symbol: '2330',
          date: DateTime(2025, 7, 15),
          amount: 0,
          isCash: true,
        ),
        throwsArgumentError,
      );
    });
  });

  // ==========================================
  // _recalculatePosition (FIFO logic via addBuyTransaction)
  // ==========================================
  group('FIFO position recalculation', () {
    /// Helper: set up mocks for recalculation tests
    void setupRecalcMocks({
      required List<PortfolioTransactionEntry> transactions,
      PortfolioPositionEntry? existingPosition,
    }) {
      when(
        () => mockDb.insertTransaction(any()),
      ).thenAnswer((_) async => transactions.length + 1);
      when(
        () => mockDb.getTransactionsForSymbol(any()),
      ).thenAnswer((_) async => transactions);
      when(
        () => mockDb.getPortfolioPosition(any()),
      ).thenAnswer((_) async => existingPosition);
      if (existingPosition != null) {
        when(
          () => mockDb.updatePortfolioPosition(
            id: any(named: 'id'),
            quantity: any(named: 'quantity'),
            avgCost: any(named: 'avgCost'),
            realizedPnl: any(named: 'realizedPnl'),
            totalDividendReceived: any(named: 'totalDividendReceived'),
          ),
        ).thenAnswer((_) async {});
      } else {
        when(
          () => mockDb.upsertPortfolioPosition(any()),
        ).thenAnswer((_) async {});
      }
    }

    test('single buy creates position with fee-adjusted avgCost', () async {
      final tx = PortfolioTransactionEntry(
        id: 1,
        symbol: '2330',
        txType: 'BUY',
        date: DateTime(2025, 1, 15),
        quantity: 1000,
        price: 500,
        fee: 712.5, // 1000*500*0.001425
        tax: 0,
        createdAt: DateTime(2025, 1, 15),
      );
      setupRecalcMocks(transactions: [tx]);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 15),
        quantity: 1000,
        price: 500,
        fee: 712.5,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;
      // avgCost = price + fee/qty = 500 + 712.5/1000 = 500.7125
      expect(captured.avgCost.value, closeTo(500.7125, 0.001));
      expect(captured.quantity.value, equals(1000));
    });

    test('buy then sell calculates realized PnL with FIFO', () async {
      final transactions = [
        PortfolioTransactionEntry(
          id: 1,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 10),
          quantity: 1000,
          price: 500,
          fee: 712.5,
          tax: 0,
          createdAt: DateTime(2025, 1, 10),
        ),
        PortfolioTransactionEntry(
          id: 2,
          symbol: '2330',
          txType: 'SELL',
          date: DateTime(2025, 1, 20),
          quantity: 500,
          price: 600,
          fee: 427.5, // 500*600*0.001425
          tax: 900, // 500*600*0.003
          createdAt: DateTime(2025, 1, 20),
        ),
      ];

      setupRecalcMocks(transactions: transactions);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 10),
        quantity: 1000,
        price: 500,
        fee: 712.5,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;

      // FIFO: buy lot costPerShare = 500 + 712.5/1000 = 500.7125
      // sell 500 shares at 600: pnl = (600 - 500.7125) * 500 = 49643.75
      // minus sell fee+tax: 49643.75 - 427.5 - 900 = 48316.25
      expect(captured.realizedPnl.value, closeTo(48316.25, 0.1));
      expect(captured.quantity.value, equals(500));
      // remaining lot still has same costPerShare
      expect(captured.avgCost.value, closeTo(500.7125, 0.001));
    });

    test('multiple buys at different prices with FIFO sell', () async {
      final transactions = [
        PortfolioTransactionEntry(
          id: 1,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 10),
          quantity: 500,
          price: 400,
          fee: 285, // 500*400*0.001425
          tax: 0,
          createdAt: DateTime(2025, 1, 10),
        ),
        PortfolioTransactionEntry(
          id: 2,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 15),
          quantity: 500,
          price: 600,
          fee: 427.5,
          tax: 0,
          createdAt: DateTime(2025, 1, 15),
        ),
        PortfolioTransactionEntry(
          id: 3,
          symbol: '2330',
          txType: 'SELL',
          date: DateTime(2025, 1, 20),
          quantity: 700,
          price: 550,
          fee: 549.45,
          tax: 1155,
          createdAt: DateTime(2025, 1, 20),
        ),
      ];

      setupRecalcMocks(transactions: transactions);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 10),
        quantity: 500,
        price: 400,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;

      // FIFO lots:
      // Lot1: 500 @ (400 + 285/500) = 500 @ 400.57
      // Lot2: 500 @ (600 + 427.5/500) = 500 @ 600.855
      // Sell 700 @ 550:
      //   From Lot1: 500 shares → pnl = (550-400.57)*500 = 74715
      //   From Lot2: 200 shares → pnl = (550-600.855)*200 = -10171
      //   Raw pnl = 74715 - 10171 = 64544
      //   After fees: 64544 - 549.45 - 1155 = 62839.55
      expect(captured.realizedPnl.value, closeTo(62839.55, 0.1));
      // Remaining: 300 shares from Lot2 @ 600.855
      expect(captured.quantity.value, equals(300));
      expect(captured.avgCost.value, closeTo(600.855, 0.001));
    });

    test('sell all shares results in zero quantity', () async {
      final transactions = [
        PortfolioTransactionEntry(
          id: 1,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 10),
          quantity: 1000,
          price: 500,
          fee: 712.5,
          tax: 0,
          createdAt: DateTime(2025, 1, 10),
        ),
        PortfolioTransactionEntry(
          id: 2,
          symbol: '2330',
          txType: 'SELL',
          date: DateTime(2025, 1, 20),
          quantity: 1000,
          price: 600,
          fee: 855,
          tax: 1800,
          createdAt: DateTime(2025, 1, 20),
        ),
      ];

      setupRecalcMocks(transactions: transactions);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 10),
        quantity: 1000,
        price: 500,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;

      expect(captured.quantity.value, equals(0));
      // avgCost should be 0 when no remaining lots
      expect(captured.avgCost.value, equals(0));
    });

    test('cash dividend adds to totalDividendReceived', () async {
      final transactions = [
        PortfolioTransactionEntry(
          id: 1,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 10),
          quantity: 1000,
          price: 500,
          fee: 712.5,
          tax: 0,
          createdAt: DateTime(2025, 1, 10),
        ),
        PortfolioTransactionEntry(
          id: 2,
          symbol: '2330',
          txType: 'DIVIDEND_CASH',
          date: DateTime(2025, 7, 15),
          quantity: 3500, // 3.5 NTD/share * 1000 shares
          price: 0,
          fee: 0,
          tax: 0,
          createdAt: DateTime(2025, 7, 15),
        ),
      ];

      setupRecalcMocks(transactions: transactions);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 10),
        quantity: 1000,
        price: 500,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;

      expect(captured.totalDividendReceived.value, equals(3500));
      expect(captured.quantity.value, equals(1000)); // unchanged
    });

    test('stock dividend adds zero-cost lot', () async {
      final transactions = [
        PortfolioTransactionEntry(
          id: 1,
          symbol: '2330',
          txType: 'BUY',
          date: DateTime(2025, 1, 10),
          quantity: 1000,
          price: 500,
          fee: 0,
          tax: 0,
          createdAt: DateTime(2025, 1, 10),
        ),
        PortfolioTransactionEntry(
          id: 2,
          symbol: '2330',
          txType: 'DIVIDEND_STOCK',
          date: DateTime(2025, 7, 15),
          quantity: 50, // 50 bonus shares
          price: 0,
          fee: 0,
          tax: 0,
          createdAt: DateTime(2025, 7, 15),
        ),
      ];

      setupRecalcMocks(transactions: transactions);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 10),
        quantity: 1000,
        price: 500,
      );

      final captured =
          verify(
                () => mockDb.upsertPortfolioPosition(captureAny()),
              ).captured.single
              as PortfolioPositionCompanion;

      // 1000 original + 50 bonus = 1050
      expect(captured.quantity.value, equals(1050));
      // avgCost = (1000*500 + 50*0) / 1050 = 500000/1050 ≈ 476.19
      expect(captured.avgCost.value, closeTo(476.19, 0.01));
    });

    test('deletes position when no transactions remain', () async {
      final existing = PortfolioPositionEntry(
        id: 1,
        symbol: '2330',
        quantity: 1000,
        avgCost: 500,
        realizedPnl: 0,
        totalDividendReceived: 0,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      when(() => mockDb.insertTransaction(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getTransactionsForSymbol('2330'),
      ).thenAnswer((_) async => []);
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => existing);
      when(() => mockDb.deletePortfolioPosition(1)).thenAnswer((_) async {});

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 15),
        quantity: 1,
        price: 1,
      );

      verify(() => mockDb.deletePortfolioPosition(1)).called(1);
    });

    test('updates existing position instead of creating new', () async {
      final existing = PortfolioPositionEntry(
        id: 42,
        symbol: '2330',
        quantity: 1000,
        avgCost: 500,
        realizedPnl: 0,
        totalDividendReceived: 0,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final tx = PortfolioTransactionEntry(
        id: 1,
        symbol: '2330',
        txType: 'BUY',
        date: DateTime(2025, 1, 15),
        quantity: 1000,
        price: 500,
        fee: 0,
        tax: 0,
        createdAt: DateTime(2025, 1, 15),
      );

      setupRecalcMocks(transactions: [tx], existingPosition: existing);

      await repository.addBuyTransaction(
        symbol: '2330',
        date: DateTime(2025, 1, 15),
        quantity: 1000,
        price: 500,
        fee: 0,
      );

      verify(
        () => mockDb.updatePortfolioPosition(
          id: 42,
          quantity: any(named: 'quantity'),
          avgCost: any(named: 'avgCost'),
          realizedPnl: any(named: 'realizedPnl'),
          totalDividendReceived: any(named: 'totalDividendReceived'),
        ),
      ).called(1);
    });
  });

  // ==========================================
  // deleteTransaction
  // ==========================================
  group('deleteTransaction', () {
    test('deletes transaction and recalculates position', () async {
      when(() => mockDb.deleteTransaction(1)).thenAnswer((_) async {});
      when(
        () => mockDb.getTransactionsForSymbol('2330'),
      ).thenAnswer((_) async => []);
      when(
        () => mockDb.getPortfolioPosition('2330'),
      ).thenAnswer((_) async => null);

      await repository.deleteTransaction(1, '2330');

      verify(() => mockDb.deleteTransaction(1)).called(1);
    });
  });
}
