import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  const service = DataSyncService();

  // Helper: 建立法人資料
  List<DailyInstitutionalEntry> createInstHistory(List<DateTime> dates) {
    return dates
        .map(
          (d) => DailyInstitutionalEntry(
            symbol: 'TEST',
            date: d,
            foreignNet: 100,
            investmentTrustNet: 50,
            dealerNet: -30,
          ),
        )
        .toList();
  }

  // ==========================================
  // synchronizeDataDates
  // ==========================================
  group('synchronizeDataDates', () {
    test('returns inst date when price history is empty', () {
      final instDate = DateTime(2025, 1, 15);
      final instHistory = createInstHistory([instDate]);

      final result = service.synchronizeDataDates([], instHistory);

      expect(result.latestPrice, isNull);
      expect(result.dataDate, equals(instDate));
      expect(result.hasDataMismatch, isFalse);
      expect(result.institutionalHistory, equals(instHistory));
    });

    test('returns null dataDate when both are empty', () {
      final result = service.synchronizeDataDates([], []);

      expect(result.latestPrice, isNull);
      expect(result.dataDate, isNull);
      expect(result.hasDataMismatch, isFalse);
    });

    test('returns price date when inst history is empty', () {
      final prices = [
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];

      final result = service.synchronizeDataDates(prices, []);

      expect(result.latestPrice, equals(prices.last));
      expect(result.dataDate, equals(DateTime(2025, 1, 15)));
      expect(result.hasDataMismatch, isFalse);
    });

    test('returns matching date when both have same date', () {
      final date = DateTime(2025, 1, 15);
      final prices = [createTestPrice(date: date, close: 100.0)];
      final instHistory = createInstHistory([date]);

      final result = service.synchronizeDataDates(prices, instHistory);

      expect(result.dataDate, equals(date));
      expect(result.hasDataMismatch, isFalse);
      expect(result.latestPrice, equals(prices.last));
    });

    test('finds latest common date when dates differ', () {
      final commonDate = DateTime(2025, 1, 14);
      final prices = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 99.0),
        createTestPrice(date: commonDate, close: 100.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 101.0),
      ];
      final instHistory = createInstHistory([
        DateTime(2025, 1, 13),
        commonDate,
        // inst missing 1/15
      ]);

      final result = service.synchronizeDataDates(prices, instHistory);

      expect(result.dataDate, equals(commonDate));
      expect(result.hasDataMismatch, isTrue);
      // inst history should be filtered to common date
      expect(
        result.institutionalHistory.length,
        equals(2), // 1/13 and 1/14
      );
    });

    test('uses earlier date when no common dates exist', () {
      final prices = [
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      final instHistory = createInstHistory([DateTime(2025, 1, 14)]);

      final result = service.synchronizeDataDates(prices, instHistory);

      expect(result.dataDate, equals(DateTime(2025, 1, 14)));
      expect(result.hasDataMismatch, isTrue);
    });

    test('sets hasDataMismatch when dates do not match', () {
      final prices = [
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      final instHistory = createInstHistory([DateTime(2025, 1, 13)]);

      final result = service.synchronizeDataDates(prices, instHistory);

      expect(result.hasDataMismatch, isTrue);
    });

    test('filters institutional history to common date range', () {
      final prices = [
        createTestPrice(date: DateTime(2025, 1, 10), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 13), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 101.0),
      ];
      final instHistory = createInstHistory([
        DateTime(2025, 1, 10),
        DateTime(2025, 1, 13),
        DateTime(2025, 1, 14),
        DateTime(2025, 1, 16),
      ]);

      final result = service.synchronizeDataDates(prices, instHistory);

      // Common dates: 1/10, 1/13. Latest common = 1/13
      expect(result.dataDate, equals(DateTime(2025, 1, 13)));
      // Inst filtered to <= 1/13
      expect(
        result.institutionalHistory.every(
          (i) => !i.date.isAfter(DateTime(2025, 1, 13)),
        ),
        isTrue,
      );
    });
  });

  // ==========================================
  // getSyncedDataDate
  // ==========================================
  group('getSyncedDataDate', () {
    test('delegates to synchronizeDataDates', () {
      final date = DateTime(2025, 1, 15);
      final prices = [createTestPrice(date: date, close: 100.0)];
      final instHistory = createInstHistory([date]);

      final dataDate = service.getSyncedDataDate(prices, instHistory);

      expect(dataDate, equals(date));
    });

    test('returns null when both are empty', () {
      final dataDate = service.getSyncedDataDate([], []);

      expect(dataDate, isNull);
    });
  });

  // ==========================================
  // getDisplayDataDate
  // ==========================================
  group('getDisplayDataDate', () {
    test('returns null when both are null', () {
      expect(service.getDisplayDataDate(null, null), isNull);
    });

    test('returns instDate when priceDate is null', () {
      final instDate = DateTime(2025, 1, 15);
      expect(service.getDisplayDataDate(null, instDate), equals(instDate));
    });

    test('returns priceDate when instDate is null', () {
      final priceDate = DateTime(2025, 1, 15);
      expect(service.getDisplayDataDate(priceDate, null), equals(priceDate));
    });

    test('returns earlier date when priceDate is before instDate', () {
      final priceDate = DateTime(2025, 1, 14);
      final instDate = DateTime(2025, 1, 15);

      final result = service.getDisplayDataDate(priceDate, instDate);

      expect(result, equals(DateTime(2025, 1, 14)));
    });

    test('returns earlier date when instDate is before priceDate', () {
      final priceDate = DateTime(2025, 1, 15);
      final instDate = DateTime(2025, 1, 14);

      final result = service.getDisplayDataDate(priceDate, instDate);

      expect(result, equals(DateTime(2025, 1, 14)));
    });
  });
}
