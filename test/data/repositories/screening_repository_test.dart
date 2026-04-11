import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/screening_repository.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAppDatabase mockDb;
  late ScreeningRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    repo = ScreeningRepository(database: mockDb);
  });

  // ==========================================
  // _fieldToColumn (tested via ScreeningField.isSqlFilterable)
  // ==========================================
  group('ScreeningField.isSqlFilterable', () {
    test('SQL-filterable fields return true', () {
      const sqlFields = [
        ScreeningField.close,
        ScreeningField.volume,
        ScreeningField.priceChangePercent,
        ScreeningField.pe,
        ScreeningField.pbr,
        ScreeningField.dividendYield,
        ScreeningField.revenueYoyGrowth,
        ScreeningField.revenueMomGrowth,
        ScreeningField.score,
      ];

      for (final field in sqlFields) {
        expect(
          field.isSqlFilterable,
          isTrue,
          reason: '${field.name} should be SQL-filterable',
        );
      }
    });

    test('non-SQL fields return false', () {
      const nonSqlFields = [
        ScreeningField.aboveMa5,
        ScreeningField.aboveMa10,
        ScreeningField.aboveMa20,
        ScreeningField.aboveMa60,
        ScreeningField.rsi14,
        ScreeningField.kValue,
        ScreeningField.dValue,
        ScreeningField.hasSignal,
        ScreeningField.volumeRatioMa20,
      ];

      for (final field in nonSqlFields) {
        expect(
          field.isSqlFilterable,
          isFalse,
          reason: '${field.name} should NOT be SQL-filterable',
        );
      }
    });
  });

  // ==========================================
  // ScreeningOperator compatibility
  // ==========================================
  group('ScreeningOperator', () {
    test('defaultFor returns correct default operator', () {
      expect(
        ScreeningOperator.defaultFor(ScreeningFieldType.numeric),
        equals(ScreeningOperator.greaterOrEqual),
      );
      expect(
        ScreeningOperator.defaultFor(ScreeningFieldType.boolean),
        equals(ScreeningOperator.isTrue),
      );
      expect(
        ScreeningOperator.defaultFor(ScreeningFieldType.signal),
        equals(ScreeningOperator.equals),
      );
    });
  });

  // ==========================================
  // ScreeningCondition serialization
  // ==========================================
  group('ScreeningCondition', () {
    test('toJson/fromJson round-trip for numeric condition', () {
      const original = ScreeningCondition(
        field: ScreeningField.close,
        operator: ScreeningOperator.greaterThan,
        value: 100.0,
      );

      final json = original.toJson();
      final restored = ScreeningCondition.fromJson(json);

      expect(restored.field, equals(original.field));
      expect(restored.operator, equals(original.operator));
      expect(restored.value, equals(original.value));
    });

    test('toJson/fromJson round-trip for between condition', () {
      const original = ScreeningCondition(
        field: ScreeningField.pe,
        operator: ScreeningOperator.between,
        value: 10.0,
        valueTo: 20.0,
      );

      final json = original.toJson();
      final restored = ScreeningCondition.fromJson(json);

      expect(restored.value, equals(10.0));
      expect(restored.valueTo, equals(20.0));
    });

    test('copyWith preserves original and applies changes', () {
      const original = ScreeningCondition(
        field: ScreeningField.close,
        operator: ScreeningOperator.greaterThan,
        value: 100.0,
      );

      final modified = original.copyWith(
        field: ScreeningField.volume,
        value: 500.0,
      );

      expect(modified.field, equals(ScreeningField.volume));
      expect(modified.value, equals(500.0));
      expect(modified.operator, equals(ScreeningOperator.greaterThan));
      // Original unchanged
      expect(original.field, equals(ScreeningField.close));
    });

    test('copyWith clearValue sets value to null', () {
      const original = ScreeningCondition(
        field: ScreeningField.close,
        operator: ScreeningOperator.greaterThan,
        value: 100.0,
      );

      final cleared = original.copyWith(clearValue: true);

      expect(cleared.value, isNull);
    });
  });

  // ==========================================
  // ScreeningStrategy serialization
  // ==========================================
  group('ScreeningStrategy', () {
    test('conditionsToJson/conditionsFromJson round-trip', () {
      const conditions = [
        ScreeningCondition(
          field: ScreeningField.close,
          operator: ScreeningOperator.greaterThan,
          value: 50.0,
        ),
        ScreeningCondition(
          field: ScreeningField.pe,
          operator: ScreeningOperator.between,
          value: 10.0,
          valueTo: 30.0,
        ),
      ];

      final json = ScreeningStrategy.conditionsToJson(conditions);
      final restored = ScreeningStrategy.conditionsFromJson(json);

      expect(restored.length, equals(2));
      expect(restored[0].field, equals(ScreeningField.close));
      expect(restored[1].valueTo, equals(30.0));
    });
  });

  // ==========================================
  // Delegation
  // ==========================================
  group('delegation', () {
    test('getPriceHistoryBatch delegates to db and returns result', () async {
      final startDate = DateTime(2025, 1, 1);
      final endDate = DateTime(2025, 1, 31);
      final expected = <String, List<DailyPriceEntry>>{
        '2330': [
          DailyPriceEntry(
            symbol: '2330',
            date: startDate,
            open: 100,
            high: 110,
            low: 95,
            close: 105,
            volume: 5000,
          ),
        ],
      };
      when(
        () => mockDb.getPriceHistoryBatch(
          any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => expected);

      final result = await repo.getPriceHistoryBatch(
        ['2330'],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result, equals(expected));
      expect(result['2330']!.length, equals(1));
      verify(
        () => mockDb.getPriceHistoryBatch(
          ['2330'],
          startDate: startDate,
          endDate: endDate,
        ),
      ).called(1);
    });

    test('getReasonsBatch delegates to db and returns result', () async {
      final date = DateTime(2025, 1, 15);
      final expected = <String, List<DailyReasonEntry>>{
        '2330': [
          DailyReasonEntry(
            symbol: '2330',
            date: date,
            rank: 1,
            reasonType: 'TREND_UP',
            evidenceJson: '{}',
            ruleScoreShort: 20.0,
            ruleScoreLong: 20.0,
          ),
        ],
      };
      when(
        () => mockDb.getReasonsBatch(any(), any()),
      ).thenAnswer((_) async => expected);

      final result = await repo.getReasonsBatch(['2330'], date);

      expect(result, equals(expected));
      expect(result['2330']!.length, equals(1));
      verify(() => mockDb.getReasonsBatch(['2330'], date)).called(1);
    });
  });
}
