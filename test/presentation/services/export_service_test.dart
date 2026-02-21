import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_types.dart';
import 'package:afterclose/presentation/services/export_service.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  const service = ExportService();

  group('watchlistToCsv', () {
    test('returns CSV with headers for empty list', () {
      final csv = service.watchlistToCsv([]);
      // Should contain header row only (7 columns)
      final lines = csv.trim().split('\n');
      expect(lines.length, 1); // header only
      // Header has 7 comma-separated values
      expect(lines[0].split(',').length, 7);
    });

    test('returns CSV with data rows', () {
      final items = [
        const WatchlistItemData(
          symbol: '2330',
          stockName: '台積電',
          market: 'TWSE',
          latestClose: 580.0,
          priceChange: 2.5,
          trendState: 'UP',
          score: 85,
        ),
        const WatchlistItemData(
          symbol: '2317',
          stockName: '鴻海',
          market: 'TWSE',
          latestClose: 105.0,
          priceChange: -1.0,
          trendState: 'DOWN',
          score: 60,
        ),
      ];

      final csv = service.watchlistToCsv(items);
      final lines = csv.trim().split('\n');
      expect(lines.length, 3); // 1 header + 2 data rows
      expect(lines[1], contains('2330'));
      expect(lines[1], contains('台積電'));
      expect(lines[2], contains('2317'));
    });

    test('handles null fields gracefully', () {
      final items = [const WatchlistItemData(symbol: '0050')];

      final csv = service.watchlistToCsv(items);
      expect(csv, contains('0050'));
      // Should not throw, null fields become empty strings
    });

    test('formats positive price change with + prefix', () {
      final items = [const WatchlistItemData(symbol: '2330', priceChange: 3.5)];

      final csv = service.watchlistToCsv(items);
      expect(csv, contains('+3.50%'));
    });

    test('formats negative price change', () {
      final items = [
        const WatchlistItemData(symbol: '2330', priceChange: -2.0),
      ];

      final csv = service.watchlistToCsv(items);
      expect(csv, contains('-2.00%'));
    });
  });

  group('portfolioToCsv', () {
    test('returns CSV with headers for empty list', () {
      final csv = service.portfolioToCsv([]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1); // header only
      // Header has 9 columns
      expect(lines[0].split(',').length, 9);
    });

    test('returns CSV with position data', () {
      final positions = [
        const PortfolioPositionData(
          positionId: 1,
          symbol: '2330',
          stockName: '台積電',
          quantity: 1000,
          avgCost: 500.0,
          realizedPnl: 10000,
          totalDividendReceived: 3000,
          currentPrice: 580.0,
        ),
      ];

      final csv = service.portfolioToCsv(positions);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2); // 1 header + 1 data row
      expect(lines[1], contains('2330'));
      expect(lines[1], contains('台積電'));
      expect(lines[1], contains('500.00')); // avgCost
      expect(lines[1], contains('580.00')); // currentPrice
    });

    test('uses avgCost for marketValue when currentPrice is null', () {
      final positions = [
        const PortfolioPositionData(
          positionId: 1,
          symbol: '0050',
          quantity: 500,
          avgCost: 120.0,
          realizedPnl: 0,
          totalDividendReceived: 0,
        ),
      ];

      final csv = service.portfolioToCsv(positions);
      expect(csv, contains('0050'));
      // marketValue = quantity * avgCost = 500 * 120 = 60000
      expect(csv, contains('60000'));
    });
  });

  group('comparisonToCsv', () {
    test('returns empty string for empty symbols', () {
      const state = ComparisonState();
      final csv = service.comparisonToCsv(state);
      expect(csv, isEmpty);
    });
  });
}
