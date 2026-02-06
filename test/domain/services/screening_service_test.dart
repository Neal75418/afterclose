import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/repositories/screening_repository.dart';
import 'package:afterclose/domain/services/screening_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/price_data_generators.dart';

class MockScreeningRepository extends Mock implements IScreeningRepository {}

void main() {
  late MockScreeningRepository mockRepo;
  late ScreeningService service;
  final targetDate = DateTime(2025, 1, 15);

  setUp(() {
    mockRepo = MockScreeningRepository();
    service = ScreeningService(repository: mockRepo);
  });

  // ==========================================
  // Empty conditions
  // ==========================================
  group('empty conditions', () {
    test('returns empty result when no conditions provided', () async {
      final result = await service.execute(
        conditions: [],
        targetDate: targetDate,
      );

      expect(result.symbols, isEmpty);
      expect(result.matchCount, equals(0));
      expect(result.totalScanned, equals(0));
      verifyNever(() => mockRepo.executeSqlFilter(any(), any()));
    });
  });

  // ==========================================
  // SQL-only conditions
  // ==========================================
  group('SQL-only conditions', () {
    test('delegates to repository and returns results', () async {
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.close,
          operator: ScreeningOperator.greaterOrEqual,
          value: 50.0,
        ),
      ];

      when(() => mockRepo.executeSqlFilter(conditions, targetDate)).thenAnswer(
        (_) async => (symbols: ['2330', '2317', '2454'], totalScanned: 1000),
      );

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      expect(result.symbols, equals(['2330', '2317', '2454']));
      expect(result.matchCount, equals(3));
      expect(result.totalScanned, equals(1000));
      verify(() => mockRepo.executeSqlFilter(conditions, targetDate)).called(1);
    });

    test('returns empty when SQL filter finds nothing', () async {
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.pe,
          operator: ScreeningOperator.lessThan,
          value: 5.0,
        ),
      ];

      when(
        () => mockRepo.executeSqlFilter(conditions, targetDate),
      ).thenAnswer((_) async => (symbols: <String>[], totalScanned: 1000));

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      expect(result.symbols, isEmpty);
      expect(result.matchCount, equals(0));
      expect(result.totalScanned, equals(1000));
    });
  });

  // ==========================================
  // Memory-only conditions
  // ==========================================
  group('memory-only conditions', () {
    test('filters candidates using indicator evaluation', () async {
      // RSI > 70 (memory condition)
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.rsi14,
          operator: ScreeningOperator.greaterThan,
          value: 70.0,
        ),
      ];

      // SQL returns all (rsi14 is not SQL filterable)
      when(
        () => mockRepo.executeSqlFilter([], targetDate),
      ).thenAnswer((_) async => (symbols: ['A', 'B'], totalScanned: 500));

      // Build price history: 'A' has strong uptrend (high RSI), 'B' has flat (low RSI)
      final now = DateTime(2025, 1, 15);
      final uptrendPrices = List.generate(60, (i) {
        return DailyPriceEntry(
          symbol: 'A',
          date: now.subtract(Duration(days: 59 - i)),
          open: 100.0 + (i * 1.5),
          high: 102.0 + (i * 1.5),
          low: 99.0 + (i * 1.5),
          close: 101.0 + (i * 1.5),
          volume: 1000,
        );
      });
      final flatPrices = generateConstantPrices(days: 60, basePrice: 100.0);

      when(
        () => mockRepo.getPriceHistoryBatch(
          ['A', 'B'],
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => {'A': uptrendPrices, 'B': flatPrices});

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      // 'A' should pass (high RSI from uptrend), 'B' likely won't (flat → RSI edge case)
      expect(result.symbols, contains('A'));
      expect(result.totalScanned, equals(500));
    });
  });

  // ==========================================
  // Signal conditions
  // ==========================================
  group('signal conditions', () {
    test('filters by signal reason type', () async {
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.hasSignal,
          operator: ScreeningOperator.equals,
          stringValue: 'BREAKOUT',
        ),
      ];

      when(
        () => mockRepo.executeSqlFilter([], targetDate),
      ).thenAnswer((_) async => (symbols: ['X', 'Y'], totalScanned: 100));

      final date = DateTime(2025, 1, 15);
      when(() => mockRepo.getReasonsBatch(['X', 'Y'], any())).thenAnswer(
        (_) async => {
          'X': [
            DailyReasonEntry(
              symbol: 'X',
              date: date,
              rank: 1,
              reasonType: 'BREAKOUT',
              evidenceJson: '{}',
              ruleScore: 10.0,
            ),
          ],
          'Y': [
            DailyReasonEntry(
              symbol: 'Y',
              date: date,
              rank: 1,
              reasonType: 'RSI_OVERSOLD',
              evidenceJson: '{}',
              ruleScore: 5.0,
            ),
          ],
        },
      );

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      expect(result.symbols, equals(['X']));
      expect(result.matchCount, equals(1));
    });

    test('returns empty when no signal matches', () async {
      final conditions = [
        const ScreeningCondition(
          field: ScreeningField.hasSignal,
          operator: ScreeningOperator.equals,
          stringValue: 'BREAKOUT',
        ),
      ];

      when(
        () => mockRepo.executeSqlFilter([], targetDate),
      ).thenAnswer((_) async => (symbols: ['X'], totalScanned: 100));

      when(
        () => mockRepo.getReasonsBatch(['X'], any()),
      ).thenAnswer((_) async => {'X': <DailyReasonEntry>[]});

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      expect(result.symbols, isEmpty);
    });
  });

  // ==========================================
  // Mixed conditions
  // ==========================================
  group('mixed SQL + memory conditions', () {
    test('SQL pre-filters then memory post-filters', () async {
      final conditions = [
        // SQL condition
        const ScreeningCondition(
          field: ScreeningField.close,
          operator: ScreeningOperator.greaterOrEqual,
          value: 50.0,
        ),
        // Memory condition (signal)
        const ScreeningCondition(
          field: ScreeningField.hasSignal,
          operator: ScreeningOperator.equals,
          stringValue: 'BREAKOUT',
        ),
      ];

      // SQL pre-filter returns 3 candidates
      when(
        () => mockRepo.executeSqlFilter(
          [conditions[0]], // Only SQL-filterable condition
          targetDate,
        ),
      ).thenAnswer((_) async => (symbols: ['A', 'B', 'C'], totalScanned: 1000));

      final date = DateTime(2025, 1, 15);
      when(() => mockRepo.getReasonsBatch(['A', 'B', 'C'], any())).thenAnswer(
        (_) async => {
          'A': [
            DailyReasonEntry(
              symbol: 'A',
              date: date,
              rank: 1,
              reasonType: 'BREAKOUT',
              evidenceJson: '{}',
              ruleScore: 10.0,
            ),
          ],
          'B': <DailyReasonEntry>[],
          'C': [
            DailyReasonEntry(
              symbol: 'C',
              date: date,
              rank: 1,
              reasonType: 'BREAKOUT',
              evidenceJson: '{}',
              ruleScore: 8.0,
            ),
          ],
        },
      );

      final result = await service.execute(
        conditions: conditions,
        targetDate: targetDate,
      );

      // Only A and C have BREAKOUT signal
      expect(result.symbols, equals(['A', 'C']));
      expect(result.matchCount, equals(2));
      expect(result.totalScanned, equals(1000));
    });
  });
}
