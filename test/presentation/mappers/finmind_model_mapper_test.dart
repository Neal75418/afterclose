import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/mappers/finmind_model_mapper.dart';

// =============================================================================
// Test Helpers
// =============================================================================

MonthlyRevenueEntry createRevenueEntry({
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

StockValuationEntry createValuationEntry({
  String symbol = '2330',
  DateTime? date,
  double? per,
  double? pbr,
  double? dividendYield,
}) {
  return StockValuationEntry(
    symbol: symbol,
    date: date ?? DateTime(2026, 2, 13),
    per: per,
    pbr: pbr,
    dividendYield: dividendYield,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // toFinMindRevenues
  // ===========================================================================

  group('toFinMindRevenues', () {
    test('maps entries correctly', () {
      final entries = [
        createRevenueEntry(
          symbol: '2330',
          date: DateTime(2025, 12, 10),
          revenueYear: 2025,
          revenueMonth: 12,
          revenue: 200000000,
          momGrowth: 5.0,
          yoyGrowth: 10.0,
        ),
      ];

      final result = FinMindModelMapper.toFinMindRevenues(entries);

      expect(result, hasLength(1));
      expect(result.first.stockId, '2330');
      expect(result.first.revenueYear, 2025);
      expect(result.first.revenueMonth, 12);
      expect(result.first.revenue, 200000000);
      expect(result.first.momGrowth, 5.0);
      expect(result.first.yoyGrowth, 10.0);
    });

    test('returns empty list for empty input', () {
      final result = FinMindModelMapper.toFinMindRevenues([]);
      expect(result, isEmpty);
    });

    test('maps multiple entries preserving order', () {
      final entries = [
        createRevenueEntry(revenueMonth: 10),
        createRevenueEntry(revenueMonth: 11),
        createRevenueEntry(revenueMonth: 12),
      ];

      final result = FinMindModelMapper.toFinMindRevenues(entries);
      expect(result, hasLength(3));
      expect(result[0].revenueMonth, 10);
      expect(result[1].revenueMonth, 11);
      expect(result[2].revenueMonth, 12);
    });

    test('handles null growth rates', () {
      final entries = [createRevenueEntry(momGrowth: null, yoyGrowth: null)];
      final result = FinMindModelMapper.toFinMindRevenues(entries);
      expect(result.first.momGrowth, isNull);
      expect(result.first.yoyGrowth, isNull);
    });
  });

  // ===========================================================================
  // toFinMindPER
  // ===========================================================================

  group('toFinMindPER', () {
    test('returns null for null input', () {
      final result = FinMindModelMapper.toFinMindPER(null);
      expect(result, isNull);
    });

    test('maps valuation entry correctly', () {
      final entry = createValuationEntry(
        symbol: '2330',
        date: DateTime(2026, 2, 13),
        per: 25.5,
        pbr: 6.2,
        dividendYield: 2.1,
      );

      final result = FinMindModelMapper.toFinMindPER(entry);

      expect(result, isNotNull);
      expect(result!.stockId, '2330');
      expect(result.per, 25.5);
      expect(result.pbr, 6.2);
      expect(result.dividendYield, 2.1);
    });

    test('handles null per/pbr/dividendYield with zero defaults', () {
      final entry = createValuationEntry(
        per: null,
        pbr: null,
        dividendYield: null,
      );

      final result = FinMindModelMapper.toFinMindPER(entry);

      expect(result, isNotNull);
      expect(result!.per, 0);
      expect(result.pbr, 0);
      expect(result.dividendYield, 0);
    });
  });
}
