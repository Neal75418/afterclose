import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/stock_fundamentals_loader.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class FakeClock implements AppClock {
  @override
  DateTime now() => DateTime(2026, 2, 15, 14, 0);
}

// =============================================================================
// Test Helpers
// =============================================================================

StockValuationEntry createValuation({
  String symbol = '2330',
  DateTime? date,
  double? per = 25.0,
  double? pbr = 6.0,
  double? dividendYield = 2.0,
}) {
  return StockValuationEntry(
    symbol: symbol,
    date: date ?? DateTime(2026, 2, 13),
    per: per,
    pbr: pbr,
    dividendYield: dividendYield,
  );
}

MonthlyRevenueEntry createRevenue({
  String symbol = '2330',
  DateTime? date,
  int revenueYear = 2025,
  int revenueMonth = 12,
  double revenue = 200000000,
  double? momGrowth,
  double? yoyGrowth,
}) {
  return MonthlyRevenueEntry(
    symbol: symbol,
    date: date ?? DateTime(2025, 12, 10),
    revenueYear: revenueYear,
    revenueMonth: revenueMonth,
    revenue: revenue,
    momGrowth: momGrowth,
    yoyGrowth: yoyGrowth,
  );
}

FinancialDataEntry createEps({
  String symbol = '2330',
  DateTime? date,
  String dataType = 'EPS',
  double? value = 5.0,
}) {
  return FinancialDataEntry(
    symbol: symbol,
    date: date ?? DateTime(2025, 11, 14),
    statementType: 'INCOME',
    dataType: dataType,
    value: value,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMind;
  late StockFundamentalsLoader loader;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMind = MockFinMindClient();
    loader = StockFundamentalsLoader(
      db: mockDb,
      finMind: mockFinMind,
      clock: FakeClock(),
    );
  });

  // ===========================================================================
  // loadAll — Valuation
  // ===========================================================================

  group('loadAll valuation', () {
    setUp(() {
      // Default stubs for other sub-methods
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <MonthlyRevenueEntry>[]);
      when(
        () => mockDb.getDividendHistory(any()),
      ).thenAnswer((_) async => <DividendHistoryEntry>[]);
      when(
        () => mockDb.getEPSHistory(any()),
      ).thenAnswer((_) async => <FinancialDataEntry>[]);
    });

    test('uses DB valuation when available', () async {
      when(
        () => mockDb.getValuationHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => [createValuation()]);

      final result = await loader.loadAll('2330');

      expect(result.latestPER, isNotNull);
      expect(result.latestPER!.per, 25.0);
      // Should NOT call API for valuation
      verifyNever(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('falls back to API when DB has no valuation', () async {
      when(
        () => mockDb.getValuationHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <StockValuationEntry>[]);

      final apiPer = FinMindPER(
        stockId: '2330',
        date: '2026-02-14',
        per: 20.0,
        pbr: 5.0,
        dividendYield: 3.0,
      );
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => [apiPer]);

      final result = await loader.loadAll('2330');

      expect(result.latestPER, isNotNull);
      expect(result.latestPER!.dividendYield, 3.0);
    });

    test('returns null PER when both DB and API fail', () async {
      when(
        () => mockDb.getValuationHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenThrow(Exception('DB error'));
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('API error'));

      final result = await loader.loadAll('2330');

      expect(result.latestPER, isNull);
    });
  });

  // ===========================================================================
  // loadAll — Revenue
  // ===========================================================================

  group('loadAll revenue', () {
    setUp(() {
      // Default stubs
      when(
        () => mockDb.getValuationHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <StockValuationEntry>[]);
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <FinMindPER>[]);
      when(
        () => mockDb.getDividendHistory(any()),
      ).thenAnswer((_) async => <DividendHistoryEntry>[]);
      when(
        () => mockDb.getEPSHistory(any()),
      ).thenAnswer((_) async => <FinancialDataEntry>[]);
    });

    test('uses DB revenue when >= 6 months available', () async {
      final dbRevenues = List.generate(
        8,
        (i) => createRevenue(revenueMonth: i + 1),
      );
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => dbRevenues);

      final result = await loader.loadAll('2330');

      expect(result.revenueData, hasLength(8));
      verifyNever(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('uses API when DB has < 6 months', () async {
      // DB has only 3 entries
      final dbRevenues = List.generate(
        3,
        (i) => createRevenue(revenueMonth: i + 1),
      );
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => dbRevenues);

      final apiRevenues = [
        FinMindRevenue(
          stockId: '2330',
          date: '2025-12-10',
          revenueYear: 2025,
          revenueMonth: 12,
          revenue: 200000000,
        ),
      ];
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => apiRevenues);

      final result = await loader.loadAll('2330');

      expect(result.revenueData, hasLength(1)); // API data used
    });

    test('falls back to DB when API fails and DB has partial data', () async {
      final dbRevenues = [createRevenue()]; // Only 1 entry (< 6)
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => dbRevenues);
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('API error'));

      final result = await loader.loadAll('2330');

      expect(result.revenueData, hasLength(1)); // DB fallback
    });

    test('returns empty when both DB and API fail', () async {
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenThrow(Exception('DB error'));
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('API error'));

      final result = await loader.loadAll('2330');

      expect(result.revenueData, isEmpty);
    });
  });

  // ===========================================================================
  // loadAll — EPS & quarter metrics
  // ===========================================================================

  group('loadAll EPS', () {
    setUp(() {
      when(
        () => mockDb.getValuationHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <StockValuationEntry>[]);
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <FinMindPER>[]);
      when(
        () => mockDb.getMonthlyRevenueHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => <MonthlyRevenueEntry>[]);
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => <FinMindRevenue>[]);
      when(
        () => mockDb.getDividendHistory(any()),
      ).thenAnswer((_) async => <DividendHistoryEntry>[]);
    });

    test('loads EPS and quarter metrics', () async {
      final epsData = [createEps()];
      when(() => mockDb.getEPSHistory(any())).thenAnswer((_) async => epsData);
      when(
        () => mockDb.getLatestQuarterMetrics(any()),
      ).thenAnswer((_) async => {'GrossMargin': 50.0});

      final result = await loader.loadAll('2330');

      expect(result.epsData, hasLength(1));
      expect(result.quarterMetrics['GrossMargin'], 50.0);
    });

    test('skips quarter metrics when no EPS data', () async {
      when(
        () => mockDb.getEPSHistory(any()),
      ).thenAnswer((_) async => <FinancialDataEntry>[]);

      final result = await loader.loadAll('2330');

      expect(result.epsData, isEmpty);
      expect(result.quarterMetrics, isEmpty);
      verifyNever(() => mockDb.getLatestQuarterMetrics(any()));
    });

    test('calculates ROE when NetIncome exists but ROE missing', () async {
      final epsData = [createEps(date: DateTime(2025, 11, 14))];
      when(() => mockDb.getEPSHistory(any())).thenAnswer((_) async => epsData);
      when(
        () => mockDb.getLatestQuarterMetrics(any()),
      ).thenAnswer((_) async => {'NetIncome': 50000.0});

      final equityEntry = FinancialDataEntry(
        symbol: '2330',
        date: DateTime(2025, 11, 14), // Same date as latest EPS
        statementType: 'BALANCE',
        dataType: 'Equity',
        value: 200000.0,
      );
      when(
        () => mockDb.getEquityHistory(any()),
      ).thenAnswer((_) async => [equityEntry]);

      final result = await loader.loadAll('2330');

      // ROE = NetIncome * 4 / Equity * 100 = 50000 * 4 / 200000 * 100 = 100.0
      expect(result.quarterMetrics['ROE'], 100.0);
    });

    test('handles EPS error gracefully', () async {
      when(() => mockDb.getEPSHistory(any())).thenThrow(Exception('DB error'));

      final result = await loader.loadAll('2330');

      expect(result.epsData, isEmpty);
      expect(result.quarterMetrics, isEmpty);
    });
  });
}
